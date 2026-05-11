#!/usr/bin/env python3
"""
plugin-audit.py — Audit-Fix #7
==============================
Curated-List + GitHub-Search-Vorschläge für Claude-Code-Plugins.
Modes:
  --mode bootstrap        Initial-Audit beim App-Bootstrap
  --mode periodic         Monatliches Audit (alle 30 Tage default)
  --mode targeted <stack> Suche nach Plugins für spezifischen Stack
  --mode update-curated   Selbst-Update der Curated-List
"""
from __future__ import annotations
import os
import sys
import json
import argparse
import urllib.request
import urllib.error
from pathlib import Path
from datetime import datetime, timezone, timedelta


CURATED_PLUGINS = {
    "language": {
        "typescript": [
            {"name": "typescript-language-server", "rationale": "Type-Check via LSP"},
        ],
        "python": [
            {"name": "python", "rationale": "Python LSP"},
        ],
    },
    "framework": {
        "nextjs": [
            {"name": "nextjs-best-practices", "rationale": "Next.js conventions"},
        ],
        "expo": [
            {"name": "expo-tools", "rationale": "Mobile dev"},
        ],
    },
    "database": {
        "postgres": [
            {"name": "supabase-cli", "rationale": "Migrations + RLS"},
        ],
    },
    "infrastructure": {
        "vercel": [
            {"name": "vercel-cli", "rationale": "Deploy-Helper"},
        ],
        "github": [
            {"name": "gh-cli", "rationale": "Repo-Operations"},
        ],
    },
    "testing": {
        "vitest": [
            {"name": "vitest-runner", "rationale": "Test-Runner-Integration"},
        ],
        "playwright": [
            {"name": "playwright-helper", "rationale": "E2E-Tests"},
        ],
    },
    "devops": {
        "git": [
            {"name": "gitleaks", "rationale": "Secret-Scanning Pre-Commit"},
        ],
    },
}


def detect_stack(app_dir: Path) -> dict[str, list[str]]:
    """Erkennt Tech-Stack der App via package.json, files, etc."""
    stack: dict[str, list[str]] = {}

    pkg = app_dir / "package.json"
    if pkg.exists():
        try:
            data = json.loads(pkg.read_text())
            deps = {**data.get("dependencies", {}), **data.get("devDependencies", {})}
            
            stack.setdefault("language", []).append("typescript" if (app_dir / "tsconfig.json").exists() else "javascript")
            
            if "next" in deps:
                stack.setdefault("framework", []).append("nextjs")
            if "expo" in deps:
                stack.setdefault("framework", []).append("expo")
            if any(k.startswith("@supabase") for k in deps):
                stack.setdefault("database", []).append("postgres")
            if "vitest" in deps:
                stack.setdefault("testing", []).append("vitest")
            if "@playwright/test" in deps or "playwright" in deps:
                stack.setdefault("testing", []).append("playwright")
        except json.JSONDecodeError:
            pass

    if (app_dir / ".git").exists() or (app_dir.parent / ".git").exists() or (app_dir.parent.parent / ".git").exists():
        stack.setdefault("devops", []).append("git")
        stack.setdefault("infrastructure", []).append("github")

    if (app_dir / ".vercel").exists():
        stack.setdefault("infrastructure", []).append("vercel")

    return stack


def recommend_plugins(stack: dict[str, list[str]]) -> list[dict]:
    """Empfehlungen aus Curated-List basierend auf detektiertem Stack."""
    recommendations = []
    for category, technologies in stack.items():
        for tech in technologies:
            plugins = CURATED_PLUGINS.get(category, {}).get(tech, [])
            for p in plugins:
                recommendations.append({**p, "category": category, "tech": tech})
    return recommendations


def cmd_bootstrap(args: argparse.Namespace) -> int:
    project_dir = Path(os.environ.get("CLAUDE_PROJECT_DIR", "."))
    stack = detect_stack(project_dir)

    print(f"🔍 Detected stack:")
    for cat, techs in stack.items():
        print(f"  {cat}: {', '.join(techs)}")

    print()
    print("📋 Empfohlene Plugins (Curated):")
    recs = recommend_plugins(stack)
    if not recs:
        print("  (keine Empfehlungen für detektierten Stack)")
    for r in recs:
        print(f"  • {r['name']:<32} ({r['category']}/{r['tech']}) — {r['rationale']}")

    # Marker
    state_dir = project_dir / ".claude" / "state"
    state_dir.mkdir(parents=True, exist_ok=True)
    (state_dir / "last-plugin-audit.timestamp").write_text(
        datetime.now(timezone.utc).isoformat()
    )

    return 0


def cmd_periodic(args: argparse.Namespace) -> int:
    project_dir = Path(os.environ.get("CLAUDE_PROJECT_DIR", "."))
    state_file = project_dir / ".claude" / "state" / "last-plugin-audit.timestamp"

    interval_days = 30
    if state_file.exists():
        try:
            last = datetime.fromisoformat(state_file.read_text().strip())
            age = datetime.now(timezone.utc) - last
            if age < timedelta(days=interval_days):
                days_left = interval_days - age.days
                print(f"ℹ️  Letztes Audit vor {age.days} Tagen — nächstes in {days_left} Tagen")
                return 0
        except (ValueError, OSError):
            pass

    return cmd_bootstrap(args)


def cmd_targeted(args: argparse.Namespace) -> int:
    stack_query = args.stack
    print(f"🔍 Targeted-Audit für: {stack_query}")
    found = False
    for category, techs in CURATED_PLUGINS.items():
        for tech, plugins in techs.items():
            if stack_query.lower() in tech.lower():
                found = True
                print(f"\n  {category}/{tech}:")
                for p in plugins:
                    print(f"    • {p['name']} — {p['rationale']}")
    if not found:
        print(f"  Keine Curated-Empfehlungen — versuche GitHub-Search:")
        print(f"  https://github.com/search?q={urllib.parse.quote(stack_query)}+claude-code-plugin")
    return 0


def cmd_update_curated(args: argparse.Namespace) -> int:
    print("ℹ️  CURATED_PLUGINS wird im Plugin-Repo gepflegt.")
    print("   Editiere scripts/plugin-audit.py und schick Plugin-Update.")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--mode", choices=["bootstrap", "periodic", "targeted", "update-curated"], default="bootstrap")
    p.add_argument("--stack", help="Für --mode targeted")
    args = p.parse_args()

    if args.mode == "targeted" and not args.stack:
        print("❌ --stack required für --mode targeted", file=sys.stderr)
        return 1

    handler = {
        "bootstrap": cmd_bootstrap,
        "periodic": cmd_periodic,
        "targeted": cmd_targeted,
        "update-curated": cmd_update_curated,
    }[args.mode]
    return handler(args)


if __name__ == "__main__":
    import urllib.parse
    sys.exit(main())
