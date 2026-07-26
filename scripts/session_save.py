#!/usr/bin/env python3
"""Deterministic local persistence kernel for Session Save System v2.

The model authors narrative Markdown. This kernel owns client namespaces,
record identity, atomic metadata writes, immutable operation events, derived
indexes, and copy-first legacy migration.
"""
from __future__ import annotations

import argparse
import datetime as dt
import fcntl
import hashlib
import json
import os
import re
import shutil
import stat
import sys
import tempfile
import unicodedata
import uuid
from contextlib import contextmanager
from pathlib import Path
from typing import Any

SCHEMA_VERSION = "2.0"
CLIENT_RE = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$")
STATUSES = {"provisional", "open", "closed", "stale"}
STATUS_MARKS = {"provisional": "🟡", "open": "🟢", "closed": "✅", "stale": "📦"}
CONTENT_FILES = ("tag.md", "checkpoints.md", "human.md", "agent.md")
PROJECT_LINE_RE = re.compile(r"^- \*\*(?P<name>(?:\\.|[^*])+)\*\*\s+—\s+(?P<description>.+)$")
PICKUP_REGISTRY_MAX = 1024 * 1024
PICKUP_ENVELOPE_MAX = 64 * 1024
PICKUP_FILE_MAX = 64 * 1024
PICKUP_TOTAL_MAX = 256 * 1024
PICKUP_PROJECT_MAX = 1000
PICKUP_SCAN_MAX = 5000
PICKUP_ERROR_MAX = 100
PICKUP_CHECKPOINT_MAX = 1000
PICKUP_RECORD_ID_RE = re.compile(r"^[0-9a-f]{32}$")
PICKUP_CHECKPOINT_RE = re.compile(r"^[0-9]{8}-[0-9]{6}-[0-9]{6}_[0-9a-f]{8}\.md$")


class UserError(Exception):
    pass


def now() -> dt.datetime:
    return dt.datetime.now().astimezone()


def iso_now() -> str:
    return now().isoformat(timespec="seconds")


def fail(message: str) -> None:
    raise UserError(message)


def config_path() -> Path:
    override = os.environ.get("SESSION_SAVE_CONFIG")
    if override:
        return Path(override).expanduser()
    return Path.home() / ".config" / "session-save" / "config.json"


def state_dir() -> Path:
    return Path(os.environ.get("SESSION_SAVE_STATE_DIR", Path.home() / ".local" / "state" / "session-save")).expanduser()


def upgrade_marker() -> Path:
    return state_dir() / "upgrade-in-progress"


def resolve_home(explicit: str | None = None) -> Path:
    if explicit:
        return Path(explicit).expanduser().resolve()
    for variable in ("SESSION_SAVE_HOME", "SAVE_SYSTEM_HOME"):
        if os.environ.get(variable):
            return Path(os.environ[variable]).expanduser().resolve()
    config = config_path()
    if config.is_file() and not config.is_symlink():
        try:
            value = json.loads(config.read_text()).get("home")
        except (OSError, json.JSONDecodeError) as exc:
            fail(f"cannot read config {config}: {exc}")
        if value:
            return Path(value).expanduser().resolve()
    legacy = Path.home() / ".claude" / "save-system-home"
    if legacy.is_file() and not legacy.is_symlink():
        value = legacy.read_text().strip()
        if value:
            return Path(value).expanduser().resolve()
    return (Path.home() / "Desktop" / "session-logs").resolve()


def safe_under(home: Path, candidate: Path) -> Path:
    """Reject lexical escapes and every existing symlink below the home."""
    home = home.resolve()
    candidate = Path(os.path.abspath(candidate.expanduser()))
    try:
        relative = candidate.relative_to(home)
    except ValueError:
        fail(f"path is outside Session Save home: {candidate}")
    current = home
    for part in relative.parts:
        current = current / part
        if current.is_symlink():
            fail(f"refusing path below symlink: {current}")
    return candidate


def initialize_home(home: Path) -> None:
    home.mkdir(parents=True, exist_ok=True)
    for relative in (
        "sessions", "events", "audits/global", "audits/by-client",
        ".session-save/migrations",
    ):
        safe_under(home, home / relative).mkdir(parents=True, exist_ok=True)
    version = safe_under(home, home / ".session-save" / "schema-version")
    if not version.exists():
        atomic_text(version, SCHEMA_VERSION + "\n")
    projects = home / "sessions" / "_PROJECTS.md"
    if not projects.exists():
        atomic_text(projects, "# Projects\n> User-approved project registry.\n")


@contextmanager
def mutation_lock(home: Path):
    """Serialize source-envelope and materialized-view mutations."""
    initialize_home(home)
    lock_path = home / ".session-save" / "write.lock"
    with lock_path.open("a+") as handle:
        os.chmod(lock_path, 0o600)
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def atomic_text(path: Path, content: str, mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        fail(f"refusing to replace symlink: {path}")
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary_path = Path(temporary)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary_path, mode)
        os.replace(temporary_path, path)
    finally:
        temporary_path.unlink(missing_ok=True)


def atomic_json(path: Path, value: Any) -> None:
    atomic_text(path, json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def safe_client(value: str) -> str:
    value = value.strip().lower()
    if not CLIENT_RE.fullmatch(value):
        fail("client ID must use lowercase letters, numbers, and single hyphens")
    return value


def safe_label(value: str, label: str) -> str:
    value = " ".join(value.strip().split())
    if not value or value in {".", ".."} or any(char in value for char in ("/", "\\", "\0")):
        fail(f"invalid {label}")
    return value


def slugify(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", safe_label(value, "slug source"))
    ascii_value = normalized.encode("ascii", "ignore").decode("ascii").lower()
    slug = re.sub(r"[^a-z0-9]+", "-", ascii_value).strip("-")
    if not slug:
        digest = hashlib.sha256(normalized.encode("utf-8")).hexdigest()[:12]
        slug = "session-" + digest
    return slug[:80].rstrip("-")


def project_folder(project: str) -> str:
    return slugify(project)


def project_key(project: str) -> str:
    return unicodedata.normalize("NFC", safe_label(project, "project")).lower()


def safe_project(value: str) -> str:
    return safe_label(value, "project")


def encode_project_name(value: str) -> str:
    return value.replace("\\", "\\\\").replace("*", "\\*")


def decode_project_name(value: str) -> str:
    return re.sub(r"\\(.)", r"\1", value)


def project_registry_path(home: Path) -> Path:
    return safe_under(home, home / "sessions" / "_PROJECTS.md")


def read_project_registry(home: Path) -> list[dict[str, str]]:
    path = project_registry_path(home)
    if not path.is_file() or path.is_symlink():
        return []
    projects: list[dict[str, str]] = []
    names: set[str] = set()
    keys: dict[str, str] = {}
    slugs: dict[str, str] = {}
    fence_char: str | None = None
    fence_length = 0
    for line in path.read_text(errors="replace").splitlines():
        fence = re.match(r"^ {0,3}(?P<run>`{3,}|~{3,})(?P<tail>.*)$", line)
        if fence:
            run = fence.group("run")
            tail = fence.group("tail")
            if fence_char is None:
                fence_char = run[0]
                fence_length = len(run)
            elif run[0] == fence_char and len(run) >= fence_length and not tail.strip():
                fence_char = None
                fence_length = 0
            continue
        if fence_char is not None or line.startswith((" ", "\t")):
            continue
        match = PROJECT_LINE_RE.fullmatch(line)
        if not match:
            if line.startswith("- **"):
                fail(f"malformed approved project registry entry: {line}")
            continue
        name = decode_project_name(match.group("name")).strip()
        if name in names:
            fail(f"duplicate approved project in registry: {name}")
        key = project_key(name)
        if key in keys and keys[key] != name:
            fail(f"approved projects differ only by letter case: {keys[key]} and {name}")
        slug = project_folder(name)
        if slug in slugs and slugs[slug] != name:
            fail(f"approved projects share one folder slug: {slugs[slug]} and {name}")
        names.add(name)
        keys[key] = name
        slugs[slug] = name
        projects.append({"name": name, "slug": slug, "description": match.group("description").strip()})
    if fence_char is not None:
        fail("project registry contains an unclosed Markdown fence")
    return projects


def project_inventory(home: Path) -> dict[str, Any]:
    approved = read_project_registry(home)
    approved_keys = {project_key(item["name"]) for item in approved}
    observed: set[str] = set()
    for path in record_paths(home):
        project = read_record(path).get("project")
        if project_key(project) not in approved_keys:
            observed.add(project)
    return {"approved": approved, "observed_unregistered": sorted(observed)}


def register_project(args: argparse.Namespace, home: Path) -> dict[str, Any]:
    initialize_home(home)
    project = safe_project(args.project)
    description = " ".join((args.description or "User-approved Session Save project").split())
    if not description or "\0" in description:
        fail("invalid project description")
    if len(description) > 240:
        fail("project description must be 240 characters or fewer")
    inventory = project_inventory(home)
    for item in inventory["approved"]:
        if project_key(item["name"]) == project_key(project):
            return {"project": item, "created": False, "registry": str(project_registry_path(home))}
        if item["slug"] == project_folder(project):
            fail(f"project folder slug already belongs to: {item['name']}")
    for observed in inventory["observed_unregistered"]:
        if project_folder(observed) == project_folder(project) and project_key(observed) != project_key(project):
            fail(f"existing record folder slug belongs to unregistered project: {observed}")
    path = project_registry_path(home)
    current = path.read_text()
    if current and not current.endswith("\n"):
        current += "\n"
    line = f"- **{encode_project_name(project)}** — {description} (first: {now().date().isoformat()})\n"
    atomic_text(path, current + line, mode=0o644)
    receipt_id = uuid.uuid4().hex
    receipt = safe_under(
        home,
        home / ".session-save" / "project-receipts" /
        f"{now().strftime('%Y%m%d-%H%M%S-%f')}_{receipt_id}.json",
    )
    atomic_json(receipt, {
        "schema_version": SCHEMA_VERSION,
        "receipt_id": receipt_id,
        "operation": "project-registered",
        "occurred_at": iso_now(),
        "project": project,
        "project_slug": project_folder(project),
    })
    return {
        "project": {"name": project, "slug": project_folder(project), "description": description},
        "created": True,
        "registry": str(path),
        "receipt": str(receipt),
    }


def require_registered_project(home: Path, project: str) -> dict[str, str]:
    project = safe_project(project)
    for item in read_project_registry(home):
        if project_key(item["name"]) == project_key(project):
            return item
    fail(f"project is not approved: {project}; select or register it explicitly")


def reject_project_slug_collision(home: Path, project: str) -> None:
    slug = project_folder(project)
    for item in read_project_registry(home):
        if item["slug"] == slug and project_key(item["name"]) != project_key(project):
            fail(f"project folder slug belongs to approved project: {item['name']}")


def within_home(home: Path, candidate: Path) -> Path:
    return safe_under(home, candidate)


def read_record(path: Path) -> dict[str, Any]:
    if path.is_dir():
        path = path / "record.json"
    if not path.is_file() or path.is_symlink():
        fail(f"record envelope not found: {path}")
    try:
        record = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"invalid record envelope {path}: {exc}")
    required = ("record_id", "client_id", "project", "session_slug", "name", "status")
    if any(not record.get(field) for field in required):
        fail(f"record envelope is missing required fields: {path}")
    return record


def record_paths(home: Path) -> list[Path]:
    sessions = home / "sessions"
    if not sessions.exists():
        return []
    paths: list[Path] = []
    for path in sessions.glob("*/*/*/record.json"):
        safe_path = safe_under(home, path)
        if safe_path.is_file() and not safe_path.is_symlink():
            paths.append(safe_path)
    return paths


def emit_event(home: Path, operation: str, record: dict[str, Any]) -> Path:
    timestamp = now()
    event_id = uuid.uuid4().hex
    relative = Path("events") / timestamp.strftime("%Y-%m-%d") / (
        timestamp.strftime("%H%M%S-%f") + f"_{event_id}.json"
    )
    payload = {
        "schema_version": SCHEMA_VERSION,
        "event_id": event_id,
        "operation": operation,
        "occurred_at": timestamp.isoformat(timespec="microseconds"),
        "record_id": record["record_id"],
        "client_id": record["client_id"],
        "project": record["project"],
        "session_slug": record["session_slug"],
        "status": record["status"],
    }
    atomic_json(safe_under(home, home / relative), payload)
    return relative


def markdown_cell(value: Any) -> str:
    return str(value or "").replace("|", "\\|").replace("\n", " ").strip()


def rebuild_index(home: Path) -> dict[str, Any]:
    initialize_home(home)
    records: list[tuple[dict[str, Any], Path]] = []
    errors: list[str] = []
    for envelope in record_paths(home):
        try:
            records.append((read_record(envelope), envelope.parent))
        except UserError as exc:
            errors.append(str(exc))
    records.sort(key=lambda item: item[0].get("updated_at", ""), reverse=True)
    lines = [
        "# Session Index",
        "> Generated from source-owned record envelopes. Run `session-save rebuild` at any time.",
        "> 🟡 provisional · 🟢 open · ✅ closed · 📦 stale",
        "",
        "| State | Updated | Project | Client | Session | Gist | Folder |",
        "|---|---|---|---|---|---|---|",
    ]
    for record, directory in records:
        relative = directory.relative_to(home).as_posix()
        status = record.get("status", "open")
        lines.append(
            f"| {STATUS_MARKS.get(status, '•')} {markdown_cell(status)} "
            f"| {markdown_cell(record.get('updated_at'))} "
            f"| {markdown_cell(record.get('project'))} "
            f"| `{markdown_cell(record.get('client_id'))}` "
            f"| {markdown_cell(record.get('name'))} "
            f"| {markdown_cell(record.get('gist'))} "
            f"| [{relative}]({relative}) |"
        )
    atomic_text(home / "_INDEX.md", "\n".join(lines) + "\n", mode=0o644)
    state = {
        "schema_version": SCHEMA_VERSION,
        "rebuilt_at": iso_now(),
        "records": len(records),
        "errors": errors,
    }
    atomic_json(home / ".session-save" / "view-state.json", state)
    return state


def find_existing(home: Path, client: str, session_id: str | None, slug: str) -> list[Path]:
    matches: list[Path] = []
    for envelope in record_paths(home):
        record = read_record(envelope)
        if record["client_id"] != client:
            continue
        if session_id and record.get("provider_session_id") == session_id:
            matches.append(envelope.parent)
        elif not session_id and record.get("session_slug") == slug:
            matches.append(envelope.parent)
    return matches


def begin_record(args: argparse.Namespace, home: Path) -> dict[str, Any]:
    initialize_home(home)
    client = safe_client(args.client)
    project = safe_project(args.project) if args.require_registered_project else safe_label(args.project, "project")
    name = safe_label(args.name, "name")
    slug = slugify(args.slug or name)
    session_id = safe_label(args.session_id, "session ID") if args.session_id else None
    status = args.status
    if status not in STATUSES:
        fail(f"unknown status: {status}")
    reject_project_slug_collision(home, project)
    approved_project = require_registered_project(home, project) if args.require_registered_project else None
    canonical_project = approved_project["name"] if approved_project else project
    matches = find_existing(home, client, session_id, slug)
    if len(matches) > 1:
        fail("multiple records match; provide a stable session ID or a different slug")
    timestamp = iso_now()
    if matches:
        directory = matches[0]
        record = read_record(directory)
        if project_key(record.get("project")) != project_key(canonical_project):
            fail("an existing record cannot move projects; create an explicit continuation instead")
        record.update({
            "name": name,
            "status": status,
            "updated_at": timestamp,
        })
        if session_id:
            record["provider_session_id"] = session_id
        operation = "record-reused"
    else:
        date = args.date or now().date().isoformat()
        try:
            parsed_date = dt.date.fromisoformat(date)
        except ValueError:
            fail("date must use ISO form YYYY-MM-DD")
        if date != parsed_date.isoformat():
            fail("date must use ISO form YYYY-MM-DD")
        project = canonical_project
        base = home / "sessions" / project_folder(project) / client / f"{date}_{slug}"
        directory = base
        if directory.exists():
            directory = Path(str(base) + "--" + uuid.uuid4().hex[:8])
        directory = safe_under(home, directory)
        directory.mkdir(parents=True, exist_ok=False)
        record = {
            "schema_version": SCHEMA_VERSION,
            "record_id": uuid.uuid4().hex,
            "client_id": client,
            "client_surface": args.surface,
            "model_id": args.model,
            "provider_session_id": session_id,
            "project": project,
            "session_slug": slug,
            "name": name,
            "status": status,
            "gist": args.gist or "",
            "created_at": timestamp,
            "updated_at": timestamp,
            "continuation_of": args.continuation_of,
            "capabilities": {
                "context_read": True,
                "session_id": bool(session_id),
                "rename": False,
                "archive": False,
                "filesystem_write": True,
            },
        }
        operation = "record-created"
    if args.gist is not None:
        record["gist"] = args.gist
    atomic_json(directory / "record.json", record)
    event = emit_event(home, operation, record)
    rebuild_index(home)
    return {"record": record, "path": str(directory), "event": str(home / event)}


def locate_record(args: argparse.Namespace, home: Path) -> dict[str, Any]:
    client = safe_client(args.client)
    slug = slugify(args.slug) if args.slug else ""
    session_id = safe_label(args.session_id, "session ID") if args.session_id else None
    if not session_id and not slug:
        fail("locate requires --session-id or --slug")
    matches = find_existing(home, client, session_id, slug)
    if not matches:
        fail("no matching record; run session-tag or session-save first")
    if len(matches) > 1:
        fail("multiple records match; provide the stable session ID")
    directory = matches[0]
    return {"record": read_record(directory), "path": str(directory)}


def require_record_client(record: dict[str, Any], requested: str) -> str:
    client = safe_client(requested)
    if record.get("client_id") != client:
        fail(f"record belongs to {record.get('client_id')}, not {client}")
    return client


def sync_record(args: argparse.Namespace, home: Path) -> dict[str, Any]:
    directory = within_home(home, Path(args.record))
    record = read_record(directory)
    require_record_client(record, args.client)
    if args.status:
        if args.status not in STATUSES:
            fail(f"unknown status: {args.status}")
        record["status"] = args.status
    if args.gist is not None:
        record["gist"] = args.gist
    if args.name:
        record["name"] = safe_label(args.name, "name")
    record["updated_at"] = iso_now()
    atomic_json(directory / "record.json", record)
    event = emit_event(home, args.operation, record)
    state = rebuild_index(home)
    return {"record": record, "path": str(directory), "event": str(home / event), "view": state}


def checkpoint_path(args: argparse.Namespace, home: Path) -> dict[str, str]:
    directory = within_home(home, Path(args.record))
    record = read_record(directory)
    require_record_client(record, args.client)
    timestamp = now().strftime("%Y%m%d-%H%M%S-%f")
    path = directory / "checkpoints" / f"{timestamp}_{uuid.uuid4().hex[:8]}.md"
    path = safe_under(home, path)
    path.parent.mkdir(parents=True, exist_ok=True)
    return {"path": str(path)}


def first_heading(path: Path) -> str | None:
    if not path.is_file():
        return None
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("# "):
            return line[2:].split(" — ", 1)[0].strip()
    return None


def frontmatter_value(path: Path, key: str) -> str | None:
    if not path.is_file():
        return None
    for line in path.read_text(errors="replace").splitlines()[:30]:
        if line.startswith(key + ":"):
            return line.split(":", 1)[1].strip().strip('"') or None
    return None


def legacy_candidates(home: Path, client: str) -> list[dict[str, Any]]:
    candidates: list[dict[str, Any]] = []
    sessions = home / "sessions"
    if not sessions.exists():
        return candidates
    for project_dir in sorted(sessions.iterdir()):
        if not project_dir.is_dir() or project_dir.is_symlink():
            continue
        for source in sorted(project_dir.iterdir()):
            if not source.is_dir() or source.is_symlink() or source.name == client:
                continue
            if not any((source / filename).is_file() for filename in CONTENT_FILES):
                continue
            tag = source / "tag.md"
            project_name = frontmatter_value(tag, "project") or project_dir_name(project_dir.name)
            destination = sessions / project_folder(project_name) / client / source.name
            if (destination / "record.json").is_file():
                continue
            symlinks = [str(path) for path in source.rglob("*") if path.is_symlink()]
            candidates.append({"source": str(source), "destination": str(destination), "symlinks": symlinks})
    return candidates


def migrate_v1(args: argparse.Namespace, home: Path) -> dict[str, Any]:
    initialize_home(home)
    client = safe_client(args.client)
    candidates = legacy_candidates(home, client)
    if args.dry_run:
        return {"mode": "dry-run", "client": client, "candidates": candidates, "count": len(candidates)}
    migrated: list[dict[str, str]] = []
    skipped: list[dict[str, str]] = []
    for item in candidates:
        source = Path(item["source"])
        destination = Path(item["destination"])
        if destination.exists():
            skipped.append({**item, "reason": "destination exists"})
            continue
        if item.get("symlinks"):
            skipped.append({**item, "reason": "legacy record contains symlinks"})
            continue
        destination = safe_under(home, destination)
        destination.parent.mkdir(parents=True, exist_ok=True)
        staging = safe_under(home, home / ".session-save" / "migration-staging" / uuid.uuid4().hex)
        staging.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source, staging)
        tag = staging / "tag.md"
        raw_slug = source.name.split("_", 1)[-1]
        slug = frontmatter_value(tag, "session_slug") or slugify(raw_slug)
        project = frontmatter_value(tag, "project") or project_dir_name(source.parent.name)
        name = frontmatter_value(tag, "name") or first_heading(tag) or f"{project} {raw_slug.replace('-', ' ').title()}"
        status = frontmatter_value(tag, "status") or ("closed" if (destination / "human.md").exists() else "open")
        if status not in STATUSES:
            status = "open"
        timestamp = iso_now()
        record = {
            "schema_version": SCHEMA_VERSION,
            "record_id": uuid.uuid4().hex,
            "client_id": client,
            "client_surface": "legacy-v1",
            "model_id": None,
            "provider_session_id": frontmatter_value(tag, "session_id"),
            "project": project,
            "session_slug": slug,
            "name": name,
            "status": status,
            "gist": "Migrated from Session Save v1; source preserved.",
            "created_at": timestamp,
            "updated_at": timestamp,
            "continuation_of": None,
            "capabilities": {
                "context_read": True,
                "session_id": bool(frontmatter_value(tag, "session_id")),
                "rename": False,
                "archive": False,
                "filesystem_write": True,
            },
            "migration": {"source": str(source), "copied_at": timestamp},
        }
        atomic_json(staging / "record.json", record)
        try:
            os.rename(staging, destination)
        except Exception:
            shutil.rmtree(staging, ignore_errors=True)
            raise
        emit_event(home, "legacy-record-copied", record)
        migrated.append(item)
    state = rebuild_index(home)
    receipt = {
        "schema_version": SCHEMA_VERSION,
        "migrated_at": iso_now(),
        "client": client,
        "migrated": migrated,
        "skipped": skipped,
        "source_records_preserved": True,
        "view": state,
    }
    receipt_path = home / ".session-save" / "migrations" / f"v1-{now().strftime('%Y%m%d-%H%M%S')}.json"
    atomic_json(receipt_path, receipt)
    receipt["receipt"] = str(receipt_path)
    return receipt


def project_dir_name(value: str) -> str:
    return value.replace("-", " ").strip().title() or "Unconfirmed"


def _pickup_open_dir_path(path: Path) -> int:
    """Open an absolute directory without following any path component."""
    path = Path(os.path.abspath(path.expanduser()))
    if path.is_symlink():
        fail(f"Pickup root cannot be a symlink: {path}")
    # Normalize platform aliases such as macOS /tmp -> /private/tmp without following the final root.
    path = path.parent.resolve() / path.name
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
    nofollow = getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(os.sep, flags)
    try:
        for part in path.parts[1:]:
            next_fd = os.open(part, flags | nofollow, dir_fd=fd)
            os.close(fd)
            fd = next_fd
        info = os.fstat(fd)
        if not stat.S_ISDIR(info.st_mode):
            fail(f"Pickup root is not a directory: {path}")
        return fd
    except Exception:
        os.close(fd)
        raise


def _pickup_open_dir_at(parent_fd: int, name: str) -> int:
    if not name or name in {".", ".."} or "/" in name or "\0" in name:
        fail("unsafe directory entry during Pickup")
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(name, flags, dir_fd=parent_fd)
    if not stat.S_ISDIR(os.fstat(fd).st_mode):
        os.close(fd)
        fail(f"Pickup entry is not a directory: {name}")
    return fd


def _pickup_read_at(parent_fd: int, name: str, maximum: int) -> tuple[bytes, os.stat_result]:
    if not name or name in {".", ".."} or "/" in name or "\0" in name:
        fail("unsafe file entry during Pickup")
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(name, flags, dir_fd=parent_fd)
    try:
        before = os.fstat(fd)
        if not stat.S_ISREG(before.st_mode):
            fail(f"Pickup source is not a regular file: {name}")
        if before.st_size > maximum:
            fail(f"Pickup source exceeds {maximum} bytes: {name}")
        chunks: list[bytes] = []
        size = 0
        while True:
            chunk = os.read(fd, min(65536, maximum + 1 - size))
            if not chunk:
                break
            chunks.append(chunk)
            size += len(chunk)
            if size > maximum:
                fail(f"Pickup source grew beyond {maximum} bytes: {name}")
        after = os.fstat(fd)
        if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (
            after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns
        ) or size != after.st_size:
            fail(f"Pickup source changed while being read: {name}")
        return b"".join(chunks), after
    finally:
        os.close(fd)


def _pickup_read_path(path: Path, maximum: int) -> bytes | None:
    try:
        parent_fd = _pickup_open_dir_path(path.parent)
    except FileNotFoundError:
        return None
    try:
        try:
            data, _ = _pickup_read_at(parent_fd, path.name, maximum)
            return data
        except FileNotFoundError:
            return None
    finally:
        os.close(parent_fd)


def resolve_pickup_home(explicit: str | None = None) -> Path:
    raw = explicit
    if not raw:
        for variable in ("SESSION_SAVE_HOME", "SAVE_SYSTEM_HOME"):
            if os.environ.get(variable):
                raw = os.environ[variable]
                break
    if not raw:
        config = config_path()
        data = _pickup_read_path(config, PICKUP_ENVELOPE_MAX)
        if data is not None:
            try:
                payload = json.loads(data.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as exc:
                fail(f"cannot read Pickup config {config}: {exc}")
            raw = payload.get("home") if isinstance(payload, dict) else None
            if raw is not None and not isinstance(raw, str):
                fail("Session Save config home must be a string")
    if not raw:
        legacy = Path.home() / ".claude" / "save-system-home"
        data = _pickup_read_path(legacy, PICKUP_ENVELOPE_MAX)
        if data is not None:
            try:
                raw = data.decode("utf-8").strip()
            except UnicodeDecodeError as exc:
                fail(f"cannot read legacy home pointer: {exc}")
    if not raw:
        raw = str(Path.home() / "Desktop" / "session-logs")
    home = Path(os.path.abspath(Path(raw).expanduser()))
    if home.is_symlink():
        fail(f"Pickup root cannot be a symlink: {home}")
    home = home.parent.resolve() / home.name
    try:
        fd = _pickup_open_dir_path(home)
    except FileNotFoundError:
        fail(f"Session Save home does not exist: {home}")
    else:
        os.close(fd)
    return home


def _pickup_parse_registry(text: str) -> list[dict[str, str]]:
    projects: list[dict[str, str]] = []
    names: set[str] = set()
    keys: dict[str, str] = {}
    slugs: dict[str, str] = {}
    fence_char: str | None = None
    fence_length = 0
    for line in text.splitlines():
        fence = re.match(r"^ {0,3}(?P<run>`{3,}|~{3,})(?P<tail>.*)$", line)
        if fence:
            run, tail = fence.group("run"), fence.group("tail")
            if fence_char is None:
                fence_char, fence_length = run[0], len(run)
            elif run[0] == fence_char and len(run) >= fence_length and not tail.strip():
                fence_char, fence_length = None, 0
            continue
        if fence_char is not None or line.startswith((" ", "\t")):
            continue
        match = PROJECT_LINE_RE.fullmatch(line)
        if not match:
            if line.startswith("- **"):
                fail(f"malformed approved project registry entry: {line}")
            continue
        name = decode_project_name(match.group("name")).strip()
        key, slug = project_key(name), project_folder(name)
        if name in names or key in keys or slug in slugs:
            fail(f"duplicate or colliding approved project: {name}")
        names.add(name)
        keys[key], slugs[slug] = name, name
        projects.append({"name": name, "slug": slug, "description": match.group("description").strip()})
        if len(projects) > PICKUP_PROJECT_MAX:
            fail(f"Pickup project registry exceeds {PICKUP_PROJECT_MAX} entries")
    if fence_char is not None:
        fail("project registry contains an unclosed Markdown fence")
    return projects


def _pickup_timestamp(value: Any, field: str) -> dt.datetime:
    if not isinstance(value, str):
        fail(f"{field} must be a string")
    try:
        parsed = dt.datetime.fromisoformat(value)
    except ValueError:
        fail(f"{field} is not an ISO timestamp")
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        fail(f"{field} must include a timezone")
    utc = parsed.astimezone(dt.timezone.utc)
    if utc < dt.datetime(1970, 1, 1, tzinfo=dt.timezone.utc):
        fail(f"{field} predates 1970")
    if utc > dt.datetime.now(dt.timezone.utc) + dt.timedelta(hours=24):
        fail(f"{field} is more than 24 hours in the future")
    return utc


def _pickup_validate_record(
    payload: Any, project_entry: dict[str, str], project_dir: str, client_dir: str, record_dir: str
) -> dict[str, Any]:
    if not isinstance(payload, dict):
        fail("record envelope must be an object")
    required_types = {
        "schema_version": str, "record_id": str, "client_id": str, "project": str,
        "session_slug": str, "name": str, "status": str, "created_at": str, "updated_at": str,
    }
    for field, expected in required_types.items():
        if type(payload.get(field)) is not expected:
            fail(f"record field {field} has the wrong type")
    if payload["schema_version"] != SCHEMA_VERSION:
        fail(f"unsupported record schema: {payload['schema_version']}")
    if not PICKUP_RECORD_ID_RE.fullmatch(payload["record_id"]):
        fail("record_id must be 32 lowercase hexadecimal characters")
    client = safe_client(payload["client_id"])
    if client != client_dir:
        fail("record client does not match its physical client directory")
    project = safe_project(payload["project"])
    if project_key(project) != project_key(project_entry["name"]):
        fail("record project does not match the selected approved project")
    if project_dir.lower() != project_entry["slug"].lower():
        fail("record project folder does not match its approved project slug")
    slug = safe_label(payload["session_slug"], "session slug")
    if len(slug) > 80 or slugify(slug) != slug:
        fail("record session_slug is not canonical")
    if not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}_.+", record_dir):
        fail("record directory lacks an ISO date prefix")
    expected = record_dir[11:].split("--", 1)[0]
    if expected != slug:
        fail("record session_slug does not match its physical directory")
    if not payload["name"].strip() or len(payload["name"]) > 512:
        fail("record name is empty or too long")
    if payload["status"] not in STATUSES:
        fail("record status is invalid")
    created = _pickup_timestamp(payload["created_at"], "created_at")
    updated = _pickup_timestamp(payload["updated_at"], "updated_at")
    if updated < created:
        fail("record updated_at is earlier than created_at")
    clean = dict(payload)
    clean["_created_utc"] = created
    clean["_updated_utc"] = updated
    return clean


def _pickup_error(errors: list[dict[str, str]], path: Path, message: str) -> None:
    if len(errors) >= PICKUP_ERROR_MAX:
        fail(f"Pickup malformed-record errors exceed {PICKUP_ERROR_MAX}; no partial ranking returned")
    errors.append({"path": str(path), "error": message})


def _pickup_names(directory_fd: int, maximum: int, label: str) -> list[str]:
    names: list[str] = []
    with os.scandir(directory_fd) as entries:
        for entry in entries:
            names.append(entry.name)
            if len(names) > maximum:
                fail(f"{label} exceeds {maximum} entries")
    return sorted(names)


def _pickup_scan(home: Path) -> tuple[list[dict[str, str]], list[dict[str, Any]], list[dict[str, str]], int]:
    root_fd = _pickup_open_dir_path(home)
    errors: list[dict[str, str]] = []
    records: list[dict[str, Any]] = []
    seen_ids: dict[str, Path] = {}
    duplicate_ids: set[str] = set()
    scanned = 0
    try:
        sessions_fd = _pickup_open_dir_at(root_fd, "sessions")
        try:
            registry_data, _ = _pickup_read_at(sessions_fd, "_PROJECTS.md", PICKUP_REGISTRY_MAX)
            try:
                projects = _pickup_parse_registry(registry_data.decode("utf-8"))
            except UnicodeDecodeError as exc:
                fail(f"project registry is not UTF-8: {exc}")
            session_names = _pickup_names(sessions_fd, PICKUP_SCAN_MAX, "Pickup sessions directory")
            scanned += len(session_names)
            actual_dirs = {name.lower(): name for name in session_names if name != "_PROJECTS.md"}
            for project in projects:
                physical = actual_dirs.get(project["slug"].lower())
                if not physical:
                    continue
                try:
                    project_fd = _pickup_open_dir_at(sessions_fd, physical)
                except OSError as exc:
                    _pickup_error(errors, home / "sessions" / physical, str(exc))
                    continue
                try:
                    client_names = _pickup_names(project_fd, PICKUP_SCAN_MAX - scanned, "Pickup directory scan")
                    for client_name in client_names:
                        # Copy-first migration preserves legacy v1 record directories beside client namespaces.
                        if re.match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}_", client_name) or client_name.startswith("_"):
                            continue
                        scanned += 1
                        if scanned > PICKUP_SCAN_MAX:
                            fail(f"Pickup directory scan exceeds {PICKUP_SCAN_MAX} entries")
                        try:
                            safe_client(client_name)
                            client_fd = _pickup_open_dir_at(project_fd, client_name)
                        except (OSError, UserError) as exc:
                            _pickup_error(errors, home / "sessions" / physical / client_name, str(exc))
                            continue
                        try:
                            record_names = _pickup_names(client_fd, PICKUP_SCAN_MAX - scanned, "Pickup directory scan")
                            for record_name in record_names:
                                scanned += 1
                                if scanned > PICKUP_SCAN_MAX:
                                    fail(f"Pickup directory scan exceeds {PICKUP_SCAN_MAX} entries")
                                record_path = home / "sessions" / physical / client_name / record_name
                                try:
                                    record_fd = _pickup_open_dir_at(client_fd, record_name)
                                    try:
                                        raw, _ = _pickup_read_at(record_fd, "record.json", PICKUP_ENVELOPE_MAX)
                                    finally:
                                        os.close(record_fd)
                                    payload = json.loads(raw.decode("utf-8"))
                                    record = _pickup_validate_record(payload, project, physical, client_name, record_name)
                                    if record["record_id"] in seen_ids:
                                        duplicate_ids.add(record["record_id"])
                                        fail(f"duplicate record ID also appears at {seen_ids[record['record_id']]}")
                                    seen_ids[record["record_id"]] = record_path
                                    records.append({
                                        "record": record,
                                        "envelope_sha256": hashlib.sha256(raw).hexdigest(),
                                        "project": project["name"],
                                        "path": record_path,
                                        "relative": ("sessions", physical, client_name, record_name),
                                    })
                                except (OSError, UnicodeDecodeError, json.JSONDecodeError, UserError) as exc:
                                    _pickup_error(errors, record_path / "record.json", str(exc))
                        finally:
                            os.close(client_fd)
                finally:
                    os.close(project_fd)
        finally:
            os.close(sessions_fd)
    finally:
        os.close(root_fd)
    if duplicate_ids:
        fail(f"duplicate record IDs make Pickup ambiguous: {', '.join(sorted(duplicate_ids))}")
    records.sort(key=lambda item: (
        item["record"]["_updated_utc"], item["record"]["client_id"], item["record"]["record_id"]
    ), reverse=True)
    return projects, records, errors, scanned


def _pickup_record_fd(root_fd: int, relative: tuple[str, ...]) -> int:
    current = os.dup(root_fd)
    try:
        for part in relative:
            next_fd = _pickup_open_dir_at(current, part)
            os.close(current)
            current = next_fd
        return current
    except Exception:
        os.close(current)
        raise


def _pickup_narrative_metadata(home: Path, root_fd: int, item: dict[str, Any]) -> list[dict[str, Any]]:
    record_fd = _pickup_record_fd(root_fd, item["relative"])
    result: list[dict[str, Any]] = []
    try:
        def add_regular(parent_fd: int, filename: str, kind: str, relative_suffix: tuple[str, ...], legacy: bool = False) -> None:
            try:
                raw, info = _pickup_read_at(parent_fd, filename, PICKUP_FILE_MAX)
            except FileNotFoundError:
                return
            result.append({
                "kind": kind,
                "path": str(item["path"].joinpath(*relative_suffix)),
                "size": info.st_size,
                "sha256": hashlib.sha256(raw).hexdigest(),
                "legacy": legacy,
                "_relative": relative_suffix,
            })

        add_regular(record_fd, "tag.md", "tag", ("tag.md",))
        checkpoint_found = False
        try:
            checkpoints_fd = _pickup_open_dir_at(record_fd, "checkpoints")
        except FileNotFoundError:
            checkpoints_fd = None
        if checkpoints_fd is not None:
            try:
                names = _pickup_names(checkpoints_fd, PICKUP_CHECKPOINT_MAX, "checkpoint directory")
                valid = sorted((name for name in names if PICKUP_CHECKPOINT_RE.fullmatch(name)), reverse=True)
                if valid:
                    add_regular(checkpoints_fd, valid[0], "checkpoint", ("checkpoints", valid[0]))
                    checkpoint_found = True
            finally:
                os.close(checkpoints_fd)
        migration = item["record"].get("migration")
        legacy_marker = (
            isinstance(migration, dict)
            and isinstance(migration.get("source"), str)
            and bool(migration.get("source"))
            and isinstance(migration.get("copied_at"), str)
        )
        if not checkpoint_found and legacy_marker:
            add_regular(record_fd, "checkpoints.md", "checkpoint", ("checkpoints.md",), legacy=True)
        add_regular(record_fd, "human.md", "human-close", ("human.md",))
        add_regular(record_fd, "agent.md", "technical-note", ("agent.md",))
        return result
    finally:
        os.close(record_fd)


def _pickup_public_errors(errors: list[dict[str, str]]) -> list[dict[str, str]]:
    return [{
        "code": "invalid-record",
        "source_fingerprint": hashlib.sha256(item["path"].encode()).hexdigest(),
    } for item in errors]


def pickup_sources(args: argparse.Namespace, home: Path) -> dict[str, Any]:
    if args.limit < 1 or args.limit > 8:
        fail("Pickup limit must be from 1 through 8")
    if len(args.record_id) > 5:
        fail("Pickup accepts at most five exact record IDs")
    if args.include_content and not args.record_id:
        fail("--include-content requires at least one --record-id")
    if args.include_content and not args.selection_token:
        fail("--include-content requires the exact --selection-token from metadata disclosure")
    if args.selection_token and not args.include_content:
        fail("--selection-token is valid only with --include-content")
    if args.record_id and not args.project:
        fail("--record-id requires --project")
    projects, records, errors, scanned = _pickup_scan(home)
    public_errors = _pickup_public_errors(errors)
    by_key = {project_key(item["name"]): item for item in projects}
    if not args.project:
        latest: dict[str, dict[str, Any]] = {}
        for item in records:
            latest.setdefault(project_key(item["project"]), item)
        project_rows = []
        for project in projects:
            recent = latest.get(project_key(project["name"]))
            project_rows.append({
                "name": project["name"],
                "slug": project["slug"],
                "latest_updated_at": recent["record"]["updated_at"] if recent else None,
                "latest_client_id": recent["record"]["client_id"] if recent else None,
            })
        project_rows.sort(key=lambda item: (item["latest_updated_at"] is not None, item["latest_updated_at"] or "", item["name"]), reverse=True)
        return {"mode": "projects", "home": str(home), "projects": project_rows[:args.limit], "corrupt_records": public_errors, "corrupt_record_count": len(public_errors), "scanned_entries": scanned}
    key = project_key(args.project)
    if key not in by_key:
        fail(f"project is not approved: {safe_project(args.project)}; select or register it explicitly")
    canonical = by_key[key]["name"]
    candidates = [item for item in records if project_key(item["project"]) == key]
    if not args.record_id:
        rows = [{
            "record_id": item["record"]["record_id"],
            "client_id": item["record"]["client_id"],
            "project": canonical,
            "status": item["record"]["status"],
            "created_at": item["record"]["created_at"],
            "updated_at": item["record"]["updated_at"],
            "path": str(item["path"]),
        } for item in candidates[:args.limit]]
        return {"mode": "candidates", "home": str(home), "project": canonical, "candidates": rows, "corrupt_records": public_errors, "corrupt_record_count": len(public_errors), "scanned_entries": scanned}
    if len(set(args.record_id)) != len(args.record_id):
        fail("duplicate --record-id values are not allowed")
    lookup = {item["record"]["record_id"]: item for item in candidates}
    missing = [record_id for record_id in args.record_id if record_id not in lookup]
    if missing:
        fail(f"record IDs do not exist in approved project {canonical}: {', '.join(missing)}")
    selected = [lookup[record_id] for record_id in args.record_id]
    root_fd = _pickup_open_dir_path(home)
    try:
        prepared: list[tuple[dict[str, Any], list[dict[str, Any]]]] = []
        receipt: list[dict[str, Any]] = []
        for item in selected:
            narratives = _pickup_narrative_metadata(home, root_fd, item)
            prepared.append((item, narratives))
            receipt.append({
                "record_id": item["record"]["record_id"],
                "envelope_sha256": item["envelope_sha256"],
                "narratives": [{
                    "kind": narrative["kind"], "path": narrative["path"],
                    "size": narrative["size"], "sha256": narrative["sha256"],
                } for narrative in narratives],
            })
        token_payload = {"project": canonical, "records": receipt}
        selection_token = hashlib.sha256(json.dumps(token_payload, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        if args.include_content and args.selection_token != selection_token:
            fail("selected records changed after disclosure; list them again and request fresh consent")
        selected_rows = []
        total = 0
        for item, narratives in prepared:
            if args.include_content:
                record_fd = _pickup_record_fd(root_fd, item["relative"])
                try:
                    for narrative in narratives:
                        parent_fd = os.dup(record_fd)
                        try:
                            for component in narrative["_relative"][:-1]:
                                next_fd = _pickup_open_dir_at(parent_fd, component)
                                os.close(parent_fd)
                                parent_fd = next_fd
                            remaining = PICKUP_TOTAL_MAX - total
                            maximum = min(PICKUP_FILE_MAX, remaining)
                            if maximum < narrative["size"]:
                                fail(f"Pickup selected content exceeds {PICKUP_TOTAL_MAX} bytes")
                            raw, _ = _pickup_read_at(parent_fd, narrative["_relative"][-1], maximum)
                            if hashlib.sha256(raw).hexdigest() != narrative["sha256"]:
                                fail(f"Pickup narrative changed after disclosure: {narrative['path']}")
                            total += len(raw)
                            try:
                                narrative["content"] = raw.decode("utf-8")
                            except UnicodeDecodeError as exc:
                                fail(f"Pickup narrative is not UTF-8: {narrative['path']}: {exc}")
                        finally:
                            os.close(parent_fd)
                finally:
                    os.close(record_fd)
            for narrative in narratives:
                narrative.pop("_relative", None)
            row = {
                "record_id": item["record"]["record_id"],
                "client_id": item["record"]["client_id"],
                "project": canonical,
                "status": item["record"]["status"],
                "created_at": item["record"]["created_at"],
                "updated_at": item["record"]["updated_at"],
                "path": str(item["path"]),
                "narratives": narratives,
            }
            if args.include_content:
                row["name"] = item["record"]["name"]
            selected_rows.append(row)
    finally:
        os.close(root_fd)
    return {
        "mode": "content" if args.include_content else "selection",
        "home": str(home), "project": canonical, "selected": selected_rows,
        "selection_token": selection_token,
        "content_bytes": total, "content_limit": PICKUP_TOTAL_MAX,
        "corrupt_records": public_errors, "corrupt_record_count": len(public_errors), "scanned_entries": scanned,
    }


def audit_sources(args: argparse.Namespace, home: Path) -> dict[str, Any]:
    inventory = project_inventory(home)
    approved_by_key = {project_key(item["name"]): item["name"] for item in inventory["approved"]}
    cutoff = None
    if args.days:
        cutoff = now() - dt.timedelta(days=args.days)
    sources: list[dict[str, Any]] = []
    for envelope in record_paths(home):
        record = read_record(envelope)
        updated_raw = record.get("updated_at")
        if cutoff and updated_raw:
            try:
                updated = dt.datetime.fromisoformat(updated_raw)
                if updated < cutoff:
                    continue
            except ValueError:
                pass
        directory = envelope.parent
        canonical_project = approved_by_key.get(project_key(record.get("project")))
        sources.append({
            "record": record,
            "project_registered": canonical_project is not None,
            "approved_project": canonical_project,
            "path": str(directory),
            "tag": str(directory / "tag.md") if (directory / "tag.md").is_file() else None,
            "human": str(directory / "human.md") if (directory / "human.md").is_file() else None,
            "agent": str(directory / "agent.md") if (directory / "agent.md").is_file() else None,
        })
    sources.sort(key=lambda item: item["record"].get("updated_at", ""), reverse=True)
    unregistered = sorted({item["record"].get("project") for item in sources if not item["project_registered"]})
    return {
        "home": str(home),
        "sources": sources,
        "count": len(sources),
        "approved_projects": inventory["approved"],
        "unregistered_projects": unregistered,
    }


def write_audit(args: argparse.Namespace, home: Path) -> dict[str, str]:
    if not re.fullmatch(r"[0-9]{4}-W(?:0[1-9]|[1-4][0-9]|5[0-3])", args.week):
        fail("week must use ISO form YYYY-Www")
    source = Path(args.input).expanduser()
    if not source.is_file() or source.is_symlink():
        fail(f"audit input must be a regular file: {source}")
    content = source.read_text()
    if not content.strip():
        fail("audit input is empty")
    destination = safe_under(home, home / "audits" / "global" / f"{args.week}_audit.md")
    atomic_text(destination, content, mode=0o644)
    return {"path": str(destination), "written_at": iso_now()}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", help="override the shared Session Save home")
    sub = parser.add_subparsers(dest="command", required=True)

    home_parser = sub.add_parser("home", help="resolve the shared home")
    home_parser.add_argument("--init", action="store_true")

    doctor = sub.add_parser("doctor", help="validate a client and shared home")
    doctor.add_argument("--client", required=True)

    begin = sub.add_parser("begin", help="create or reuse a client-namespaced record")
    begin.add_argument("--client", required=True)
    begin.add_argument("--project", required=True)
    begin.add_argument("--name", required=True)
    begin.add_argument("--slug")
    begin.add_argument("--session-id")
    begin.add_argument("--status", default="open", choices=sorted(STATUSES))
    begin.add_argument("--gist")
    begin.add_argument("--date")
    begin.add_argument("--surface", default="local")
    begin.add_argument("--model")
    begin.add_argument("--continuation-of")
    begin.add_argument(
        "--require-registered-project",
        action="store_true",
        help="fail unless --project exactly matches the user-approved registry",
    )

    sub.add_parser("project-list", help="list approved and observed unregistered project names")
    project_check = sub.add_parser("project-check", help="require one exact approved project name")
    project_check.add_argument("--project", required=True)
    project_register = sub.add_parser("project-register", help="register one explicitly approved project")
    project_register.add_argument("--project", required=True)
    project_register.add_argument("--description")

    locate = sub.add_parser("locate", help="find an existing client-namespaced record")
    locate.add_argument("--client", required=True)
    locate.add_argument("--session-id")
    locate.add_argument("--slug")

    sync = sub.add_parser("sync", help="update metadata and rebuild global views")
    sync.add_argument("--client", required=True)
    sync.add_argument("--record", required=True)
    sync.add_argument("--status", choices=sorted(STATUSES))
    sync.add_argument("--gist")
    sync.add_argument("--name")
    sync.add_argument("--operation", default="record-synced")

    checkpoint = sub.add_parser("checkpoint-path", help="allocate an immutable checkpoint path")
    checkpoint.add_argument("--client", required=True)
    checkpoint.add_argument("--record", required=True)

    sub.add_parser("rebuild", help="rebuild the global index from record envelopes")

    migrate = sub.add_parser("migrate-v1", help="copy legacy records into a client namespace")
    migrate.add_argument("--client", default="claude")
    mode = migrate.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--apply", action="store_true")

    pickup = sub.add_parser("pickup-sources", help="list or read bounded sources for read-only Pickup")
    pickup.add_argument("--project")
    pickup.add_argument("--record-id", action="append", default=[])
    pickup.add_argument("--limit", type=int, default=8)
    pickup.add_argument("--include-content", action="store_true")
    pickup.add_argument("--selection-token")

    audit = sub.add_parser("audit-sources", help="list source-attributed records for audit")
    audit.add_argument("--days", type=int, default=7)

    write_audit_parser = sub.add_parser("write-audit", help="atomically publish a global audit")
    write_audit_parser.add_argument("--week", required=True)
    write_audit_parser.add_argument("--input", required=True)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        marker = upgrade_marker()
        if marker.exists() or marker.is_symlink():
            fail(f"Session Save upgrade or recovery is in progress: {marker}")
        home = resolve_pickup_home(args.home) if args.command == "pickup-sources" else resolve_home(args.home)
        if args.command == "home":
            if args.init:
                initialize_home(home)
            result: Any = {"home": str(home), "initialized": bool(args.init)}
        elif args.command == "doctor":
            client = safe_client(args.client)
            initialize_home(home)
            legacy = legacy_candidates(home, "claude")
            result = {
                "ok": not legacy,
                "client": client,
                "home": str(home),
                "schema_version": SCHEMA_VERSION,
                "writable": os.access(home, os.W_OK),
                "records": len(record_paths(home)),
                "migration_required": len(legacy),
                "message": "run migrate-v1 --client claude --dry-run before saving" if legacy else "ready",
            }
        elif args.command == "begin":
            with mutation_lock(home):
                result = begin_record(args, home)
        elif args.command == "project-list":
            result = project_inventory(home)
        elif args.command == "project-check":
            result = {"project": require_registered_project(home, args.project), "approved": True}
        elif args.command == "project-register":
            with mutation_lock(home):
                result = register_project(args, home)
        elif args.command == "locate":
            result = locate_record(args, home)
        elif args.command == "sync":
            with mutation_lock(home):
                result = sync_record(args, home)
        elif args.command == "checkpoint-path":
            result = checkpoint_path(args, home)
        elif args.command == "rebuild":
            with mutation_lock(home):
                result = rebuild_index(home)
        elif args.command == "migrate-v1":
            if args.dry_run:
                result = migrate_v1(args, home)
            else:
                with mutation_lock(home):
                    result = migrate_v1(args, home)
        elif args.command == "pickup-sources":
            result = pickup_sources(args, home)
        elif args.command == "audit-sources":
            result = audit_sources(args, home)
        elif args.command == "write-audit":
            with mutation_lock(home):
                result = write_audit(args, home)
        else:
            parser.error("unknown command")
            return 2
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0
    except (UserError, OSError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
