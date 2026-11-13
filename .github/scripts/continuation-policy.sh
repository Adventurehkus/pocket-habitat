#!/usr/bin/env bash
# Shared policy for bounded cross-run continuation of the autonomous pipeline.
# Return success only when a fresh run can safely reset run-local limits while
# there are still eligible daily quota pools to try.
should_auto_continue_after_run() {
  local stop_reason="${1:-}"
  local quota_target_reached="${2:-}"
  local eligible_pool_count="${3:-}"
  local retryable_implementation_barrier="${4:-}"
  local continuation_count="${5:-}"
  local chain_started_at="${6:-}"
  local now="${7:-}"
  local max_continuations="${8:-8}"
  local max_chain_seconds="${9:-86400}"
  local elapsed

  [[ "$quota_target_reached" == "false" ]] || return 1
  [[ "$eligible_pool_count" =~ ^[0-9]+$ ]] || return 1
  (( eligible_pool_count > 0 )) || return 1
  [[ "$continuation_count" =~ ^[0-9]+$ ]] || return 1
  [[ "$chain_started_at" =~ ^[0-9]+$ ]] || return 1
  [[ "$now" =~ ^[0-9]+$ ]] || return 1
  [[ "$max_continuations" =~ ^[0-9]+$ ]] || return 1
  [[ "$max_chain_seconds" =~ ^[0-9]+$ ]] || return 1

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

  (( continuation_count < max_continuations )) || return 1
  (( max_chain_seconds > 0 )) || return 1

  if (( now < chain_started_at )); then
    elapsed=0
  else
    elapsed=$((now - chain_started_at))
  fi
  (( elapsed < max_chain_seconds )) || return 1

  return 0
}

# Load only quota-pool IDs that still exist in the configured model registry.
# The comma-separated state is carried as a workflow_dispatch input between
# linked runs, avoiding repeated probes of pools already exhausted in this chain.
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
    printf '%s\n' "${keys[@]}" | sort | paste -sd, -
  fi
}
