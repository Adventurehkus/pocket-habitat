#!/usr/bin/env bash
# Shared policy for safe cross-run continuation of the autonomous pipeline.
# Each workflow execution has bounded local budgets; a fresh run may resume
# eligible work without a fixed continuation count or chain-age cutoff.
should_auto_continue_after_run() {
  local stop_reason="${1:-}"
  local quota_target_reached="${2:-}"
  local eligible_pool_count="${3:-}"
  local retryable_implementation_barrier="${4:-}"

  [[ "$quota_target_reached" == "false" ]] || return 1
  [[ "$eligible_pool_count" =~ ^[0-9]+$ ]] || return 1
  (( eligible_pool_count > 0 )) || return 1
  case "$stop_reason" in
    no_implementation_progress)
      # A successful implementation call that repeatedly made no changes is
      # not a reason to spin up another run. Only retryable route barriers qualify.
      [[ "$retryable_implementation_barrier" == "true" ]] || return 1
      ;;
    total_model_call_budget|autonomous_round_budget)
      # These are explicit per-run budgets; the next run gets a fresh budget.
      ;;
    *)
      return 1
      ;;
  esac

  return 0
}

# Daily quota exhaustion is carried between runs only while the UTC date is
# unchanged. An empty prior date is treated as legacy state and preserved for
# the current day, avoiding immediate re-probes from an older in-flight run.
reset_exhausted_quota_pool_keys_for_utc_day() {
  local encoded="${1:-}"
  local previous_day="${2:-}"
  local current_day="${3:-}"

  if [[ -n "$previous_day" && "$previous_day" != "$current_day" ]]; then
    printf ''
  else
    printf '%s' "$encoded"
  fi
}

# Load only quota-pool IDs that still exist in the configured model registry.
# The comma-separated state is carried between child runs to avoid probing
# pools already confirmed exhausted during the same UTC quota day.
load_exhausted_quota_pool_keys() {
  local encoded="${1:-}"
  local known_name="$2"
  local exhausted_name="$3"
  local -n known_ref="$known_name"
  local -n exhausted_ref="$exhausted_name"
  local pool_key
  local -a incoming=()

  [[ -n "$encoded" ]] || return 0
  IFS=',' read -r -a incoming <<< "$encoded"
  for pool_key in "${incoming[@]}"; do
    [[ -n "${known_ref[$pool_key]:-}" ]] || continue
    exhausted_ref["$pool_key"]="1"
  done
}

serialize_exhausted_quota_pool_keys() {
  local exhausted_name="$1"
  local known_name="$2"
  local -n exhausted_ref="$exhausted_name"
  local -n known_ref="$known_name"
  local pool_key
  local -a keys=()

  for pool_key in "${!exhausted_ref[@]}"; do
    [[ -n "${known_ref[$pool_key]:-}" ]] || continue
    keys+=("$pool_key")
  done

  if (( ${#keys[@]} == 0 )); then
    printf ''
  else
    printf '%s\\n' "${keys[@]}" | sort | paste -sd, -
  fi
}
