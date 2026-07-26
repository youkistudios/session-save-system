#!/bin/sh
# Session Save System v2 transactional installer — Claude Code + Codex.
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export SESSION_SAVE_REPO_DIR="$REPO_DIR"
exec python3 - "$@" <<'PY'
from __future__ import annotations

import fcntl
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

REPO = Path(os.environ["SESSION_SAVE_REPO_DIR"])
OPERATION = os.environ.get("SESSION_SAVE_OPERATION", "install")
if OPERATION not in {"install", "uninstall", "recover"}:
    raise SystemExit(f"unsupported Session Save operation: {OPERATION}")
UID = os.getuid()
CLIENTS_RAW = os.environ.get("SESSION_SAVE_CLIENTS", "claude,codex")
if CLIENTS_RAW not in {"claude", "codex", "claude,codex", "codex,claude"}:
    raise SystemExit("Unsupported SESSION_SAVE_CLIENTS (use claude, codex, or claude,codex)")
CLIENTS = list(dict.fromkeys(CLIENTS_RAW.split(",")))
CLAUDE = Path(os.environ.get("CLAUDE_CONFIG_DIR", Path.home() / ".claude")).expanduser()
CODEX = Path(os.environ.get("AGENTS_CONFIG_DIR", Path.home() / ".agents")).expanduser()
LIB = Path(os.environ.get("SESSION_SAVE_LIB_DIR", Path.home() / ".local" / "share" / "session-save")).expanduser()
STATE = Path(os.environ.get("SESSION_SAVE_STATE_DIR", Path.home() / ".local" / "state" / "session-save")).expanduser()
CONFIG = Path(os.environ.get("SESSION_SAVE_CONFIG", Path.home() / ".config" / "session-save" / "config.json")).expanduser()
ROOTS: dict[str, Path] = {"shared": LIB, "claude": CLAUDE, "codex": CODEX, "config": CONFIG.parent}
ROOT_FDS: dict[str, int] = {}
JOURNAL_LIMIT = 64 * 1024
CLIENT_ALLOWED = {
    *(f"skills/{skill}/{leaf}" for skill in ["session-tag", "session-checkpoint", "session-close", "session-review", "session-pickup", "session-save", "session-summary", "session-audit"] for leaf in ["SKILL.md", "CLIENT.md", "scripts/session_save.py"]),
    *(f"commands/{name}.md" for name in ["session-tag", "session-checkpoint", "session-close", "session-review", "session-pickup", "session-save", "session-summary", "session-audit", "st", "ss", "ssum", "sa"]),
    "save-system-home",
}


def die(message: str) -> None:
    raise RuntimeError(message)


def digest_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def fsync_dir(path: Path) -> None:
    fd = os.open(path, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def ensure_dir_nofollow(path: Path, mode: int = 0o755) -> Path:
    path = Path(os.path.abspath(path))
    if path.is_symlink():
        die(f"refusing symlinked directory root: {path}")
    # Normalize platform aliases such as macOS /tmp -> /private/tmp, but never the final root.
    path = path.parent.resolve() / path.name
    fd = os.open(os.sep, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
    try:
        for index, part in enumerate(path.parts[1:]):
            try:
                next_fd = os.open(part, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0), dir_fd=fd)
            except FileNotFoundError:
                os.mkdir(part, mode if index == len(path.parts[1:]) - 1 else 0o755, dir_fd=fd)
                next_fd = os.open(part, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0), dir_fd=fd)
            info = os.fstat(next_fd)
            if not stat.S_ISDIR(info.st_mode):
                os.close(next_fd)
                die(f"not a real directory: {path}")
            os.close(fd)
            fd = next_fd
        info = os.fstat(fd)
        if info.st_uid != UID:
            die(f"directory is not owned by current user: {path}")
    finally:
        os.close(fd)
    return path


def regular_state(path: Path) -> tuple[bool, str | None]:
    try:
        info = os.lstat(path)
    except FileNotFoundError:
        return False, None
    if not stat.S_ISREG(info.st_mode) or stat.S_ISLNK(info.st_mode):
        die(f"target is not a regular file: {path}")
    return True, digest(path)


def atomic_write(path: Path, data: bytes, mode: int) -> None:
    ensure_dir_nofollow(path.parent)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    tmp = Path(temporary)
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(tmp, mode)
        os.replace(tmp, path)
        fsync_dir(path.parent)
    finally:
        tmp.unlink(missing_ok=True)


def atomic_write_at(parent_fd: int, name: str, data: bytes, mode: int) -> None:
    if not name or "/" in name or name in {".", ".."}:
        die("unsafe descriptor-relative filename")
    temporary = f".{name}.{os.getpid()}.{time.time_ns()}"
    fd = os.open(temporary, os.O_CREAT | os.O_EXCL | os.O_WRONLY | getattr(os, "O_NOFOLLOW", 0), mode, dir_fd=parent_fd)
    try:
        with os.fdopen(fd, "wb", closefd=False) as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.fchmod(fd, mode)
        os.replace(temporary, name, src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
        os.fsync(parent_fd)
    finally:
        os.close(fd)
        try:
            os.unlink(temporary, dir_fd=parent_fd)
        except FileNotFoundError:
            pass


def read_json_at(parent_fd: int, name: str, maximum: int = JOURNAL_LIMIT) -> Any:
    fd = os.open(name, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0), dir_fd=parent_fd)
    try:
        before = os.fstat(fd)
        if not stat.S_ISREG(before.st_mode) or before.st_size > maximum:
            die(f"JSON input is unsafe or exceeds {maximum} bytes: {name}")
        chunks: list[bytes] = []
        size = 0
        while True:
            chunk = os.read(fd, min(65536, maximum + 1 - size))
            if not chunk:
                break
            chunks.append(chunk)
            size += len(chunk)
            if size > maximum:
                die(f"JSON input exceeds {maximum} bytes: {name}")
        after = os.fstat(fd)
        if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
            die(f"JSON input changed while being read: {name}")
        return json.loads(b"".join(chunks))
    finally:
        os.close(fd)


def open_parent_from_root(root_id: str, relative: str) -> tuple[int, str]:
    if root_id not in ROOT_FDS or not safe_relative(relative):
        die(f"transaction root is not descriptor-bound: {root_id}")
    parts = Path(relative).parts
    fd = os.dup(ROOT_FDS[root_id])
    try:
        for part in parts[:-1]:
            next_fd = os.open(part, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0), dir_fd=fd)
            os.close(fd)
            fd = next_fd
        return fd, parts[-1]
    except Exception:
        os.close(fd)
        raise


def regular_state_at(parent_fd: int, name: str) -> tuple[bool, str | None]:
    try:
        fd = os.open(name, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0), dir_fd=parent_fd)
    except FileNotFoundError:
        return False, None
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode):
            die(f"descriptor-relative target is not regular: {name}")
        h = hashlib.sha256()
        for chunk in iter(lambda: os.read(fd, 65536), b""):
            h.update(chunk)
        after = os.fstat(fd)
        if (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns) != (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
            die(f"descriptor-relative target changed while being read: {name}")
        return True, h.hexdigest()
    finally:
        os.close(fd)


def _verify_prior_at(parent_fd: int, name: str, op: dict[str, Any]) -> None:
    try:
        fd = os.open(name, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0), dir_fd=parent_fd)
    except FileNotFoundError:
        if op["prior_exists"]:
            die(f"transaction target disappeared after preflight: {name}")
        return
    try:
        info = os.fstat(fd)
        if not op["prior_exists"] or not stat.S_ISREG(info.st_mode):
            die(f"transaction target appeared or became unsafe after preflight: {name}")
        h = hashlib.sha256()
        for chunk in iter(lambda: os.read(fd, 65536), b""):
            h.update(chunk)
        after = os.fstat(fd)
        if (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns) != (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
            die(f"transaction target changed during verification: {name}")
        if (info.st_dev, info.st_ino, h.hexdigest()) != (op["prior_dev"], op["prior_ino"], op["prior_hash"]):
            die(f"transaction target changed after preflight: {name}")
    finally:
        os.close(fd)


def atomic_write_checked(data: bytes, mode: int, op: dict[str, Any]) -> None:
    parent_fd, name = open_parent_from_root(op["root"], op["path"])
    temporary = op["temporary"]
    fd = os.open(temporary, os.O_CREAT | os.O_EXCL | os.O_WRONLY | getattr(os, "O_NOFOLLOW", 0), mode, dir_fd=parent_fd)
    try:
        with os.fdopen(fd, "wb", closefd=False) as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.fchmod(fd, mode)
        if os.environ.get("SESSION_SAVE_TEST_CRASH_TEMP_PATH") == op["path"]:
            os._exit(95)
        _verify_prior_at(parent_fd, name, op)
        os.replace(temporary, name, src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
        os.fsync(parent_fd)
    finally:
        os.close(fd)
        try:
            os.unlink(temporary, dir_fd=parent_fd)
        except FileNotFoundError:
            pass
        os.close(parent_fd)


def delete_checked(op: dict[str, Any]) -> None:
    parent_fd, name = open_parent_from_root(op["root"], op["path"])
    try:
        _verify_prior_at(parent_fd, name, op)
        os.unlink(name, dir_fd=parent_fd)
        os.fsync(parent_fd)
    finally:
        os.close(parent_fd)


def read_json_regular(path: Path, maximum: int = JOURNAL_LIMIT) -> Any:
    fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    try:
        before = os.fstat(fd)
        if not stat.S_ISREG(before.st_mode) or before.st_size > maximum:
            die(f"JSON input is unsafe or exceeds {maximum} bytes: {path}")
        chunks: list[bytes] = []
        size = 0
        while True:
            chunk = os.read(fd, min(65536, maximum + 1 - size))
            if not chunk:
                break
            chunks.append(chunk)
            size += len(chunk)
            if size > maximum:
                die(f"JSON input exceeds {maximum} bytes: {path}")
        after = os.fstat(fd)
        if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
            die(f"JSON input changed while being read: {path}")
        return json.loads(b"".join(chunks))
    finally:
        os.close(fd)


def read_manifest(path: Path) -> dict[str, str]:
    exists, _ = regular_state(path)
    if not exists:
        return {}
    result: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        parts = raw.split("\t", 1)
        if len(parts) != 2 or not re.fullmatch(r"[0-9a-f]{64}", parts[0]) or parts[1] in result:
            die(f"invalid ownership manifest: {path}")
        relative = parts[1]
        if not safe_relative(relative):
            die(f"unsafe ownership manifest path: {relative}")
        result[relative] = parts[0]
    return result


def manifest_bytes(entries: dict[str, str]) -> bytes:
    return "".join(f"{value}\t{key}\n" for key, value in sorted(entries.items())).encode()


def safe_relative(value: str) -> bool:
    path = Path(value)
    return bool(value) and not path.is_absolute() and ".." not in path.parts and "\0" not in value


def target(root_id: str, relative: str) -> Path:
    if root_id not in ROOTS or not safe_relative(relative):
        die(f"unsafe transaction target: {root_id}:{relative}")
    root = ROOTS[root_id]
    candidate = root.joinpath(*Path(relative).parts)
    current = root
    for part in Path(relative).parts[:-1]:
        current = current / part
        if current.is_symlink():
            die(f"refusing path below symlink: {candidate}")
    return candidate


def source_bytes(path: Path) -> bytes:
    exists, _ = regular_state(path)
    if not exists:
        die(f"repository source missing: {path}")
    return path.read_bytes()


ensure_dir_nofollow(STATE, 0o700)
lock_path = STATE / "install.lock"
lock_fd = os.open(lock_path, os.O_CREAT | os.O_RDWR | getattr(os, "O_NOFOLLOW", 0), 0o600)
lock_info = os.fstat(lock_fd)
if not stat.S_ISREG(lock_info.st_mode) or lock_info.st_uid != UID or lock_info.st_nlink != 1 or stat.S_IMODE(lock_info.st_mode) != 0o600:
    os.close(lock_fd)
    raise SystemExit("unsafe Session Save global installer lock")
try:
    fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    os.close(lock_fd)
    raise SystemExit("another Session Save install, uninstall, or recovery is running")
if os.environ.get("SESSION_SAVE_TEST_HOLD_LOCK"):
    time.sleep(float(os.environ["SESSION_SAVE_TEST_HOLD_LOCK"]))

transactions = ensure_dir_nofollow(STATE / "install-transactions", 0o700)
backups = ensure_dir_nofollow(STATE / "backups", 0o700)
transactions_fd = os.open(transactions, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0))
state_fd = os.open(STATE, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0))
journal_path = transactions / "current.json"
marker_path = STATE / "upgrade-in-progress"


def validate_journal(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict) or value.get("schema") != 1 or value.get("state") not in {"prepared", "applying", "committed"}:
        die("invalid installation journal envelope")
    operation_type = value.get("operation")
    if operation_type not in {"install", "uninstall"}:
        die("invalid installation journal operation type")
    transaction_id = value.get("transaction_id")
    if not isinstance(transaction_id, str) or not re.fullmatch(r"[0-9]{8}-[0-9]{6}-[0-9]+", transaction_id):
        die("invalid installation transaction ID")
    operations = value.get("operations")
    if not isinstance(operations, list) or len(operations) > 200:
        die("invalid installation journal operations")
    seen_targets: set[tuple[str, str]] = set()
    for op in operations:
        if not isinstance(op, dict) or op.get("root") not in ROOTS or op.get("action") not in {"write", "delete"}:
            die("invalid installation journal operation")
        if not safe_relative(op.get("path", "")):
            die("unsafe installation journal path")
        identity = (op["root"], op["path"])
        if identity in seen_targets:
            die("duplicate installation journal target")
        seen_targets.add(identity)
        allowed = False
        if op["root"] == "shared" and op["path"] in {"session_save.py", "VERSION", "install.manifest"}:
            allowed = (
                operation_type == "install" and op["action"] == "write"
            ) or (
                operation_type == "uninstall" and (
                    (op["path"] == "install.manifest" and op["action"] in {"write", "delete"})
                    or (op["path"] in {"session_save.py", "VERSION"} and op["action"] == "delete")
                )
            )
        elif op["root"] in {"claude", "codex"} and (op["path"] in CLIENT_ALLOWED or op["path"] == "session-save-system.manifest"):
            allowed = (
                operation_type == "install" and op["action"] == "write"
            ) or (
                operation_type == "uninstall" and (
                    (op["path"] == "session-save-system.manifest" and op["action"] in {"write", "delete"})
                    or (op["path"] in CLIENT_ALLOWED and op["action"] == "delete")
                )
            )
        elif op["root"] == "config":
            allowed = operation_type == "install" and op["path"] == CONFIG.name and op["action"] == "write"
        elif op["root"] == "home":
            allowed = operation_type == "install" and op["path"] in {"GUIDE.md", ".version"} and op["action"] == "write"
        if not allowed:
            die("operation is outside the installation journal allowlist")
        for field in ("prior_hash", "new_hash", "backup_hash"):
            if op.get(field) is not None and not re.fullmatch(r"[0-9a-f]{64}", op[field]):
                die(f"invalid installation journal {field}")
        if type(op.get("prior_exists")) is not bool or op.get("status") not in {"pending", "applying", "complete"}:
            die("invalid installation journal state")
        for field in ("prior_dev", "prior_ino"):
            if op.get(field) is not None and (not isinstance(op[field], int) or op[field] < 0):
                die(f"invalid installation journal {field}")
        temporary = op.get("temporary")
        if op["action"] == "write":
            temporary_seed = f"{transaction_id}:{op['root']}:{op['path']}".encode()
            expected_temporary = f".session-save-txn-{hashlib.sha256(temporary_seed).hexdigest()[:24]}"
            if temporary != expected_temporary:
                die("invalid installation temporary path")
            if op.get("new_hash") is None:
                die("write operation has no intended hash")
        elif temporary is not None or op.get("new_hash") is not None:
            die("delete operation has an invalid temporary path or intended hash")
        backup = op.get("backup")
        expected_backup = f"{transaction_id}/{op['root']}/{op['path']}" if op["prior_exists"] else None
        if backup != expected_backup:
            die("invalid installation journal backup path")
        if op["prior_exists"]:
            if op.get("prior_hash") is None or op.get("backup_hash") != op.get("prior_hash") or op.get("prior_dev") is None or op.get("prior_ino") is None:
                die("incomplete installation journal prior-state receipt")
        elif any(op.get(field) is not None for field in ("prior_hash", "backup_hash", "prior_dev", "prior_ino")):
            die("absent prior target has unexpected receipt data")
    roots = value.get("roots")
    if not isinstance(roots, dict):
        die("installation journal has invalid root receipts")
    if set(roots) != {op["root"] for op in operations}:
        die("installation journal roots do not match operations")
    for root_id, receipt in roots.items():
        if root_id not in ROOTS or not isinstance(receipt, dict):
            die("invalid installation journal root")
        if not isinstance(receipt.get("path"), str) or not Path(receipt["path"]).is_absolute():
            die("invalid installation journal root path")
        if any(not isinstance(receipt.get(field), int) for field in ("dev", "ino", "uid")):
            die("invalid installation journal root identity")
    return value


def save_journal(value: dict[str, Any]) -> None:
    data = json.dumps(value, indent=2, sort_keys=True).encode() + b"\n"
    if len(data) > JOURNAL_LIMIT:
        die("installation journal exceeds 64 KiB")
    atomic_write_at(transactions_fd, "current.json", data, 0o600)


def backup_path(relative: str) -> Path:
    if not safe_relative(relative):
        die("unsafe backup path")
    return backups.joinpath(*Path(relative).parts)


def root_receipt(root_id: str) -> dict[str, Any]:
    path = ROOTS[root_id]
    if path.is_symlink():
        die(f"transaction root is a symlink: {path}")
    canonical = path.parent.resolve() / path.name
    info = os.lstat(canonical)
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != UID:
        die(f"unsafe transaction root: {canonical}")
    return {"path": str(canonical), "dev": info.st_dev, "ino": info.st_ino, "uid": info.st_uid}


def bind_journal_roots(value: dict[str, Any]) -> None:
    for fd in ROOT_FDS.values():
        os.close(fd)
    ROOT_FDS.clear()
    for root_id, expected in value["roots"].items():
        current = root_receipt(root_id)
        if current != expected:
            die(f"transaction root identity changed: {root_id}")
        fd = os.open(expected["path"], os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0))
        info = os.fstat(fd)
        if (info.st_dev, info.st_ino, info.st_uid) != (expected["dev"], expected["ino"], expected["uid"]):
            os.close(fd)
            die(f"transaction root changed while binding: {root_id}")
        ROOT_FDS[root_id] = fd


def verify_journal_roots(value: dict[str, Any]) -> None:
    if set(ROOT_FDS) != set(value["roots"]):
        die("transaction root descriptors are incomplete")
    for root_id, expected in value["roots"].items():
        info = os.fstat(ROOT_FDS[root_id])
        if (info.st_dev, info.st_ino, info.st_uid) != (expected["dev"], expected["ino"], expected["uid"]):
            die(f"transaction root descriptor changed: {root_id}")


def cleanup_transaction_temporary(op: dict[str, Any]) -> None:
    if not op.get("temporary"):
        return
    parent_fd, _ = open_parent_from_root(op["root"], op["path"])
    try:
        try:
            info = os.stat(op["temporary"], dir_fd=parent_fd, follow_symlinks=False)
        except FileNotFoundError:
            return
        if not stat.S_ISREG(info.st_mode) or info.st_uid != UID or info.st_nlink != 1:
            die("unsafe transaction temporary encountered during recovery")
        os.unlink(op["temporary"], dir_fd=parent_fd)
        os.fsync(parent_fd)
    finally:
        os.close(parent_fd)


def rollback(value: dict[str, Any]) -> None:
    verify_journal_roots(value)
    for op in reversed(value["operations"]):
        if op["status"] == "pending":
            cleanup_transaction_temporary(op)
            continue
        parent_fd, name = open_parent_from_root(op["root"], op["path"])
        try:
            exists, current_hash = regular_state_at(parent_fd, name)
            mutated = (op["action"] == "write" and exists and current_hash == op["new_hash"]) or (op["action"] == "delete" and not exists)
            unchanged = (op["prior_exists"] and exists and current_hash == op["prior_hash"]) or (not op["prior_exists"] and not exists)
            if op["status"] == "applying" and unchanged:
                op["status"] = "pending"
                cleanup_transaction_temporary(op)
                save_journal(value)
                continue
            if not mutated:
                die(f"cannot prove transaction ownership during recovery: {op['root']}:{op['path']}")
            if op["prior_exists"]:
                saved = backup_path(op["backup"])
                saved_exists, saved_hash = regular_state(saved)
                if not saved_exists or saved_hash != op["backup_hash"] or saved_hash != op["prior_hash"]:
                    die(f"backup hash mismatch during recovery: {saved}")
                atomic_write_at(parent_fd, name, saved.read_bytes(), op["prior_mode"])
            elif exists:
                os.unlink(name, dir_fd=parent_fd)
                os.fsync(parent_fd)
        finally:
            os.close(parent_fd)
        op["status"] = "pending"
        cleanup_transaction_temporary(op)
        save_journal(value)
    try:
        os.unlink("upgrade-in-progress", dir_fd=state_fd)
    except FileNotFoundError:
        pass
    try:
        os.unlink("current.json", dir_fd=transactions_fd)
    except FileNotFoundError:
        pass
    os.fsync(transactions_fd)


def recover_if_needed() -> None:
    try:
        info = os.stat("current.json", dir_fd=transactions_fd, follow_symlinks=False)
    except FileNotFoundError:
        try:
            os.stat("upgrade-in-progress", dir_fd=state_fd, follow_symlinks=False)
        except FileNotFoundError:
            return
        die(f"upgrade marker exists without a recoverable journal: {marker_path}")
    if not stat.S_ISREG(info.st_mode) or info.st_uid != UID or info.st_nlink != 1 or stat.S_IMODE(info.st_mode) != 0o600:
        die("unsafe installation journal")
    value = validate_journal(read_json_at(transactions_fd, "current.json"))
    bind_journal_roots(value)
    if value["state"] == "committed":
        try:
            os.unlink("upgrade-in-progress", dir_fd=state_fd)
        except FileNotFoundError:
            pass
        os.unlink("current.json", dir_fd=transactions_fd)
        return
    rollback(value)
    print("  recovered incomplete Session Save transaction")


def recovery_home_root() -> Path:
    if os.environ.get("SESSION_SAVE_HOME"):
        raw = os.environ["SESSION_SAVE_HOME"]
    elif os.environ.get("SAVE_SYSTEM_HOME"):
        raw = os.environ["SAVE_SYSTEM_HOME"]
    else:
        config_exists, _ = regular_state(CONFIG)
        if config_exists:
            payload = read_json_regular(CONFIG)
            raw = payload.get("home") if isinstance(payload, dict) else None
            if not isinstance(raw, str) or not raw:
                die(f"Session Save config has no valid home: {CONFIG}")
        else:
            pointer = CLAUDE / "save-system-home"
            pointer_exists, _ = regular_state(pointer)
            raw = pointer.read_text().splitlines()[0] if pointer_exists else str(Path.home() / "Desktop" / "session-logs")
    path = Path(os.path.abspath(Path(raw).expanduser()))
    if path.is_symlink():
        die(f"refusing symlinked home root: {path}")
    return path.parent.resolve() / path.name


ROOTS["home"] = recovery_home_root()
recover_if_needed()
if OPERATION == "recover":
    print("Session Save recovery complete")
    fcntl.flock(lock_fd, fcntl.LOCK_UN)
    os.close(lock_fd)
    raise SystemExit(0)


def resolve_home() -> tuple[Path, bytes | None]:
    explicit = False
    if os.environ.get("SESSION_SAVE_HOME"):
        requested = os.environ["SESSION_SAVE_HOME"]
        explicit = True
    elif os.environ.get("SAVE_SYSTEM_HOME"):
        requested = os.environ["SAVE_SYSTEM_HOME"]
        explicit = True
    else:
        pointer = CLAUDE / "save-system-home"
        if pointer.is_file() and not pointer.is_symlink():
            requested = pointer.read_text().splitlines()[0]
        else:
            requested = str(Path.home() / "Desktop" / "session-logs")
    requested_path = Path(os.path.abspath(Path(requested).expanduser()))
    config_exists, _ = regular_state(CONFIG)
    if config_exists:
        try:
            payload = read_json_regular(CONFIG)
            configured = Path(os.path.abspath(Path(payload["home"]).expanduser()))
        except Exception as exc:
            die(f"invalid Session Save config {CONFIG}: {exc}")
        if configured != requested_path and explicit:
            die(f"Explicit home conflicts with existing config: {CONFIG}\n  configured: {configured}\n  requested:  {requested_path}")
        return configured, None
    data = json.dumps({"schema_version": "2.0", "home": str(requested_path)}, indent=2).encode() + b"\n"
    return requested_path, data


HOME_DIR, CONFIG_DATA = resolve_home()
ensure_dir_nofollow(HOME_DIR)
ROOTS["home"] = HOME_DIR
CLIENT_ROOTS = {"claude": CLAUDE, "codex": CODEX}
for root in [LIB, CONFIG.parent, *[CLIENT_ROOTS[c] for c in CLIENTS]]:
    ensure_dir_nofollow(root)

stamp = time.strftime("%Y%m%d-%H%M%S") + f"-{os.getpid()}"
backup_root = ensure_dir_nofollow(backups / stamp, 0o700)
operations: list[dict[str, Any]] = []
operation_data: dict[tuple[str, str], bytes] = {}


def add_operation(root_id: str, relative: str, data: bytes | None, mode: int = 0o600) -> None:
    path = target(root_id, relative)
    exists, prior_hash = regular_state(path)
    action = "delete" if data is None else "write"
    new_hash = digest_bytes(data) if data is not None else None
    if action == "write" and exists and prior_hash == new_hash:
        return
    if action == "delete" and not exists:
        return
    prior_info = os.lstat(path) if exists else None
    prior_mode = stat.S_IMODE(prior_info.st_mode) if prior_info else mode
    backup_rel = None
    backup_hash = None
    if exists:
        backup_rel = f"{stamp}/{root_id}/{relative}"
        saved = backup_path(backup_rel)
        ensure_dir_nofollow(saved.parent, 0o700)
        shutil.copyfile(path, saved)
        os.chmod(saved, 0o600)
        backup_hash = digest(saved)
    ensure_dir_nofollow(path.parent)
    temporary_name = f".session-save-txn-{hashlib.sha256(f'{stamp}:{root_id}:{relative}'.encode()).hexdigest()[:24]}" if action == "write" else None
    if temporary_name is not None and (path.parent / temporary_name).exists():
        die(f"transaction temporary target already exists: {path.parent / temporary_name}")
    op = {
        "root": root_id, "path": relative, "action": action,
        "prior_exists": exists, "prior_hash": prior_hash, "prior_mode": prior_mode,
        "prior_dev": prior_info.st_dev if prior_info else None,
        "prior_ino": prior_info.st_ino if prior_info else None,
        "new_hash": new_hash, "mode": mode, "backup": backup_rel,
        "backup_hash": backup_hash,
        "temporary": temporary_name,
        "status": "pending",
    }
    operations.append(op)
    if data is not None:
        operation_data[(root_id, relative)] = data


def can_manage(root_id: str, relative: str, data: bytes, previous: dict[str, str]) -> bool:
    try:
        path = target(root_id, relative)
        exists, current = regular_state(path)
    except RuntimeError:
        return False
    if not exists or current == digest_bytes(data):
        return True
    return relative in previous


ALLOWED = CLIENT_ALLOWED


def build_install() -> tuple[dict[str, dict[str, str]], dict[str, str]]:
    shared_manifest_path = LIB / "install.manifest"
    shared_previous = read_manifest(shared_manifest_path)
    shared_entries: dict[str, str] = {}
    for source, relative, mode in [(REPO / "scripts/session_save.py", "session_save.py", 0o700), (REPO / "VERSION", "VERSION", 0o600)]:
        data = source_bytes(source)
        path = target("shared", relative)
        exists, current = regular_state(path)
        if exists and current != digest_bytes(data) and relative not in shared_previous:
            die(f"Unowned shared target conflicts with Session Save: {path}")
        shared_entries[relative] = digest_bytes(data)
        add_operation("shared", relative, data, mode)
    if CONFIG_DATA is not None:
        add_operation("config", CONFIG.name, CONFIG_DATA, 0o600)

    client_entries: dict[str, dict[str, str]] = {}
    adapter_source = REPO / "scripts/session_save_adapter.py"
    canonical = ["session-tag", "session-save", "session-summary", "session-audit"]
    aliases = [("session-checkpoint", "session-save"), ("session-close", "session-summary"), ("session-review", "session-audit")]
    for client in CLIENTS:
        root_id = client
        manifest_path = CLIENT_ROOTS[client] / "session-save-system.manifest"
        previous = read_manifest(manifest_path)
        entries: dict[str, str] = {}

        def install_file(source: Path, relative: str, mode: int = 0o644) -> bool:
            data = source_bytes(source)
            if not can_manage(root_id, relative, data, previous):
                return False
            entries[relative] = digest_bytes(data)
            add_operation(root_id, relative, data, mode)
            return True

        for skill in canonical:
            canonical_unit = [
                (REPO / "skills" / skill / "SKILL.md", f"skills/{skill}/SKILL.md", 0o644),
                (REPO / "adapters" / client / "CLIENT.md", f"skills/{skill}/CLIENT.md", 0o644),
                (adapter_source, f"skills/{skill}/scripts/session_save.py", 0o700),
            ]
            if all(can_manage(root_id, rel, source_bytes(src), previous) for src, rel, _ in canonical_unit):
                for src, rel, mode in canonical_unit:
                    install_file(src, rel, mode)
            else:
                print(f"  skipped {client} canonical skill {skill} — complete managed skill unit is unavailable")
        for alias, canonical_name in aliases:
            required = [f"skills/{canonical_name}/SKILL.md", f"skills/{canonical_name}/CLIENT.md", f"skills/{canonical_name}/scripts/session_save.py"]
            unit = [
                (REPO / "skills" / alias / "SKILL.md", f"skills/{alias}/SKILL.md", 0o644),
                (REPO / "adapters" / client / "CLIENT.md", f"skills/{alias}/CLIENT.md", 0o644),
                (adapter_source, f"skills/{alias}/scripts/session_save.py", 0o700),
            ]
            if all(path in entries for path in required) and all(can_manage(root_id, rel, source_bytes(src), previous) for src, rel, _ in unit):
                for src, rel, mode in unit:
                    install_file(src, rel, mode)
                if client == "claude":
                    install_file(REPO / "commands" / f"{alias}.md", f"commands/{alias}.md")
            else:
                print(f"  skipped {client} alias {alias} — complete managed alias unit is unavailable")
        pickup_unit = [
            (REPO / "skills/session-pickup/SKILL.md", "skills/session-pickup/SKILL.md", 0o644),
            (REPO / "adapters" / client / "CLIENT.md", "skills/session-pickup/CLIENT.md", 0o644),
            (adapter_source, "skills/session-pickup/scripts/session_save.py", 0o700),
        ]
        if all(can_manage(root_id, rel, source_bytes(src), previous) for src, rel, _ in pickup_unit):
            for src, rel, mode in pickup_unit:
                install_file(src, rel, mode)
            if client == "claude" and not install_file(REPO / "commands/session-pickup.md", "commands/session-pickup.md"):
                print("  skipped claude command /session-pickup — unrelated command exists; Pickup skill remains available")
        else:
            print(f"  skipped {client} Pickup — complete managed Pickup unit is unavailable")
        if client == "claude":
            for command in ["session-tag", "session-save", "session-summary", "session-audit", "st", "ss", "ssum", "sa"]:
                if not install_file(REPO / "commands" / f"{command}.md", f"commands/{command}.md"):
                    print(f"  skipped claude command /{command} — unrelated command exists")
            pointer = (str(HOME_DIR) + "\n").encode()
            if can_manage(root_id, "save-system-home", pointer, previous):
                entries["save-system-home"] = digest_bytes(pointer)
                add_operation(root_id, "save-system-home", pointer, 0o600)
        client_entries[client] = entries
        add_operation(root_id, "session-save-system.manifest", manifest_bytes(entries), 0o600)
    add_operation("shared", "install.manifest", manifest_bytes(shared_entries), 0o600)
    add_operation("home", "GUIDE.md", source_bytes(REPO / "GUIDE.md"), 0o644)
    add_operation("home", ".version", source_bytes(REPO / "VERSION"), 0o600)
    return client_entries, shared_entries


def build_uninstall() -> tuple[dict[str, dict[str, str]], dict[str, str]]:
    client_remaining: dict[str, dict[str, str]] = {}
    for client in CLIENTS:
        root_id = client
        manifest_path = CLIENT_ROOTS[client] / "session-save-system.manifest"
        previous = read_manifest(manifest_path)
        preserve = False
        for relative, expected in previous.items():
            dependency_sensitive = bool(re.match(r"^skills/(session-checkpoint|session-close|session-review|session-pickup)/", relative)) or relative in {
                "commands/session-checkpoint.md", "commands/session-close.md", "commands/session-review.md", "commands/session-pickup.md"
            }
            if relative not in ALLOWED or not dependency_sensitive:
                continue
            path = target(root_id, relative)
            exists, current = regular_state(path)
            if exists and current != expected:
                preserve = True
                break
        if preserve:
            print(f"  preserved complete {client} adapter unit because a managed file was modified or unsafe")
            client_remaining[client] = previous
            continue
        remaining = {relative: expected for relative, expected in previous.items() if relative not in ALLOWED}
        for relative, expected in previous.items():
            if relative not in ALLOWED:
                continue
            path = target(root_id, relative)
            exists, current = regular_state(path)
            if exists and current == expected:
                add_operation(root_id, relative, None)
            elif exists:
                remaining[relative] = expected
        if remaining:
            add_operation(root_id, "session-save-system.manifest", manifest_bytes(remaining), 0o600)
        else:
            add_operation(root_id, "session-save-system.manifest", None)
        client_remaining[client] = remaining

    launcher_remains = False
    for client in ["claude", "codex"]:
        if client in client_remaining:
            entries = client_remaining[client]
        else:
            entries = read_manifest(CLIENT_ROOTS[client] / "session-save-system.manifest")
        if any(re.fullmatch(r"skills/[^/]+/scripts/session_save\.py", relative) for relative in entries):
            launcher_remains = True
    shared_previous = read_manifest(LIB / "install.manifest")
    shared_remaining = dict(shared_previous)
    if not launcher_remains:
        for relative in ["session_save.py", "VERSION"]:
            expected = shared_previous.get(relative)
            if not expected:
                continue
            path = target("shared", relative)
            exists, current = regular_state(path)
            if exists and current == expected:
                add_operation("shared", relative, None)
                shared_remaining.pop(relative, None)
            elif exists:
                print(f"  preserved modified shared file: {relative}")
        if shared_remaining:
            add_operation("shared", "install.manifest", manifest_bytes(shared_remaining), 0o600)
        else:
            add_operation("shared", "install.manifest", None)
    return client_remaining, shared_remaining


try:
    if OPERATION == "install":
        print("Session Save System v2 transactional installer")
        print(f"  shared home: {HOME_DIR}")
        print(f"  shared kernel: {LIB / 'session_save.py'}")
        print(f"  clients: {','.join(CLIENTS)}")
        client_entries, _ = build_install()
    else:
        print("Session Save System v2 transactional uninstaller")
        client_entries, _ = build_uninstall()

    used_roots = sorted({op["root"] for op in operations})
    journal = {
        "schema": 1, "state": "prepared", "operation": OPERATION, "transaction_id": stamp,
        "roots": {root_id: root_receipt(root_id) for root_id in used_roots},
        "operations": operations,
    }
    journal = validate_journal(journal)
    bind_journal_roots(journal)
    save_journal(journal)
    atomic_write_at(state_fd, "upgrade-in-progress", json.dumps({"operation": OPERATION, "pid": os.getpid()}).encode() + b"\n", 0o600)
    journal["state"] = "applying"
    save_journal(journal)
    test_fail_after = int(os.environ.get("SESSION_SAVE_TEST_FAIL_AFTER", "0"))
    test_crash_after = int(os.environ.get("SESSION_SAVE_TEST_CRASH_AFTER", "0"))
    test_crash_during = int(os.environ.get("SESSION_SAVE_TEST_CRASH_DURING", "0"))
    applied = 0
    for op in journal["operations"]:
        verify_journal_roots(journal)
        path = target(op["root"], op["path"])
        exists, current_hash = regular_state(path)
        if exists != op["prior_exists"] or current_hash != op["prior_hash"]:
            die(f"transaction target changed after preflight: {path}")
        if exists:
            current_info = os.lstat(path)
            if (current_info.st_dev, current_info.st_ino) != (op["prior_dev"], op["prior_ino"]):
                die(f"transaction target identity changed after preflight: {path}")
        op["status"] = "applying"
        save_journal(journal)
        if op["action"] == "write":
            atomic_write_checked(operation_data[(op["root"], op["path"])], op["mode"], op)
        else:
            delete_checked(op)
        applied += 1
        if test_crash_during == applied:
            os._exit(96)
        op["status"] = "complete"
        save_journal(journal)
        if test_crash_after == applied:
            os._exit(97)
        if test_fail_after == applied:
            die(f"injected transaction failure after operation {applied}")
    for op in journal["operations"]:
        path = target(op["root"], op["path"])
        exists, current = regular_state(path)
        if op["action"] == "write" and (not exists or current != op["new_hash"]):
            die(f"post-install verification failed: {path}")
        if op["action"] == "delete" and exists:
            die(f"post-uninstall verification failed: {path}")
    journal["state"] = "committed"
    save_journal(journal)
    try:
        os.unlink("upgrade-in-progress", dir_fd=state_fd)
    except FileNotFoundError:
        pass
    os.unlink("current.json", dir_fd=transactions_fd)
    os.fsync(transactions_fd)
except Exception as exc:
    try:
        try:
            os.stat("current.json", dir_fd=transactions_fd, follow_symlinks=False)
        except FileNotFoundError:
            pass
        else:
            recovery_value = validate_journal(read_json_at(transactions_fd, "current.json"))
            if not ROOT_FDS:
                bind_journal_roots(recovery_value)
            rollback(recovery_value)
    except Exception as recovery_exc:
        print(f"Session Save transaction failed: {exc}", file=sys.stderr)
        print(f"Automatic recovery could not prove safety: {recovery_exc}", file=sys.stderr)
        print(f"Journal and upgrade marker retained: {journal_path}", file=sys.stderr)
        raise SystemExit(2)
    print(f"Session Save transaction failed and was rolled back: {exc}", file=sys.stderr)
    raise SystemExit(2)

if OPERATION == "install":
    kernel = (LIB / "session_save.py").resolve()
    subprocess.run(
        [sys.executable, str(kernel), "--home", str(HOME_DIR), "home", "--init"],
        check=True, capture_output=True, text=True,
    )
    migration_run = subprocess.run(
        [sys.executable, str(kernel), "--home", str(HOME_DIR), "migrate-v1", "--client", "claude", "--dry-run"],
        check=True, capture_output=True, text=True,
    )
    count = json.loads(migration_run.stdout)["count"]
    print(f"  Claude manifest files: {len(client_entries.get('claude', {}))}" if "claude" in client_entries else "")
    print(f"  Codex manifest files: {len(client_entries.get('codex', {}))}" if "codex" in client_entries else "")
    if count:
        print(f"Installed, but {count} legacy record(s) require copy-first migration before use.")
        print(f'Review: python3 "{kernel}" --home "{HOME_DIR}" migrate-v1 --client claude --dry-run')
        print(f'Apply after review: python3 "{kernel}" --home "{HOME_DIR}" migrate-v1 --client claude --apply')
    else:
        if len(CLIENTS) == 1:
            print(f"Done. Installed {CLIENTS[0]} uses: {HOME_DIR}")
        else:
            print(f"Done. Installed clients share: {HOME_DIR}")
    if "claude" in CLIENTS:
        print("Claude Code: /session-tag · /session-checkpoint · /session-close · /session-review · /session-pickup")
    if "codex" in CLIENTS:
        print("Codex: $session-tag · $session-checkpoint · $session-close · $session-review · $session-pickup")
    print("Existing session-save, session-summary, session-audit, and short aliases remain supported.")
else:
    print("Uninstall complete. Shared config, records, migration sources, and backups were not touched.")

for fd in ROOT_FDS.values():
    os.close(fd)
os.close(transactions_fd)
os.close(state_fd)
fcntl.flock(lock_fd, fcntl.LOCK_UN)
os.close(lock_fd)
PY
