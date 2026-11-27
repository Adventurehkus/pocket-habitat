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

cat > "$TEMP_DIR/no-progress-stop.md" <<'REPORT'
- **Development result: NO VALIDATED DEVELOPMENT PROGRESS — AUTOMATIC CONTINUATION STOPPED**
- Quota target reached: false
- Provider-aware quota reset state: model:google/gemini-test@300,model:groq/qwen-test@200,provider:cohere@9999
- Monthly quota pools excluded from reset wait: provider:cohere
REPORT
result="$(assert_result false "$TEMP_DIR/no-progress-stop.md" 299)"
grep -Fxq 'REASON=waiting_for_all_nonmonthly_resets_after_no_progress_stop' <<< "$result"
grep -Fxq 'DAILY_POOL_COUNT=2' <<< "$result"
grep -Fxq 'MONTHLY_POOL_COUNT=1' <<< "$result"
result="$(assert_result true "$TEMP_DIR/no-progress-stop.md" 300)"
grep -Fxq 'REASON=all_nonmonthly_quota_pools_reset_after_no_progress_stop' <<< "$result"

cat > "$TEMP_DIR/no-progress-without-reset.md" <<'REPORT'
- **Development result: NO VALIDATED DEVELOPMENT PROGRESS — AUTOMATIC CONTINUATION STOPPED**
- Quota target reached: false
- Provider-aware quota reset state: none
REPORT
result="$(assert_result false "$TEMP_DIR/no-progress-without-reset.md" 99999)"
grep -Fxq 'REASON=missing_reset_state' <<< "$result"

cat > "$TEMP_DIR/monthly-only.md" <<'REPORT'
- Quota target reached: true
- Provider-aware quota reset state: provider:cohere@9999,provider:github-copilot@9999
- Monthly quota pools excluded from reset wait: provider:cohere,provider:github-copilot
REPORT
result="$(assert_result false "$TEMP_DIR/monthly-only.md" 99999)"
grep -Fxq 'REASON=no_nonmonthly_quota_pools' <<< "$result"

echo "PASS: quota-resume gate waits for every non-monthly pool and ignores monthly pools"

TEMP_GATE="$SCRIPT_DIR/temporary-limit-resume-gate.sh"
cat > "$TEMP_DIR/transient-stop.md" <<'REPORT'
- **Development result: NO VALIDATED DEVELOPMENT PROGRESS — AUTOMATIC CONTINUATION STOPPED**
- Eligible quota pools remaining: 1
- Quota target reached: false
- Models deferred after repeated temporary limits: 1
- Automatic temporary-limit wait: 151s across 4 classified events
REPORT
result="$(bash "$TEMP_GATE" "$TEMP_DIR/transient-stop.md" 2000 1699)"
grep -Fxq 'READY=true' <<< "$result"
grep -Fxq 'REASON=transient_model_retry_cooldown_elapsed' <<< "$result"

result="$(bash "$TEMP_GATE" "$TEMP_DIR/transient-stop.md" 1998 1699)"
grep -Fxq 'READY=false' <<< "$result"
grep -Fxq 'REASON=waiting_for_transient_retry_cooldown' <<< "$result"

sed 's/Eligible quota pools remaining: 1/Eligible quota pools remaining: 0/' "$TEMP_DIR/transient-stop.md" > "$TEMP_DIR/no-eligible-pool.md"
result="$(bash "$TEMP_GATE" "$TEMP_DIR/no-eligible-pool.md" 2000 1699)"
grep -Fxq 'READY=false' <<< "$result"
grep -Fxq 'REASON=no_eligible_quota_pools' <<< "$result"

sed 's/Models deferred after repeated temporary limits: 1/Models deferred after repeated temporary limits: 0/' "$TEMP_DIR/transient-stop.md" > "$TEMP_DIR/no-deferred-model.md"
result="$(bash "$TEMP_GATE" "$TEMP_DIR/no-deferred-model.md" 2000 1699)"
grep -Fxq 'READY=false' <<< "$result"
grep -Fxq 'REASON=no_deferred_temporary_model' <<< "$result"

echo "PASS: transient-limit recovery requires an eligible pool, a deferred model, and an elapsed cooldown"
