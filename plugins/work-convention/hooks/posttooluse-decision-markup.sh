#!/usr/bin/env bash
# =============================================================================
# posttooluse-decision-markup.sh — PostToolUse:Edit/Write
# Parsed Decision-Blocks aus Edits, postet als ClickUp-Comment.
# v1.2: stdin-JSON. Plugin-Cache-Pfad für clickup-spiegel.py.
# =============================================================================
set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE" ] && exit 0
[ ! -f "$FILE" ] && exit 0

# Suche nach Decision-Blocks
if ! grep -q "^DECISION:" "$FILE" 2>/dev/null; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
STATE_DIR="$PROJECT_DIR/.claude/state"
SIG_FILE="$STATE_DIR/decision-signatures.log"
mkdir -p "$STATE_DIR"
touch "$SIG_FILE"

# Load .env for ClickUp tokens
[ -f "$PROJECT_DIR/.env" ] && { set -a; source "$PROJECT_DIR/.env"; set +a; }

python3 - "$FILE" "$SIG_FILE" "$PLUGIN_ROOT" <<'PYEOF'
import sys, re, hashlib, os, subprocess, pathlib

file_path = sys.argv[1]
sig_file = sys.argv[2]
plugin_root = sys.argv[3]

content = pathlib.Path(file_path).read_text(encoding='utf-8', errors='ignore')

pattern = re.compile(r'(DECISION:\s*[^\n]+\n(?:[A-Z_]+:[^\n]*\n){2,}LAYER:\s*\d+)', re.MULTILINE)
blocks = pattern.findall(content)

seen = set(pathlib.Path(sig_file).read_text(errors='ignore').splitlines())
clickup_script = pathlib.Path(plugin_root) / 'scripts' / 'clickup-spiegel.py' if plugin_root else None

new_blocks = []
for block in blocks:
    sig = hashlib.sha256(block.encode()).hexdigest()[:16]
    if sig in seen:
        continue
    new_blocks.append((sig, block))

if not new_blocks:
    sys.exit(0)

if not clickup_script or not clickup_script.exists():
    sys.exit(0)

for sig, block in new_blocks:
    m = re.search(r'TICKET:\s*([A-Z]+-\d+)', block)
    if not m:
        continue
    ticket = m.group(1)
    try:
        subprocess.run(
            ['python3', str(clickup_script), 'comment',
             '--ticket', ticket, '--body', f"```\n{block}\n```"],
            check=False, capture_output=True, timeout=10
        )
        with open(sig_file, 'a') as f:
            f.write(sig + '\n')
    except Exception:
        pass
PYEOF
exit 0
