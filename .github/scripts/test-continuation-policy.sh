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

# Per-run limits may hand off indefinitely while eligible quota pools remain.
# There is intentionally no cross-run count or elapsed-time argument.
assert_policy true no_implementation_progress false 6 true
assert_policy true total_model_call_budget false 6 false
assert_policy true autonomous_round_budget false 1 false
assert_policy false no_implementation_progress false 6 false
assert_policy false no_implementation_progress true 6 true
assert_policy false no_implementation_progress false 0 true
assert_policy false recovery_checkpoint_persistence_failed false 6 true
assert_policy false unknown_stop_reason false 6 true
assert_policy false total_model_call_budget true 6 false

# Exhausted daily quota state is retained on the same UTC day, cleared when
# a child starts on a later UTC day, and preserved for legacy runs with no date.
SAME_DAY="$(reset_exhausted_quota_pool_keys_for_utc_day "provider:openrouter,model:google/gemini-a" "2026-11-14" "2026-11-14")"
[[ "$SAME_DAY" == "provider:openrouter,model:google/gemini-a" ]]
NEXT_DAY="$(reset_exhausted_quota_pool_keys_for_utc_day "provider:openrouter,model:google/gemini-a" "2026-11-14" "2026-11-15")"
[[ -z "$NEXT_DAY" ]]
LEGACY_DAY="$(reset_exhausted_quota_pool_keys_for_utc_day "provider:openrouter" "" "2026-11-15")"
[[ "$LEGACY_DAY" == "provider:openrouter" ]]

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

echo "PASS: unlimited cross-run continuation and UTC quota rollover policy tests"
