#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=continuation-policy.sh
source "$SCRIPT_DIR/continuation-policy.sh"

assert_policy() {
  local expected="$1"
  shift
  local actual=false
  if should_auto_continue_after_run "$@"; then
    actual=true
  fi
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: expected %s, got %s for: %s\n' "$expected" "$actual" "$*" >&2
    exit 1
  fi
}

# Run-local limits can hand off, but consecutive runs without a validated
# development cycle are capped. A validated cycle resets the counter to zero.
assert_policy true no_implementation_progress false 6 true 0 5
assert_policy true no_implementation_progress false 6 true 1 5
assert_policy true no_implementation_progress false 6 true 2 5
assert_policy true no_implementation_progress false 6 true 4 5
assert_policy true no_implementation_progress false 6 true 4
assert_policy false no_implementation_progress false 6 true 5 5
assert_policy true total_model_call_budget false 6 false 0 2
assert_policy true autonomous_round_budget false 1 false 1 2
assert_policy false total_model_call_budget false 6 false 2 2
assert_policy false autonomous_round_budget false 1 false 3 2
assert_policy false no_implementation_progress false 6 false 0 2
assert_policy false no_implementation_progress false 6 true 0 0
assert_policy false no_implementation_progress false 6 true invalid 2
assert_policy false recovery_checkpoint_persistence_failed false 6 true 0 2
assert_policy false unknown_stop_reason false 6 true 0 2
assert_policy false total_model_call_budget true 6 false 0 2

# Model-specific conservative payload budgets keep low-TPM routes from
# receiving oversized recovery notes or complete diffs.
[[ "$(model_input_budget_bytes groq/qwen/qwen3.8-27b)" -eq 18432 ]]
[[ "$(model_input_budget_bytes cloudflare-workers-ai/glm-4.7-flash)" -eq 49152 ]]
[[ "$(model_input_budget_bytes cohere/north-mini-code)" -eq 98304 ]]
[[ "$(model_input_budget_bytes google/gemini-3.5-flash-lite)" -eq 196608 ]]
[[ "$(model_input_budget_bytes unknown/model)" -eq 65536 ]]

# Deterministic provider reset checks (times are UTC epochs).
NOW="$(date -u -d '2026-11-14 16:00:00' +%s)"
GOOGLE_EXPECTED="$(date -u -d '2026-11-15 08:05:00' +%s)"
UTC_DAILY_EXPECTED="$(date -u -d '2026-11-15 00:05:00' +%s)"
MONTHLY_EXPECTED="$(date -u -d '2026-12-01 00:05:00' +%s)"
[[ "$(quota_pool_reset_epoch "model:google/gemini-3.5-flash-lite" "" "$NOW")" == "$GOOGLE_EXPECTED" ]]
# Confirm the Pacific reset follows daylight-saving transitions (UTC offset changes).
SPRING_NOW="$(date -u -d '2026-03-07 16:00:00' +%s)"
SPRING_EXPECTED="$(date -u -d '2026-03-08 08:05:00' +%s)"
SUMMER_NOW="$(date -u -d '2026-07-15 16:00:00' +%s)"
SUMMER_EXPECTED="$(date -u -d '2026-07-16 07:05:00' +%s)"
[[ "$(quota_pool_reset_epoch "model:google/gemini-3.5-flash-lite" "" "$SPRING_NOW")" == "$SPRING_EXPECTED" ]]
[[ "$(quota_pool_reset_epoch "model:google/gemini-3.5-flash-lite" "" "$SUMMER_NOW")" == "$SUMMER_EXPECTED" ]]
[[ "$(quota_pool_reset_epoch "provider:openrouter" "" "$NOW")" == "$UTC_DAILY_EXPECTED" ]]
[[ "$(quota_pool_reset_epoch "provider:cloudflare-workers-ai" "" "$NOW")" == "$UTC_DAILY_EXPECTED" ]]
[[ "$(quota_pool_reset_epoch "provider:github-copilot" "" "$NOW")" == "$MONTHLY_EXPECTED" ]]
[[ "$(quota_pool_reset_epoch "provider:cohere" "" "$NOW")" == "$MONTHLY_EXPECTED" ]]
[[ "$(quota_pool_reset_epoch "model:google/gemini-3.5-flash-lite" "" "$NOW" "MODEL_MONTHLY_QUOTA")" == "$MONTHLY_EXPECTED" ]]
YEAR_END_NOW="$(date -u -d '2026-12-31 22:00:00' +%s)"
JANUARY_EXPECTED="$(date -u -d '2027-01-01 00:05:00' +%s)"
[[ "$(quota_pool_reset_epoch "provider:github-copilot" "" "$YEAR_END_NOW")" == "$JANUARY_EXPECTED" ]]

# Groq's response header is preferred; missing headers get a conservative 24h fallback.
GROQ_LOG="$(mktemp)"
printf '%s\n' 'x-ratelimit-reset-requests: 2m59.56s' > "$GROQ_LOG"
GROQ_HEADER_EXPECTED=$((NOW + 180 + 300))
[[ "$(quota_pool_reset_epoch "model:groq/qwen/qwen3.8-27b" "$GROQ_LOG" "$NOW")" == "$GROQ_HEADER_EXPECTED" ]]
printf '%s\n' '{"headers":{"x-ratelimit-reset-requests":"2m59.56s"}}' > "$GROQ_LOG"
[[ "$(quota_pool_reset_epoch "model:groq/qwen/qwen3.8-27b" "$GROQ_LOG" "$NOW")" == "$GROQ_HEADER_EXPECTED" ]]
GROQ_FALLBACK_EXPECTED=$((NOW + 86400 + 300))
[[ "$(quota_pool_reset_epoch "model:groq/qwen/qwen3.8-27b" "" "$NOW")" == "$GROQ_FALLBACK_EXPECTED" ]]
rm -f "$GROQ_LOG"

# Expiry state carries exact reset epochs, drops expired entries, and migrates legacy bare IDs.
declare -A KNOWN=()
declare -A RESETS=()
KNOWN["model:google/gemini-3.5-flash-lite"]="1"
KNOWN["provider:cohere"]="1"
KNOWN["provider:openrouter"]="1"
load_quota_pool_reset_state "model:google/gemini-3.5-flash-lite@$GOOGLE_EXPECTED,provider:cohere@$MONTHLY_EXPECTED,provider:removed@9999999999" KNOWN RESETS "$NOW"
[[ "${RESETS[model:google/gemini-3.5-flash-lite]:-}" == "$GOOGLE_EXPECTED" ]]
[[ "${RESETS[provider:cohere]:-}" == "$MONTHLY_EXPECTED" ]]
[[ -z "${RESETS[provider:removed]:-}" ]]
SERIALIZED="$(serialize_quota_pool_reset_state RESETS KNOWN "$NOW")"
[[ "$SERIALIZED" == "model:google/gemini-3.5-flash-lite@$GOOGLE_EXPECTED,provider:cohere@$MONTHLY_EXPECTED" ]]
refresh_quota_pool_reset_state RESETS "$GOOGLE_EXPECTED"
[[ -z "${RESETS[model:google/gemini-3.5-flash-lite]:-}" ]]
[[ -n "${RESETS[provider:cohere]:-}" ]]

declare -A LEGACY=()
load_quota_pool_reset_state "provider:openrouter" KNOWN LEGACY "$NOW"
[[ "${LEGACY[provider:openrouter]:-}" == "$UTC_DAILY_EXPECTED" ]]


# Recovery waits select the earliest future pool reset and split long waits into
# chunks shorter than the GitHub Actions job timeout. Expired/invalid entries are ignored.
declare -A RECOVERY_WAITS=()
RECOVERY_WAITS["daily-later"]="1900"
RECOVERY_WAITS["daily-earlier"]="1500"
RECOVERY_WAITS["expired"]="900"
[[ "$(quota_recovery_retry_epoch RECOVERY_WAITS 1000 300)" == "1300" ]]
[[ "$(quota_recovery_retry_epoch RECOVERY_WAITS 1000 1000)" == "1500" ]]
RECOVERY_WAITS=()
RECOVERY_WAITS["bad"]="not-a-timestamp"
[[ "$(quota_recovery_retry_epoch RECOVERY_WAITS 1000 300)" == "0" ]]
if quota_recovery_retry_epoch RECOVERY_WAITS invalid 300 >/dev/null 2>&1; then
  echo "FAIL: invalid recovery wait arguments were accepted" >&2
  exit 1
fi

echo "PASS: continuation policy and provider-aware quota-reset tests"
