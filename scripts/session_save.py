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
import json
import os
import re
import shutil
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
        slug = "session-" + uuid.uuid4().hex[:8]
    return slug[:80].rstrip("-")


def project_folder(project: str) -> str:
    return slugify(project)


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
    project = safe_label(args.project, "project")
    name = safe_label(args.name, "name")
    slug = slugify(args.slug or name)
    session_id = safe_label(args.session_id, "session ID") if args.session_id else None
    status = args.status
    if status not in STATUSES:
        fail(f"unknown status: {status}")
    matches = find_existing(home, client, session_id, slug)
    if len(matches) > 1:
        fail("multiple records match; provide a stable session ID or a different slug")
    timestamp = iso_now()
    if matches:
        directory = matches[0]
        record = read_record(directory)
        if record.get("project") != project:
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


def audit_sources(args: argparse.Namespace, home: Path) -> dict[str, Any]:
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
        sources.append({
            "record": record,
            "path": str(directory),
            "tag": str(directory / "tag.md") if (directory / "tag.md").is_file() else None,
            "human": str(directory / "human.md") if (directory / "human.md").is_file() else None,
            "agent": str(directory / "agent.md") if (directory / "agent.md").is_file() else None,
        })
    sources.sort(key=lambda item: item["record"].get("updated_at", ""), reverse=True)
    return {"home": str(home), "sources": sources, "count": len(sources)}


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
        home = resolve_home(args.home)
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
    except UserError as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
