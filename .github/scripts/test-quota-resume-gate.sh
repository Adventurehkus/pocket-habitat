#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/quota-resume-gate.sh"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

assert_result() {
  local expected_ready="$1"
  local report="$2"
  local now="$3"
  local output
  output="$(bash "$GATE" "$report" "$now")"
  if ! grep -Fxq "READY=$expected_ready" <<< "$output"; then
    printf 'FAIL: expected READY=%s; output was:\n%s\n' "$expected_ready" "$output" >&2
    exit 1
  fi
  printf '%s\n' "$output"
}

cat > "$TEMP_DIR/mixed.md" <<'REPORT'
- Quota target reached: true
- Provider-aware quota reset state: model:google/gemini-test@300,model:groq/qwen-test@200,provider:cohere@9999,provider:github-copilot@9999
- Monthly quota pools excluded from reset wait: provider:cohere,provider:github-copilot
REPORT

result="$(assert_result false "$TEMP_DIR/mixed.md" 299)"
grep -Fxq 'DAILY_POOL_COUNT=2' <<< "$result"
grep -Fxq 'MONTHLY_POOL_COUNT=2' <<< "$result"
grep -Fxq 'LATEST_DAILY_RESET_EPOCH=300' <<< "$result"

result="$(assert_result true "$TEMP_DIR/mixed.md" 300)"
grep -Fxq 'REASON=all_nonmonthly_quota_pools_reset' <<< "$result"
grep -Fxq 'MONTHLY_QUOTA_POOLS=provider:cohere,provider:github-copilot' <<< "$result"

cat > "$TEMP_DIR/legacy.md" <<'REPORT'
- Quota target reached: true
- Provider-aware quota reset state: provider:openrouter@100,provider:cohere@9999,provider:github-copilot@9999
REPORT
result="$(assert_result true "$TEMP_DIR/legacy.md" 100)"
grep -Fxq 'DAILY_POOL_COUNT=1' <<< "$result"
grep -Fxq 'MONTHLY_POOL_COUNT=2' <<< "$result"

sed 's/Quota target reached: true/Quota target reached: false/' "$TEMP_DIR/mixed.md" > "$TEMP_DIR/not-exhausted.md"
result="$(assert_result false "$TEMP_DIR/not-exhausted.md" 99999)"
grep -Fxq 'REASON=quota_target_not_reached' <<< "$result"

cat > "$TEMP_DIR/monthly-only.md" <<'REPORT'
- Quota target reached: true
- Provider-aware quota reset state: provider:cohere@9999,provider:github-copilot@9999
- Monthly quota pools excluded from reset wait: provider:cohere,provider:github-copilot
REPORT
result="$(assert_result false "$TEMP_DIR/monthly-only.md" 99999)"
grep -Fxq 'REASON=no_nonmonthly_quota_pools' <<< "$result"

echo "PASS: quota-resume gate waits for every non-monthly pool and ignores monthly pools"
