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
  local quota_reset_epoch="${10:-0}"
  local quota_reset_buffer_seconds="${11:-300}"
  local elapsed

  [[ "$quota_target_reached" == "false" ]] || return 1
  [[ "$eligible_pool_count" =~ ^[0-9]+$ ]] || return 1
  (( eligible_pool_count > 0 )) || return 1
  [[ "$continuation_count" =~ ^[0-9]+$ ]] || return 1
  [[ "$chain_started_at" =~ ^[0-9]+$ ]] || return 1
  [[ "$now" =~ ^[0-9]+$ ]] || return 1
  [[ "$max_continuations" =~ ^[0-9]+$ ]] || return 1
  [[ "$max_chain_seconds" =~ ^[0-9]+$ ]] || return 1
  [[ "$quota_reset_epoch" =~ ^[0-9]+$ ]] || return 1
  [[ "$quota_reset_buffer_seconds" =~ ^[0-9]+$ ]] || return 1

  # Never queue a child run that could cross the earliest known provider reset.
  if (( quota_reset_epoch > 0 && now >= quota_reset_epoch - quota_reset_buffer_seconds )); then
    return 1
  fi

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

next_midnight_epoch() {
  local now="$1"
  local timezone="$2"
  local local_date next_date

  local_date="$(TZ="$timezone" date -d "@$now" +%F)" || return 1
  next_date="$(TZ="$timezone" date -d "$local_date +1 day" +%F)" || return 1
  TZ="$timezone" date -d "$next_date 00:00:00" +%s
}

next_month_start_utc_epoch() {
  local now="$1"
  local year month next_year next_month
  year="$(date -u -d "@$now" +%Y)" || return 1
  month="$(date -u -d "@$now" +%m)" || return 1
  if (( 10#$month == 12 )); then
    next_year=$((year + 1))
    next_month=01
  else
    next_year="$year"
    next_month="$(printf '%02d' "$((10#$month + 1))")"
  fi
  date -u -d "$next_year-$next_month-01 00:00:00" +%s
}

# Determine the earliest published/reset-boundary schedule among configured
# providers. The returned value is a Unix epoch in seconds (0 = unknown).
calculate_earliest_quota_reset_epoch() {
  local now="$1"
  shift
  local model provider candidate earliest=0

  for model in "$@"; do
    provider="${model%%/*}"
    candidate=0
    case "$provider" in
      google)
        # Gemini API requests-per-day quotas reset at midnight Pacific.
        candidate="$(next_midnight_epoch "$now" "America/Los_Angeles")" || return 1
        ;;
      openrouter|cloudflare-workers-ai|groq)
        # OpenRouter free-model daily requests and Cloudflare Workers AI daily
        # allocations publish a 00:00 UTC reset. Groq's UTC RPD boundary is a
        # conservative fallback; its response header can provide a more exact
        # per-request RPD reset and will move this cutoff earlier when observed.
        candidate="$(next_midnight_epoch "$now" "UTC")" || return 1
        ;;
      cohere|github-copilot)
        # These providers publish monthly trial/AI-credit allowances. Cohere
        # does not document an exact reset timezone; use UTC month-start as a
        # conservative calendar-month guard, while Copilot documents 00:00 UTC.
        candidate="$(next_month_start_utc_epoch "$now")" || return 1
        ;;
    esac

    if (( candidate > 0 && (earliest == 0 || candidate < earliest) )); then
      earliest="$candidate"
    fi
  done

  printf '%s\n' "$earliest"
}

# Extract Groq's documented X-RateLimit-Reset-Requests RPD duration when the
# OpenCode log exposes response headers. Do not use Retry-After: it may describe
# a minute-level throttle rather than the daily request quota.
observe_groq_daily_reset_epoch() {
  local log_file="$1"
  local now="$2"
  python3 - "$log_file" "$now" <<'PY'
import math
import re
import sys

path, now_text = sys.argv[1:3]
try:
    now = int(now_text)
    text = open(path, "r", encoding="utf-8", errors="replace").read()
except (OSError, ValueError):
    print(0)
    raise SystemExit(0)

pattern = re.compile(
    r"x-ratelimit-reset-requests\s*[:=]\s*"
    r"((?:\d+(?:\.\d+)?d)?(?:\d+(?:\.\d+)?h)?"
    r"(?:\d+(?:\.\d+)?m)?(?:\d+(?:\.\d+)?s)?)",
    re.I,
)
matches = list(pattern.finditer(text))
if not matches:
    print(0)
    raise SystemExit(0)

raw = matches[-1].group(1).lower()
parts = {
    "d": re.search(r"(\d+(?:\.\d+)?)d", raw),
    "h": re.search(r"(\d+(?:\.\d+)?)h", raw),
    "m": re.search(r"(\d+(?:\.\d+)?)m", raw),
    "s": re.search(r"(\d+(?:\.\d+)?)s", raw),
}
seconds = (
    (float(parts["d"].group(1)) * 86400 if parts["d"] else 0)
    + (float(parts["h"].group(1)) * 3600 if parts["h"] else 0)
    + (float(parts["m"].group(1)) * 60 if parts["m"] else 0)
    + (float(parts["s"].group(1)) if parts["s"] else 0)
)
print(now + math.ceil(seconds) if seconds > 0 else 0)
PY
}

# A provider may explicitly describe a quota's next reset in its error body.
# Only accept reset-specific wording, not generic Retry-After/rate-limit hints.
observe_explicit_quota_reset_epoch() {
  local log_file="$1"
  local now="$2"
  python3 - "$log_file" "$now" <<'PY'
import datetime as dt
import math
import re
import sys

path, now_text = sys.argv[1:3]
try:
    now = int(now_text)
    text = open(path, "r", encoding="utf-8", errors="replace").read()
except (OSError, ValueError):
    print(0)
    raise SystemExit(0)

absolute = re.findall(
    r"(?:quota|daily allocation|daily limit).{0,80}?"
    r"(?:resets?|resetting)\s+(?:at|on)\s+"
    r"(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)",
    text,
    re.I,
)
if absolute:
    raw = absolute[-1].replace("Z", "+00:00").replace(" ", "T")
    try:
        stamp = dt.datetime.fromisoformat(raw)
        if stamp.tzinfo is None:
            stamp = stamp.replace(tzinfo=dt.timezone.utc)
        print(int(stamp.timestamp()))
        raise SystemExit(0)
    except ValueError:
        pass

duration = re.findall(
    r"(?:quota|daily allocation|daily limit).{0,80}?"
    r"(?:resets?|resetting)\s+(?:in|after)\s+"
    r"((?:\d+(?:\.\d+)?[dhms])+)",
    text,
    re.I,
)
if duration:
    raw = duration[-1].lower()
    days = re.search(r"(\d+(?:\.\d+)?)d", raw)
    hours = re.search(r"(\d+(?:\.\d+)?)h", raw)
    minutes = re.search(r"(\d+(?:\.\d+)?)m", raw)
    seconds = re.search(r"(\d+(?:\.\d+)?)s", raw)
    total = (
        (float(days.group(1)) * 86400 if days else 0)
        + (float(hours.group(1)) * 3600 if hours else 0)
        + (float(minutes.group(1)) * 60 if minutes else 0)
        + (float(seconds.group(1)) if seconds else 0)
    )
    print(now + math.ceil(total) if total > 0 else 0)
else:
    print(0)
PY
}

# Load only quota-pool IDs that still exist in the configured model registry.
# The comma-separated state is carried between linked runs to avoid probing
# pools already confirmed exhausted during the same continuation chain.
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
