#!/usr/bin/env bash
# Shared policy for safe cross-run continuation and provider-aware quota resets.
should_auto_continue_after_run() {
  local stop_reason="${1:-}"
  local quota_target_reached="${2:-}"
  local eligible_pool_count="${3:-}"
  local retryable_implementation_barrier="${4:-}"
  local consecutive_no_progress_runs="${5:-0}"
  local max_no_progress_runs="${6:-2}"

  [[ "$quota_target_reached" == "false" ]] || return 1
  [[ "$eligible_pool_count" =~ ^[0-9]+$ ]] || return 1
  (( eligible_pool_count > 0 )) || return 1
  [[ "$consecutive_no_progress_runs" =~ ^[0-9]+$ ]] || return 1
  [[ "$max_no_progress_runs" =~ ^[1-9][0-9]*$ ]] || return 1
  # Every continuation run must make validated progress within a bounded
  # number of consecutive handoffs. Model cooldowns do not justify an
  # unlimited chain of zero-cycle runs.
  (( consecutive_no_progress_runs < max_no_progress_runs )) || return 1

  case "$stop_reason" in
    no_implementation_progress)
      [[ "$retryable_implementation_barrier" == "true" ]] || return 1
      ;;
    total_model_call_budget|autonomous_round_budget)
      ;;
    *)
      return 1
      ;;
  esac
  return 0
}

# Conservative preflight attachment budgets, expressed in UTF-8 bytes. These
# are intentionally lower than published context windows to leave room for
# tool schemas, system prompts, and provider-side input accounting.
model_input_budget_bytes() {
  local model="${1:-}"
  local provider="${model%%/*}"
  case "$provider" in
    groq) echo 18432 ;;                       # ~4.5K tokens at 4 bytes/token
    cloudflare-workers-ai) echo 49152 ;;     # ~12K tokens
    cohere|openrouter) echo 98304 ;;         # ~24K tokens
    google) echo 196608 ;;                   # ~48K tokens
    github-copilot) echo 98304 ;;
    *) echo 65536 ;;
  esac
}

# Calculate a safe retry time for the quota scope that was exhausted.
# Reset boundaries are based on provider documentation:
# - Google Gemini RPD: midnight America/Los_Angeles (DST-aware).
# - OpenRouter free-tier daily cap and Cloudflare Workers AI: 00:00 UTC.
# - GitHub Copilot monthly allowance: first of month, 00:00 UTC.
# - Cohere documents a monthly trial-call cap but not its precise boundary;
#   use the next UTC calendar-month boundary as an explicit approximation.
# - Groq supplies x-ratelimit-reset-requests for RPD. Use it when the
#   response transcript exposes it; otherwise use a conservative 24h delay.
quota_pool_reset_epoch() {
  local pool_key="$1"
  local log_file="${2:-}"
  local now_epoch="${3:-$(date -u +%s)}"
  local quota_class="${4:-}"
  python3 - "$pool_key" "$log_file" "$now_epoch" "$quota_class" <<'PY'
import datetime
import math
import pathlib
import re
import sys
from zoneinfo import ZoneInfo

pool_key, log_path, now_text, quota_class = (sys.argv[1:5] + [""])[:4]
utc = datetime.timezone.utc
now = datetime.datetime.fromtimestamp(int(now_text), utc)
provider = pool_key.split(":", 1)[1].split("/", 1)[0] if ":" in pool_key else "unknown"
grace = datetime.timedelta(minutes=5)

def next_utc_midnight():
    day = now.date() + datetime.timedelta(days=1)
    return datetime.datetime.combine(day, datetime.time.min, utc) + grace

def next_utc_month():
    if now.month == 12:
        year, month = now.year + 1, 1
    else:
        year, month = now.year, now.month + 1
    return datetime.datetime(year, month, 1, 0, 5, tzinfo=utc)

if "MONTHLY_QUOTA" in quota_class:
    # The provider-specific month boundary is fully documented for Cohere's
    # monthly cap and Copilot's monthly premium allowance. For another provider
    # explicitly reporting a monthly cap, use UTC month-end as a fallback.
    reset = next_utc_month()
elif provider == "google":
    pacific = ZoneInfo("America/Los_Angeles")
    local_now = now.astimezone(pacific)
    next_day = local_now.date() + datetime.timedelta(days=1)
    reset_local = datetime.datetime.combine(next_day, datetime.time.min, pacific) + grace
    reset = reset_local.astimezone(utc)
elif provider in ("openrouter", "cloudflare-workers-ai"):
    reset = next_utc_midnight()
elif provider in ("cohere", "github-copilot"):
    reset = next_utc_month()
elif provider == "groq":
    try:
        log_text = pathlib.Path(log_path).read_text(encoding="utf-8", errors="replace") if log_path else ""
    except OSError:
        log_text = ""
    headers = re.findall(
        r'''(?i)x-ratelimit-reset-requests["']?\s*[:=]\s*["']?([^"'\s,}]+)''',
        log_text,
    )
    delay = None
    if headers:
        raw = headers[-1].strip().strip('"').strip("'")
        if re.fullmatch(r"[0-9]+(?:\.[0-9]+)?", raw):
            delay = float(raw)
        else:
            parts = re.findall(r"([0-9]+(?:\.[0-9]+)?)([hms])", raw, re.I)
            normalized = raw.lower().replace(" ", "")
            if parts and "".join(number + unit for number, unit in parts).lower() == normalized:
                delay = sum(float(number) * {"h": 3600, "m": 60, "s": 1}[unit.lower()] for number, unit in parts)
    if delay is None:
        reset = now + datetime.timedelta(days=1) + grace
    else:
        reset = now + datetime.timedelta(seconds=math.ceil(max(0, delay))) + grace
else:
    # Unknown daily quota scope: avoid an early retry.
    reset = now + datetime.timedelta(days=1) + grace

print(int(reset.timestamp()))
PY
}

refresh_quota_pool_reset_state() {
  local map_name="$1"
  local now_epoch="$2"
  local -n reset_ref="$map_name"
  local pool_key reset_at
  for pool_key in "${!reset_ref[@]}"; do
    reset_at="${reset_ref[$pool_key]:-0}"
    if [[ ! "$reset_at" =~ ^[0-9]+$ ]] || (( reset_at <= now_epoch )); then
      unset 'reset_ref[$pool_key]'
    fi
  done
}

# State format is comma-separated pool-key@Unix-epoch entries. Bare pool keys
# from older workflow versions are migrated using that provider's reset policy.
load_quota_pool_reset_state() {
  local encoded="${1:-}"
  local known_name="$2"
  local reset_name="$3"
  local now_epoch="$4"
  local -n known_ref="$known_name"
  local -n reset_ref="$reset_name"
  local entry pool_key reset_at
  local -a incoming=()

  [[ -n "$encoded" ]] || return 0
  IFS=',' read -r -a incoming <<< "$encoded"
  for entry in "${incoming[@]}"; do
    if [[ "$entry" == *@* ]]; then
      pool_key="${entry%@*}"
      reset_at="${entry##*@}"
    else
      pool_key="$entry"
      reset_at=""
    fi
    [[ -n "${known_ref[$pool_key]:-}" ]] || continue
    if [[ ! "$reset_at" =~ ^[0-9]+$ ]]; then
      reset_at="$(quota_pool_reset_epoch "$pool_key" "" "$now_epoch")"
    fi
    if (( reset_at > now_epoch )); then
      reset_ref["$pool_key"]="$reset_at"
    fi
  done
}

serialize_quota_pool_reset_state() {
  local reset_name="$1"
  local known_name="$2"
  local now_epoch="$3"
  local -n reset_ref="$reset_name"
  local -n known_ref="$known_name"
  local pool_key
  local -a entries=()

  refresh_quota_pool_reset_state "$reset_name" "$now_epoch"
  for pool_key in "${!reset_ref[@]}"; do
    [[ -n "${known_ref[$pool_key]:-}" ]] || continue
    entries+=("$pool_key@${reset_ref[$pool_key]}")
  done

  if (( ${#entries[@]} == 0 )); then
    printf ''
  else
    printf '%s\n' "${entries[@]}" | sort | paste -sd, -
  fi
}
