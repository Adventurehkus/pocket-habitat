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

# Per-run limits can hand off while eligible quota pools remain. Continuation
# depends on the explicit stop reason and bounded chain limits, not reset dates.
assert_policy true no_implementation_progress false 6 true 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
assert_policy true total_model_call_budget false 6 false 0 "$START" 3000 "$MAX_RUNS" "$MAX_SECONDS"
assert_policy true autonomous_round_budget false 1 false 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
assert_policy false no_implementation_progress false 6 false 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
assert_policy false no_implementation_progress true 6 true 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
assert_policy false no_implementation_progress false 0 true 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
assert_policy false recovery_checkpoint_persistence_failed false 6 true 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
assert_policy false total_model_call_budget false 6 false 8 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
assert_policy false total_model_call_budget false 6 false 0 "$START" "$((START + MAX_SECONDS))" "$MAX_RUNS" "$MAX_SECONDS"
assert_policy true total_model_call_budget false 2 false 0 "$((NOW + 60))" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"

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

echo "PASS: continuation policy and cross-run quota-state tests"
