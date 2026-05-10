#!/usr/bin/env python3
"""
clickup-spiegel.py — ClickUp-Worker für Status-Sync, Comments, Tasks
=====================================================================
Commands:
  bootstrap-space    Legt Space + Tasks-List an
  status             Status eines Tasks ändern (mit advance_only_from-Schutz)
  comment            Comment in Task posten
  fetch              Task-Details lesen
  create             Neuen Task anlegen
  sync-tasks         Generiert TASKS.md aus aktuellen Tasks
  extract-decisions  Liest DECISIONS.md, postet Blocks als Comments

Audit-Fix #4: Custom-Fields werden separate via bootstrap-clickup-fields.py erstellt.
"""
from __future__ import annotations
import os
import sys
import json
import argparse
import urllib.request
import urllib.parse
import urllib.error
from pathlib import Path
from typing import Any

CLICKUP_BASE = "https://api.clickup.com/api/v2"

STATUS_TRANSITIONS = {
    "TODO": ["IN PROGRESS", "BLOCKED"],
    "IN PROGRESS": ["READY-TO-DEPLOY", "BLOCKED", "TODO"],
    "READY-TO-DEPLOY": ["DEPLOYED-STAGE", "BLOCKED", "IN PROGRESS"],
    "DEPLOYED-STAGE": ["DONE", "BLOCKED"],
    "BLOCKED": ["TODO", "IN PROGRESS", "DONE"],
    "DONE": [],
}


def get_token() -> str:
    token = os.environ.get("CLICKUP_API_TOKEN", "").strip()
    if not token:
        die("CLICKUP_API_TOKEN nicht gesetzt")
    return token


def get_team_id() -> str:
    tid = os.environ.get("CLICKUP_TEAM_ID", "").strip()
    if not tid:
        die("CLICKUP_TEAM_ID nicht gesetzt")
    return tid


def die(msg: str, code: int = 1) -> None:
    print(f"❌ {msg}", file=sys.stderr)
    sys.exit(code)


def api_request(method: str, path: str, body: dict | None = None) -> Any:
    url = f"{CLICKUP_BASE}{path}"
    headers = {
        "Authorization": get_token(),
        "Content-Type": "application/json",
    }
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")

    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="ignore")
        die(f"ClickUp-API {method} {path} → {e.code}: {body}")
    except urllib.error.URLError as e:
        die(f"Network-Error: {e}")


def get_task_id_by_custom_id(custom_id: str) -> str | None:
    """Resolved Custom-ID (z.B. TODO-42) zu Internal-ID."""
    team_id = get_team_id()
    try:
        result = api_request(
            "GET",
            f"/task/{custom_id}?custom_task_ids=true&team_id={team_id}",
        )
        return result.get("id")
    except SystemExit:
        return None


def cmd_bootstrap_space(args: argparse.Namespace) -> int:
    team_id = get_team_id()
    space_name = args.space_name

    # Check existing spaces
    spaces = api_request("GET", f"/team/{team_id}/space?archived=false").get("spaces", [])
    existing = next((s for s in spaces if s["name"].lower() == space_name.lower()), None)
    if existing:
        space_id = existing["id"]
        print(f"ℹ️  Space '{space_name}' existiert bereits: {space_id}")
    else:
        result = api_request("POST", f"/team/{team_id}/space", {
            "name": space_name,
            "multiple_assignees": True,
            "features": {
                "due_dates": {"enabled": True, "start_date": True},
                "tags": {"enabled": True},
                "time_tracking": {"enabled": False},
                "custom_fields": {"enabled": True},
            },
        })
        space_id = result["id"]
        print(f"✅ Space '{space_name}' angelegt: {space_id}")

    # Create "Tasks" list
    folders = api_request("GET", f"/space/{space_id}/folder?archived=false").get("folders", [])
    lists = api_request("GET", f"/space/{space_id}/list?archived=false").get("lists", [])
    existing_list = next((l for l in lists if l["name"].lower() == "tasks"), None)
    if existing_list:
        list_id = existing_list["id"]
        print(f"ℹ️  Liste 'Tasks' existiert bereits: {list_id}")
    else:
        result = api_request("POST", f"/space/{space_id}/list", {
            "name": "Tasks",
            "content": "Master-Tasks-Liste mit Status-Field statt 4 Listen.",
        })
        list_id = result["id"]
        print(f"✅ Liste 'Tasks' angelegt: {list_id}")

    print()
    print("In .env eintragen:")
    print(f'  CLICKUP_SPACE_ID="{space_id}"')
    print(f'  CLICKUP_TASKS_LIST_ID="{list_id}"')
    print()
    print("Nächster Schritt: Custom-Fields anlegen")
    print(f"  python3 .claude/scripts/bootstrap-clickup-fields.py")
    return 0


def cmd_status(args: argparse.Namespace) -> int:
    task_id = get_task_id_by_custom_id(args.ticket) or args.ticket
    new_status = args.status.upper()

    # advance_only_from-Schutz
    if not args.force:
        try:
            current = api_request("GET", f"/task/{task_id}")
            current_status = current.get("status", {}).get("status", "").upper()
            allowed = STATUS_TRANSITIONS.get(current_status, [])
            if new_status not in [s.upper() for s in allowed]:
                die(
                    f"Status-Transition nicht erlaubt: {current_status} → {new_status}\n"
                    f"  Erlaubt: {', '.join(allowed) or '(keine)'}\n"
                    f"  Override: --force"
                )
        except SystemExit:
            pass

    api_request("PUT", f"/task/{task_id}", {"status": new_status})
    print(f"✅ Status: {args.ticket} → {new_status}")
    return 0


def cmd_comment(args: argparse.Namespace) -> int:
    task_id = get_task_id_by_custom_id(args.ticket) or args.ticket
    api_request("POST", f"/task/{task_id}/comment", {
        "comment_text": args.body,
        "notify_all": False,
    })
    print(f"✅ Comment posted: {args.ticket}")
    return 0


def cmd_fetch(args: argparse.Namespace) -> int:
    if args.ticket:
        task_id = get_task_id_by_custom_id(args.ticket) or args.ticket
        result = api_request("GET", f"/task/{task_id}")
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0
    if args.status:
        list_id = os.environ.get("CLICKUP_TASKS_LIST_ID")
        if not list_id:
            die("CLICKUP_TASKS_LIST_ID nicht gesetzt")
        result = api_request("GET", f"/list/{list_id}/task?statuses[]={urllib.parse.quote(args.status)}")
        for t in result.get("tasks", []):
            print(f"  {t.get('custom_id') or t['id']}: {t['name']} [{t.get('status', {}).get('status')}]")
        return 0
    die("--ticket oder --status required")


def cmd_create(args: argparse.Namespace) -> int:
    list_id = os.environ.get("CLICKUP_TASKS_LIST_ID")
    if not list_id:
        die("CLICKUP_TASKS_LIST_ID nicht gesetzt")
    body = {"name": args.title, "description": args.description, "status": args.status or "TODO"}
    result = api_request("POST", f"/list/{list_id}/task", body)
    print(f"✅ Task erstellt: {result.get('id')} — {args.title}")
    if "custom_id" in result:
        print(f"   Custom-ID: {result['custom_id']}")
    return 0


def cmd_sync_tasks(args: argparse.Namespace) -> int:
    list_id = os.environ.get("CLICKUP_TASKS_LIST_ID")
    if not list_id:
        die("CLICKUP_TASKS_LIST_ID nicht gesetzt")

    project_dir = Path(os.environ.get("CLAUDE_PROJECT_DIR", "."))
    out = project_dir / "TASKS.md"

    result = api_request("GET", f"/list/{list_id}/task?include_closed=false")
    tasks = result.get("tasks", [])

    grouped: dict[str, list] = {}
    for t in tasks:
        status = t.get("status", {}).get("status", "OTHER").upper()
        grouped.setdefault(status, []).append(t)

    lines = [f"<!-- AUTO-GENERATED via clickup-spiegel.py sync-tasks -->", "",
             f"# TASKS — {os.environ.get('APP_NAME', 'app')}", "",
             f"**Last Sync:** {os.popen('date -u +%Y-%m-%dT%H:%M:%SZ').read().strip()}", ""]

    order = ["IN PROGRESS", "READY-TO-DEPLOY", "BLOCKED", "TODO"]
    for status in order:
        if status in grouped:
            lines.append(f"## {status}")
            lines.append("")
            for t in grouped[status]:
                cid = t.get("custom_id") or t["id"][:8]
                lines.append(f"- **{cid}** — {t['name']}")
            lines.append("")

    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"✅ TASKS.md aktualisiert ({len(tasks)} Tasks)")
    return 0


def cmd_extract_decisions(args: argparse.Namespace) -> int:
    """Liest DECISIONS.md, postet jeden Block als Comment im jeweiligen Task. Idempotent."""
    import re
    import hashlib

    project_dir = Path(os.environ.get("CLAUDE_PROJECT_DIR", "."))
    decisions = project_dir / "DECISIONS.md"
    if not decisions.exists():
        print("ℹ️  Kein DECISIONS.md gefunden")
        return 0

    state_dir = project_dir / ".claude" / "state"
    state_dir.mkdir(parents=True, exist_ok=True)
    sig_file = state_dir / "decision-signatures.log"
    seen = set(sig_file.read_text(errors="ignore").splitlines()) if sig_file.exists() else set()

    content = decisions.read_text(encoding="utf-8")
    pattern = re.compile(r'(DECISION:\s*[^\n]+\n(?:[A-Z_]+:[^\n]*\n){2,}LAYER:\s*\d+)', re.MULTILINE)
    blocks = pattern.findall(content)

    posted = 0
    for block in blocks:
        sig = hashlib.sha256(block.encode()).hexdigest()[:16]
        if sig in seen:
            continue
        m = re.search(r'TICKET:\s*([A-Z]+-\d+)', block)
        if not m:
            continue
        ticket = m.group(1)
        task_id = get_task_id_by_custom_id(ticket)
        if not task_id:
            continue
        try:
            api_request("POST", f"/task/{task_id}/comment", {
                "comment_text": f"```\n{block}\n```",
                "notify_all": False,
            })
            with sig_file.open("a") as f:
                f.write(sig + "\n")
            posted += 1
        except SystemExit:
            pass

    print(f"✅ {posted} Decision-Blocks gepostet ({len(blocks)} total, {len(blocks)-posted} skipped)")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser("bootstrap-space")
    sp.add_argument("--space-name", required=True)

    sp = sub.add_parser("status")
    sp.add_argument("--ticket", required=True)
    sp.add_argument("--status", required=True)
    sp.add_argument("--force", action="store_true")

    sp = sub.add_parser("comment")
    sp.add_argument("--ticket", required=True)
    sp.add_argument("--body", required=True)

    sp = sub.add_parser("fetch")
    sp.add_argument("--ticket")
    sp.add_argument("--status")

    sp = sub.add_parser("create")
    sp.add_argument("--title", required=True)
    sp.add_argument("--description", default="")
    sp.add_argument("--status", default="TODO")

    sub.add_parser("sync-tasks")
    sub.add_parser("extract-decisions")

    args = p.parse_args()
    handler = globals()[f"cmd_{args.cmd.replace('-', '_')}"]
    return handler(args)


if __name__ == "__main__":
    sys.exit(main())
