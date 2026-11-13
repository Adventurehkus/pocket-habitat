#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=continuation-policy.sh
source "$SCRIPT_DIR/continuation-policy.sh"

NOW=2000
START=1000
MAX_RUNS=8
MAX_SECONDS=86400
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

# Run-local limits may hand off while quota pools remain, but never within the
# five-minute guard before the earliest known quota reset.
assert_policy true no_implementation_progress false 6 true 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS" 3000 300
assert_policy true total_model_call_budget false 6 false 0 "$START" 2699 "$MAX_RUNS" "$MAX_SECONDS" 3000 300
assert_policy false no_implementation_progress false 6 true 0 "$START" 2700 "$MAX_RUNS" "$MAX_SECONDS" 3000 300
assert_policy false no_implementation_progress false 6 true 0 "$START" 3000 "$MAX_RUNS" "$MAX_SECONDS" 3000 300
assert_policy false no_implementation_progress false 6 false 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS" 3000 300
assert_policy true total_model_call_budget false 6 false 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS" 3000 300
assert_policy true autonomous_round_budget false 1 false 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS" 3000 300
assert_policy false no_implementation_progress true 6 true 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS" 3000 300
assert_policy false no_implementation_progress false 0 true 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS" 3000 300
assert_policy false recovery_checkpoint_persistence_failed false 6 true 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS" 3000 300
assert_policy false total_model_call_budget false 6 false 8 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS" 3000 300
assert_policy false total_model_call_budget false 6 false 0 "$START" "$((START + MAX_SECONDS))" "$MAX_RUNS" "$MAX_SECONDS" 0 300
assert_policy true total_model_call_budget false 2 false 0 "$((NOW + 60))" "$NOW" "$MAX_RUNS" "$MAX_SECONDS" 3000 300

# Reset scheduler: UTC-provider schedules precede Pacific midnight when near it.
utc_reset="$(next_midnight_epoch 1700000000 UTC)"
pacific_reset="$(next_midnight_epoch 1700000000 America/Los_Angeles)"
[[ "$utc_reset" -gt 1700000000 ]]
[[ "$pacific_reset" -gt 1700000000 ]]
[[ "$(calculate_earliest_quota_reset_epoch 1700000000 google/gemini-x openrouter/free)" == "$utc_reset" ]]
[[ "$(calculate_earliest_quota_reset_epoch 1700000000 google/gemini-x)" == "$pacific_reset" ]]
[[ "$(calculate_earliest_quota_reset_epoch 1700000000 cohere/command-a)" == "$(next_month_start_utc_epoch 1700000000)" ]]

# Groq's RPD response header carries a duration until its reset.
tmp_log="$(mktemp)"
printf 'x-ratelimit-reset-requests: 2m59.56s\n' > "$tmp_log"
observed="$(observe_groq_daily_reset_epoch "$tmp_log" 1000)"
[[ "$observed" -eq 1180 ]]
rm -f "$tmp_log"

# Explicit daily-quota reset hints are accepted; generic Retry-After is ignored.
tmp_log="$(mktemp)"
printf 'Daily quota resets in 1h30m\nRetry-After: 2\n' > "$tmp_log"
observed="$(observe_explicit_quota_reset_epoch "$tmp_log" 1000)"
[[ "$observed" -eq 6400 ]]
printf 'Please retry in 4s\n' > "$tmp_log"
observed="$(observe_explicit_quota_reset_epoch "$tmp_log" 1000)"
[[ "$observed" -eq 0 ]]
printf 'Daily quota resets in 2d\n' > "$tmp_log"
observed="$(observe_explicit_quota_reset_epoch "$tmp_log" 1000)"
[[ "$observed" -eq 173800 ]]
printf 'Daily quota resets at 2026-11-14T01:00:00+01:00\n' > "$tmp_log"
observed="$(observe_explicit_quota_reset_epoch "$tmp_log" 0)"
expected="$(date -u -d '2026-11-14T00:00:00Z' +%s)"
[[ "$observed" -eq "$expected" ]]
rm -f "$tmp_log"

# Daily quota exhaustion learned in earlier runs is retained only for known pools.
declare -A KNOWN_POOLS=()
declare -A LOADED_POOLS=()
KNOWN_POOLS["model:google/gemini-a"]="1"
KNOWN_POOLS["provider:openrouter"]="1"
load_exhausted_quota_pool_keys "provider:openrouter,model:google/gemini-a,provider:removed" KNOWN_POOLS LOADED_POOLS
[[ "${LOADED_POOLS[provider:openrouter]:-}" == "1" ]]
[[ "${LOADED_POOLS[model:google/gemini-a]:-}" == "1" ]]
[[ -z "${LOADED_POOLS[provider:removed]:-}" ]]
SERIALIZED="$(serialize_exhausted_quota_pool_keys LOADED_POOLS KNOWN_POOLS)"
[[ "$SERIALIZED" == "model:google/gemini-a,provider:openrouter" ]]

echo "PASS: continuation policy, earliest reset scheduling, and cross-run quota-state tests"
