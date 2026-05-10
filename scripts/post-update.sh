#!/usr/bin/env bash
# =============================================================================
# post-update.sh
# Wird nach `claude plugin update` ausgeführt. Aktualisiert Plugin-Files
# OHNE App-spezifische Configs zu überschreiben.
# =============================================================================
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ROOT="${CLAUDE_APP_ROOT:-$(pwd)}"

echo "🔄 Update work-convention-plugin in: $APP_ROOT"

# Backup vor Update
BACKUP_DIR="$APP_ROOT/.claude.backup-$(date +%s)"
cp -R "$APP_ROOT/.claude" "$BACKUP_DIR" 2>/dev/null || true
echo "💾 Backup: $BACKUP_DIR"

# Plugin-managed Komponenten aktualisieren
cp -R "$PLUGIN_ROOT/claude/hooks/"*    "$APP_ROOT/.claude/hooks/"    2>/dev/null || true
cp -R "$PLUGIN_ROOT/claude/agents/"*   "$APP_ROOT/.claude/agents/"   2>/dev/null || true
cp -R "$PLUGIN_ROOT/claude/skills/"*   "$APP_ROOT/.claude/skills/"   2>/dev/null || true
cp -R "$PLUGIN_ROOT/claude/commands/"* "$APP_ROOT/.claude/commands/" 2>/dev/null || true
cp -R "$PLUGIN_ROOT/scripts/"*         "$APP_ROOT/.claude/scripts/" 2>/dev/null || true

# settings.json mergen statt überschreiben (App-lokale Overrides bewahren)
if [ -f "$APP_ROOT/.claude/settings.local.json" ]; then
  echo "ℹ️  settings.local.json gefunden — nicht überschrieben"
fi

# Permissions
chmod +x "$APP_ROOT/.claude/hooks/"*.sh 2>/dev/null || true
chmod +x "$APP_ROOT/.claude/scripts/"*.sh 2>/dev/null || true
chmod +x "$APP_ROOT/.claude/scripts/"*.py 2>/dev/null || true

# Marker aktualisieren
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$APP_ROOT/.plugin-installed-marker"
NEW_VERSION=$(python3 -c "import json; print(json.load(open('$PLUGIN_ROOT/.plugin.json'))['version'])")
echo "$NEW_VERSION" >> "$APP_ROOT/.plugin-installed-marker"

echo "✅ Plugin auf v$NEW_VERSION aktualisiert"
echo "ℹ️  Bei Problemen rollback: rm -rf .claude && mv $BACKUP_DIR .claude"
