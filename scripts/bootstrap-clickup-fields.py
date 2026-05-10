#!/usr/bin/env python3
"""
bootstrap-clickup-fields.py — Audit-Fix #4
==========================================
Legt Custom-Fields idempotent in der Tasks-Liste an.
Listet bestehende, erstellt nur fehlende.
"""
from __future__ import annotations
import os
import sys
import json
import urllib.request
import urllib.error

CLICKUP_BASE = "https://api.clickup.com/api/v2"

REQUIRED_FIELDS = [
    {
        "name": "Layer",
        "type": "drop_down",
        "type_config": {
            "options": [
                {"name": "1", "color": "#10b981"},
                {"name": "2", "color": "#f59e0b"},
                {"name": "3", "color": "#ef4444"},
            ]
        },
    },
    {
        "name": "Escalation Count",
        "type": "number",
    },
    {
        "name": "GitHub PR",
        "type": "url",
    },
    {
        "name": "Deployment Env",
        "type": "drop_down",
        "type_config": {
            "options": [
                {"name": "stage", "color": "#3b82f6"},
                {"name": "production", "color": "#8b5cf6"},
                {"name": "both", "color": "#10b981"},
                {"name": "none", "color": "#9ca3af"},
            ]
        },
    },
    {
        "name": "Decision Block",
        "type": "text",
    },
]


def die(msg: str) -> None:
    print(f"❌ {msg}", file=sys.stderr)
    sys.exit(1)


def api_request(method: str, path: str, body: dict | None = None):
    token = os.environ.get("CLICKUP_API_TOKEN", "").strip()
    if not token:
        die("CLICKUP_API_TOKEN nicht gesetzt")
    url = f"{CLICKUP_BASE}{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": token, "Content-Type": "application/json"
    })
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        die(f"API {method} {path} → {e.code}: {e.read().decode(errors='ignore')}")


def main() -> int:
    list_id = os.environ.get("CLICKUP_TASKS_LIST_ID", "").strip()
    if not list_id:
        die("CLICKUP_TASKS_LIST_ID nicht gesetzt")

    existing = api_request("GET", f"/list/{list_id}/field").get("fields", [])
    existing_names = {f["name"].lower(): f for f in existing}

    print(f"📋 Custom-Fields in Liste {list_id}:")
    print(f"   Bestehend: {len(existing)}")

    env_lines: list[str] = []

    for fdef in REQUIRED_FIELDS:
        name = fdef["name"]
        if name.lower() in existing_names:
            field = existing_names[name.lower()]
            print(f"  ℹ️  '{name}' existiert ({field['id']})")
        else:
            try:
                result = api_request("POST", f"/list/{list_id}/field", fdef)
                field = result
                print(f"  ✅ '{name}' angelegt ({field['id']})")
            except SystemExit:
                continue

        env_key = f"CLICKUP_FIELD_{name.upper().replace(' ', '_')}_ID"
        env_lines.append(f'{env_key}="{field["id"]}"')

    print()
    print("In .env eintragen:")
    for line in env_lines:
        print(f"  {line}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
