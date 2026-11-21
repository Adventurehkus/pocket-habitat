#!/usr/bin/env bash
# Decide whether every exhausted non-monthly quota pool has reached its reset.
# Input: the Markdown pipeline report and, optionally, the current Unix epoch.
set -euo pipefail

report_file="${1:?Usage: quota-resume-gate.sh REPORT_FILE [NOW_EPOCH]}"
now_epoch="${2:-$(date -u +%s)}"

if [[ ! -f "$report_file" || ! "$now_epoch" =~ ^[0-9]+$ ]]; then
  echo "ERROR=invalid_input" >&2
  exit 2
fi

quota_target="$(sed -n 's/^- Quota target reached: //p' "$report_file" | tail -n 1)"
reset_state="$(sed -n 's/^- Provider-aware quota reset state: //p' "$report_file" | tail -n 1)"
monthly_state="$(sed -n 's/^- Monthly quota pools excluded from reset wait: //p' "$report_file" | tail -n 1)"

ready=false
reason="quota_target_not_reached"
daily_pool_count=0
monthly_pool_count=0
latest_daily_reset=0
monthly_pools=()

if [[ "$quota_target" != "true" ]]; then
  :
elif [[ -z "$reset_state" || "$reset_state" == "none" ]]; then
  reason="missing_reset_state"
else
  declare -A monthly_pool_keys=()
  if [[ -n "$monthly_state" ]]; then
    if [[ "$monthly_state" != "none" ]]; then
      IFS=',' read -r -a supplied_monthly_pools <<< "$monthly_state"
      for pool_key in "${supplied_monthly_pools[@]}"; do
        [[ -n "$pool_key" ]] && monthly_pool_keys["$pool_key"]="1"
      done
    fi
  else
    # Backward-compatible interpretation for reports created before this
    # workflow carried explicit quota-class metadata. These are the monthly
    # account scopes in the existing provider reset policy.
    monthly_pool_keys["provider:cohere"]="1"
    monthly_pool_keys["provider:github-copilot"]="1"
  fi

  IFS=',' read -r -a reset_entries <<< "$reset_state"
  for entry in "${reset_entries[@]}"; do
    [[ -n "$entry" && "$entry" != "none" ]] || continue
    if [[ "$entry" != *@* ]]; then
      echo "ERROR=malformed_reset_entry:$entry" >&2
      exit 2
    fi

    pool_key="${entry%@*}"
    reset_at="${entry##*@}"
    if [[ ! "$reset_at" =~ ^[0-9]+$ ]]; then
      echo "ERROR=malformed_reset_epoch:$entry" >&2
      exit 2
    fi

    if [[ -n "${monthly_pool_keys[$pool_key]:-}" ]]; then
      monthly_pool_count=$((monthly_pool_count + 1))
      monthly_pools+=("$pool_key")
      continue
    fi

    daily_pool_count=$((daily_pool_count + 1))
    if (( reset_at > latest_daily_reset )); then
      latest_daily_reset="$reset_at"
    fi
  done

  if (( daily_pool_count == 0 )); then
    reason="no_nonmonthly_quota_pools"
  elif (( now_epoch < latest_daily_reset )); then
    reason="waiting_for_all_nonmonthly_resets"
  else
    ready=true
    reason="all_nonmonthly_quota_pools_reset"
  fi
fi

if (( ${#monthly_pools[@]} > 0 )); then
  monthly_quota_pools="$(printf '%s\n' "${monthly_pools[@]}" | sort -u | paste -sd, -)"
else
  monthly_quota_pools=""
fi

if (( latest_daily_reset > 0 )); then
  latest_daily_reset_utc="$(date -u -d "@$latest_daily_reset" +%Y-%m-%dT%H:%M:%SZ)"
else
  latest_daily_reset_utc=""
fi

printf 'READY=%s\n' "$ready"
printf 'REASON=%s\n' "$reason"
printf 'DAILY_POOL_COUNT=%s\n' "$daily_pool_count"
printf 'MONTHLY_POOL_COUNT=%s\n' "$monthly_pool_count"
printf 'LATEST_DAILY_RESET_EPOCH=%s\n' "$latest_daily_reset"
printf 'LATEST_DAILY_RESET_UTC=%s\n' "$latest_daily_reset_utc"
printf 'MONTHLY_QUOTA_POOLS=%s\n' "$monthly_quota_pools"
