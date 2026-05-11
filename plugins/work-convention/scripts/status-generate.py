#!/usr/bin/env python3
"""
status-generate.py — Erzeugt STATUS.md oder Slack-JSON
======================================================
Modi:
  --mode markdown   STATUS.md-Format
  --mode slack-json Slack-Block-Kit-JSON
"""
from __future__ import annotations
import os
import sys
import json
import argparse
import subprocess
from pathlib import Path
from datetime import datetime, timezone


def get_state(project_dir: Path) -> dict:
    state_dir = project_dir / ".claude" / "state"
    state: dict = {}

    # Identity
    identity_file = state_dir / "session-identity.json"
    if identity_file.exists():
        state["identity"] = json.loads(identity_file.read_text())

    # Escalation counter
    counter_file = state_dir / "escalation-counter.state"
    state["escalation_count"] = int(counter_file.read_text()) if counter_file.exists() else 0

    # Hard-trigger
    state["hard_trigger"] = (state_dir / "escalation-3fail.flag").exists()
    state["solver_active"] = (state_dir / "solver-activated.flag").exists()

    # Active ticket
    ticket_file = state_dir / "active-ticket.txt"
    state["active_ticket"] = ticket_file.read_text().strip() if ticket_file.exists() else None

    # Git status
    try:
        branch = subprocess.check_output(["git", "branch", "--show-current"], cwd=project_dir, text=True).strip()
        head = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=project_dir, text=True).strip()
        changes = subprocess.check_output(["git", "status", "--porcelain"], cwd=project_dir, text=True)
        state["git"] = {"branch": branch, "head": head, "uncommitted": len([l for l in changes.splitlines() if l.strip()])}
    except subprocess.CalledProcessError:
        state["git"] = {"branch": "?", "head": "?", "uncommitted": 0}

    # Open Blockers
    blockers = project_dir / "BLOCKERS.md"
    if blockers.exists():
        content = blockers.read_text()
        # Naive parse — Lines starting with "## " in "## Offen"-Section
        in_offen = False
        count = 0
        for line in content.splitlines():
            if line.startswith("## Offen"):
                in_offen = True; continue
            if line.startswith("## Resolved"):
                in_offen = False; continue
            if in_offen and line.strip().startswith("##"):
                count += 1
        state["open_blockers"] = count
    else:
        state["open_blockers"] = 0

    return state


def render_markdown(state: dict, app_name: str) -> str:
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    operator = state.get("identity", {}).get("operator", "?")
    branch = state.get("git", {}).get("branch", "?")
    head = state.get("git", {}).get("head", "?")
    uncommitted = state.get("git", {}).get("uncommitted", 0)
    fails = state.get("escalation_count", 0)

    lines = [
        f"<!-- AUTO-GENERATED via posttooluse-status-refresh.sh — DO NOT EDIT -->",
        "",
        f"# {app_name} — Live-Status",
        "",
        f"**Last Update:** {now}",
        f"**Operator:** {operator}",
        f"**Branch:** {branch} ({head})",
        f"**Uncommitted Changes:** {uncommitted}",
        "",
        "## Aktueller Task",
        "",
        f"{state.get('active_ticket') or '(kein aktiver Task)'}",
        "",
        "## Eskalations-Counter",
        "",
        f"{fails} Fails",
    ]
    if state.get("hard_trigger"):
        lines.append("")
        lines.append("🚨 **Hard-Trigger aktiv** — Solver-Subagent erforderlich")
    if state.get("open_blockers", 0) > 0:
        lines.append("")
        lines.append(f"⚠️  **{state['open_blockers']} offene Blocker** in BLOCKERS.md")
    return "\n".join(lines) + "\n"


def render_slack_json(state: dict, app_name: str) -> str:
    operator = state.get("identity", {}).get("operator", "?")
    branch = state.get("git", {}).get("branch", "?")
    fails = state.get("escalation_count", 0)
    blockers = state.get("open_blockers", 0)

    text = f"📊 *{app_name}* — Operator: `{operator}` — Branch: `{branch}` — Fails: {fails} — Open Blockers: {blockers}"
    return json.dumps({"text": text})


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--mode", choices=["markdown", "slack-json"], default="markdown")
    args = p.parse_args()

    project_dir = Path(os.environ.get("CLAUDE_PROJECT_DIR", "."))
    app_name = os.environ.get("APP_NAME", project_dir.name)

    state = get_state(project_dir)

    if args.mode == "markdown":
        print(render_markdown(state, app_name))
    else:
        print(render_slack_json(state, app_name))

    return 0


if __name__ == "__main__":
    sys.exit(main())
