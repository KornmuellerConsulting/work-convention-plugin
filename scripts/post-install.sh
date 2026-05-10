#!/usr/bin/env bash
# =============================================================================
# post-install.sh
# Wird von Claude Code nach `claude plugin install` automatisch ausgeführt.
# Initialisiert die Plugin-Files in der Ziel-App.
# =============================================================================
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ROOT="${CLAUDE_APP_ROOT:-$(pwd)}"

echo "📦 Installiere work-convention-plugin in: $APP_ROOT"

# 1. .claude/-Struktur kopieren
mkdir -p "$APP_ROOT/.claude/hooks"
mkdir -p "$APP_ROOT/.claude/agents"
mkdir -p "$APP_ROOT/.claude/skills"
mkdir -p "$APP_ROOT/.claude/commands"
mkdir -p "$APP_ROOT/.claude/scripts"
mkdir -p "$APP_ROOT/.claude/state"

# 2. Plugin-Komponenten kopieren
cp -R "$PLUGIN_ROOT/claude/settings.json"  "$APP_ROOT/.claude/settings.json"
cp -R "$PLUGIN_ROOT/claude/hooks/"*        "$APP_ROOT/.claude/hooks/"
cp -R "$PLUGIN_ROOT/claude/agents/"*       "$APP_ROOT/.claude/agents/"
cp -R "$PLUGIN_ROOT/claude/skills/"*       "$APP_ROOT/.claude/skills/"
cp -R "$PLUGIN_ROOT/claude/commands/"*     "$APP_ROOT/.claude/commands/"
cp -R "$PLUGIN_ROOT/scripts/"*             "$APP_ROOT/.claude/scripts/"

# 3. CLAUDE.md ins App-Root (nur wenn nicht existent)
if [ ! -f "$APP_ROOT/CLAUDE.md" ]; then
  cp "$PLUGIN_ROOT/templates/CLAUDE.md" "$APP_ROOT/CLAUDE.md"
  echo "✅ CLAUDE.md ins App-Root kopiert"
else
  echo "ℹ️  CLAUDE.md existiert schon, nicht überschrieben"
fi

# 4. .env.example kopieren falls nicht da
if [ ! -f "$APP_ROOT/.env.example" ]; then
  cp "$PLUGIN_ROOT/.env.example" "$APP_ROOT/.env.example"
fi

# 5. Hook-Files executable machen
chmod +x "$APP_ROOT/.claude/hooks/"*.sh 2>/dev/null || true
chmod +x "$APP_ROOT/.claude/scripts/"*.sh 2>/dev/null || true
chmod +x "$APP_ROOT/.claude/scripts/"*.py 2>/dev/null || true

# 6. Marker setzen
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$APP_ROOT/.plugin-installed-marker"
echo "1.0.0" >> "$APP_ROOT/.plugin-installed-marker"

echo "✅ work-convention-plugin v1.0.0 installiert"
echo ""
echo "Nächste Schritte:"
echo "  1. cp .env.example .env"
echo "  2. .env ausfüllen (siehe docs/SETUP.md)"
echo "  3. bash .claude/scripts/healthcheck.sh"
echo ""
