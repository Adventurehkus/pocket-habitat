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

# The Run #38 case: no route completed because run-local caps/cooldowns blocked
# implementation, while six daily quota pools were still eligible.
assert_policy true no_implementation_progress false 6 true 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"

# Do not retry a genuine no-diff implementation result in an endless run chain.
assert_policy false no_implementation_progress false 6 false 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"

# Fresh runs are also valid after explicit per-run call/round budgets.
assert_policy true total_model_call_budget false 6 false 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
assert_policy true autonomous_round_budget false 1 false 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"

# Never continue after the quota target or when there are no eligible pools.
assert_policy false no_implementation_progress true 6 true 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
assert_policy false no_implementation_progress false 0 true 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"

# Unknown and hard-stop reasons must not create child runs.
assert_policy false recovery_checkpoint_persistence_failed false 6 true 0 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"

# Both chain-count and wall-clock safety limits are enforced.
assert_policy false total_model_call_budget false 6 false 8 "$START" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"
assert_policy false total_model_call_budget false 6 false 0 "$START" "$((NOW - MAX_SECONDS))" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"

# Future timestamps are treated as zero elapsed time, not as a negative timeout.
assert_policy true total_model_call_budget false 2 false 0 "$((NOW + 60))" "$NOW" "$MAX_RUNS" "$MAX_SECONDS"

echo "PASS: automatic continuation policy tests"
