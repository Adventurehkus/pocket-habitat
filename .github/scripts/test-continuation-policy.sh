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

# Run #38: run-local caps/cooldowns blocked implementation while six daily pools remained.
assert_policy true no_implementation_progress false 6 true 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
# A successful implementation call that repeatedly made no changes is a real stall.
assert_policy false no_implementation_progress false 6 false 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
# Explicit per-run call/round budgets are safe handoff points.
assert_policy true total_model_call_budget false 6 false 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
assert_policy true autonomous_round_budget false 1 false 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
# Never continue after quota exhaustion or when no eligible pools remain.
assert_policy false no_implementation_progress true 6 true 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
assert_policy false no_implementation_progress false 0 true 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
# Unknown and hard-stop reasons must not create child runs.
assert_policy false recovery_checkpoint_persistence_failed false 6 true 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
# Bound both the number of continuation runs and the chain wall-clock duration.
assert_policy false total_model_call_budget false 6 false 8 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
assert_policy false total_model_call_budget false 6 false 0 "$START" "$((NOW - MAX_SECONDS))" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
# A future start timestamp cannot produce a negative elapsed-time bypass.
assert_policy true total_model_call_budget false 2 false 0 "$((NOW + 60))" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"

# Daily quota exhaustion learned in earlier runs is retained without accepting
# stale IDs that are not part of the current configured model registry.
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

echo "PASS: automatic continuation policy and cross-run quota-state tests"
