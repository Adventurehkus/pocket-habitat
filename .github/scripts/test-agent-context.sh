#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="$SCRIPT_DIR/build-agent-context.sh"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$TEMP_DIR/repo/docs"
cat > "$TEMP_DIR/repo/docs/PROJECT_STATE.md" <<'DOC'
# Project State
## Current status
The game has a source-level gathering and planting loop.
DOC
cat >> "$TEMP_DIR/repo/docs/PROJECT_STATE.md" <<'DOC'
## Next task
Implement and verify creature feeding.
DOC
cat > "$TEMP_DIR/repo/docs/ROADMAP.md" <<'DOC'
# Roadmap
## Current priority
1. Finish creature interactions.
2. Add tests to production rules.
DOC
cat > "$TEMP_DIR/repo/docs/AUTONOMOUS_RECOVERY.md" <<'DOC'
RECOVERY_STATUS: OPEN
Fix the creature interaction review blocker.
DOC
cat > "$TEMP_DIR/repo/docs/TESTING.md" <<'DOC'
# Testing
## Last validated gameplay execution
Rojo, StyLua, Selene passed in the latest source validation.
DOC
printf 'ARCHIVE_SENTINEL\n' > "$TEMP_DIR/repo/docs/old-archive.md"

CONTEXT_TASK='Implement creature feeding safely.' \
CONTEXT_RUN_NUMBER='999' \
CONTEXT_CYCLE='2' \
  bash "$BUILDER" "$TEMP_DIR/repo" "$TEMP_DIR/context.md" >/dev/null

grep -Fq 'Implement creature feeding safely.' "$TEMP_DIR/context.md"
grep -Fq 'Implement and verify creature feeding.' "$TEMP_DIR/context.md"
grep -Fq 'Finish creature interactions.' "$TEMP_DIR/context.md"
grep -Fq 'RECOVERY_STATUS: OPEN' "$TEMP_DIR/context.md"
grep -Fq 'Rojo, StyLua, Selene passed' "$TEMP_DIR/context.md"
if grep -Fq 'ARCHIVE_SENTINEL' "$TEMP_DIR/context.md"; then
  echo 'FAIL: compact context unexpectedly included archive content.' >&2
  exit 1
fi

context_bytes="$(wc -c < "$TEMP_DIR/context.md")"
if (( context_bytes > 11500 )); then
  echo "FAIL: compact context exceeded budget ($context_bytes bytes)." >&2
  exit 1
fi

echo "PASS: compact context includes current state, task, roadmap, recovery, and testing without archives ($context_bytes bytes)"

# Large user task text is bounded instead of being replayed as an oversized prompt.
LONG_TASK="$(printf '%12000s' ' ' | tr ' ' 'x')"
CONTEXT_TASK="$LONG_TASK" \
CONTEXT_RUN_NUMBER='999' \
CONTEXT_CYCLE='3' \
  bash "$BUILDER" "$TEMP_DIR/repo" "$TEMP_DIR/long-task-context.md" >/dev/null
long_task_bytes="$(awk '/## Current task/{active=1;next}/## Working tree/{active=0}active{total+=length($0)+1}END{print total+0}' "$TEMP_DIR/long-task-context.md")"
if (( long_task_bytes > 1402 )); then
  echo "FAIL: long task exceeded its 1,400-byte prompt budget ($long_task_bytes bytes)." >&2
  exit 1
fi
echo "PASS: long user task text clipped to $long_task_bytes bytes in compact context"

