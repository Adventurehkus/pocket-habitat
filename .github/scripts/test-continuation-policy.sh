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

# Per-run limits may hand off without a fixed cross-run count or age limit.
assert_policy true no_implementation_progress false 6 true
assert_policy true total_model_call_budget false 6 false
assert_policy true autonomous_round_budget false 1 false
assert_policy false no_implementation_progress false 6 false
assert_policy false no_implementation_progress true 6 true
assert_policy false no_implementation_progress false 0 true
assert_policy false recovery_checkpoint_persistence_failed false 6 true
assert_policy false unknown_stop_reason false 6 true
assert_policy false total_model_call_budget true 6 false

# Deterministic provider reset checks (times are UTC epochs).
NOW="$(date -u -d '2026-11-14 16:00:00' +%s)"
GOOGLE_EXPECTED="$(date -u -d '2026-11-15 08:05:00' +%s)"
UTC_DAILY_EXPECTED="$(date -u -d '2026-11-15 00:05:00' +%s)"
MONTHLY_EXPECTED="$(date -u -d '2026-12-01 00:05:00' +%s)"
[[ "$(quota_pool_reset_epoch "model:google/gemini-3.5-flash-lite" "" "$NOW")" == "$GOOGLE_EXPECTED" ]]
[[ "$(quota_pool_reset_epoch "provider:openrouter" "" "$NOW")" == "$UTC_DAILY_EXPECTED" ]]
[[ "$(quota_pool_reset_epoch "provider:cloudflare-workers-ai" "" "$NOW")" == "$UTC_DAILY_EXPECTED" ]]
[[ "$(quota_pool_reset_epoch "provider:github-copilot" "" "$NOW")" == "$MONTHLY_EXPECTED" ]]
[[ "$(quota_pool_reset_epoch "provider:cohere" "" "$NOW")" == "$MONTHLY_EXPECTED" ]]

# Groq's response header is preferred; missing headers get a conservative 24h fallback.
GROQ_LOG="$(mktemp)"
printf '%s\n' 'x-ratelimit-reset-requests: 2m59.56s' > "$GROQ_LOG"
GROQ_HEADER_EXPECTED=$((NOW + 180 + 300))
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

echo "PASS: continuation policy and provider-aware quota-reset tests"
