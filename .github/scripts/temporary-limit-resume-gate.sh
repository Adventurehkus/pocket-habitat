#!/usr/bin/env bash
# Decide whether a no-progress circuit-breaker stop may be retried after a
# transient model-rate-limit cooldown. Daily quota resets remain a separate gate.
set -euo pipefail

report_file="${1:?Usage: temporary-limit-resume-gate.sh REPORT_FILE NOW_EPOCH RUN_UPDATED_EPOCH}"
now_epoch="${2:?Usage: temporary-limit-resume-gate.sh REPORT_FILE NOW_EPOCH RUN_UPDATED_EPOCH}"
run_updated_epoch="${3:?Usage: temporary-limit-resume-gate.sh REPORT_FILE NOW_EPOCH RUN_UPDATED_EPOCH}"

if [[ ! -f "$report_file" || ! "$now_epoch" =~ ^[0-9]+$ || ! "$run_updated_epoch" =~ ^[0-9]+$ ]]; then
  echo "ERROR=invalid_input" >&2
  exit 2
fi

development_result="$(sed -n 's/^- \\*\\*Development result: \\(.*\\)\\*\\*$/\\1/p' "$report_file" | tail -n 1)"
quota_target="$(sed -n 's/^- Quota target reached: //p' "$report_file" | tail -n 1)"
eligible_pool_count="$(sed -n 's/^- Eligible quota pools remaining: //p' "$report_file" | tail -n 1)"
deferred_model_count="$(sed -n 's/^- Models deferred after repeated temporary limits: //p' "$report_file" | tail -n 1)"
temporary_wait_seconds="$(sed -n 's/^- Automatic temporary-limit wait: \\([0-9][0-9]*\\)s across .*/\\1/p' "$report_file" | tail -n 1)"

ready=false
reason="not_a_temporary_limit_circuit_breaker_stop"
minimum_age_seconds=300

if [[ "$development_result" != "NO VALIDATED DEVELOPMENT PROGRESS — AUTOMATIC CONTINUATION STOPPED" ]]; then
  :
elif [[ "$quota_target" != "false" ]]; then
  reason="quota_target_reached"
elif [[ ! "$eligible_pool_count" =~ ^[0-9]+$ ]] || (( eligible_pool_count < 1 )); then
  reason="no_eligible_quota_pools"
elif [[ ! "$deferred_model_count" =~ ^[0-9]+$ ]] || (( deferred_model_count < 1 )); then
  reason="no_deferred_temporary_model"
elif [[ ! "$temporary_wait_seconds" =~ ^[0-9]+$ ]] || (( temporary_wait_seconds < 1 )); then
  reason="no_recorded_temporary_wait"
elif (( now_epoch - run_updated_epoch < minimum_age_seconds )); then
  reason="waiting_for_transient_retry_cooldown"
else
  ready=true
  reason="transient_model_retry_cooldown_elapsed"
fi

run_age_seconds=$((now_epoch - run_updated_epoch))
printf 'READY=%s\\n' "$ready"
printf 'REASON=%s\\n' "$reason"
printf 'ELIGIBLE_POOL_COUNT=%s\\n' "${eligible_pool_count:-0}"
printf 'DEFERRED_MODEL_COUNT=%s\\n' "${deferred_model_count:-0}"
printf 'TEMPORARY_WAIT_SECONDS=%s\\n' "${temporary_wait_seconds:-0}"
printf 'RUN_AGE_SECONDS=%s\\n' "$run_age_seconds"
printf 'MINIMUM_AGE_SECONDS=%s\\n' "$minimum_age_seconds"
