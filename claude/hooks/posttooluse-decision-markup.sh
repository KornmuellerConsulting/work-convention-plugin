#!/usr/bin/env bash
# =============================================================================
# posttooluse-decision-markup.sh — PostToolUse:Edit/Write
# Audit-Fix #10: Parsed Decision-Blocks aus Edits, postet als ClickUp-Comment.
# =============================================================================
set -euo pipefail

FILE="${CLAUDE_TOOL_INPUT_file_path:-}"
[ -z "$FILE" ] && exit 0
[ ! -f "$FILE" ] && exit 0

# Suche nach Decision-Blocks (DECISION:...DATE:...LAYER:)
if ! grep -q "^DECISION:" "$FILE" 2>/dev/null; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATE_DIR="$PROJECT_DIR/.claude/state"
SIG_FILE="$STATE_DIR/decision-signatures.log"
mkdir -p "$STATE_DIR"
touch "$SIG_FILE"

# Extrahiere alle Decision-Blocks aus File, sende neue an ClickUp
python3 - "$FILE" "$SIG_FILE" "$PROJECT_DIR" <<'PYEOF'
import sys, re, hashlib, os, subprocess, pathlib

file_path = sys.argv[1]
sig_file = sys.argv[2]
project_dir = sys.argv[3]

content = pathlib.Path(file_path).read_text(encoding='utf-8', errors='ignore')

# Match Decision-Block: DECISION: ... LAYER: <n>
pattern = re.compile(r'(DECISION:\s*[^\n]+\n(?:[A-Z_]+:[^\n]*\n){2,}LAYER:\s*\d+)', re.MULTILINE)
blocks = pattern.findall(content)

seen = set(pathlib.Path(sig_file).read_text(errors='ignore').splitlines())
clickup_script = pathlib.Path(project_dir) / '.claude' / 'scripts' / 'clickup-spiegel.py'

new_blocks = []
for block in blocks:
    sig = hashlib.sha256(block.encode()).hexdigest()[:16]
    if sig in seen:
        continue
    new_blocks.append((sig, block))

if not new_blocks:
    sys.exit(0)

if not clickup_script.exists():
    sys.exit(0)

for sig, block in new_blocks:
    # Ticket aus Block extrahieren
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
