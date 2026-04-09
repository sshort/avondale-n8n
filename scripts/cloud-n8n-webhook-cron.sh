#!/usr/bin/env bash
set -u

webhook_url="https://n8n-150285098361.europe-west2.run.app/webhook/21194392-347b-4983-a67a-cc2ffbc8313b"
log_file="/var/log/cloud-n8n-webhook.log"
max_attempts=12
sleep_seconds=10
request_timeout=15
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
hostname_value="$(hostname)"
pid_value="$$"
expected_pattern='Workflow was started'

log() {
  local message="$1"
  printf "%s [%s pid=%s] %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$hostname_value" "$pid_value" "$message" >> "$log_file"
  logger -t cloud-n8n-webhook "$message"
}

log "start webhook_url=$webhook_url started_at=$started_at max_attempts=$max_attempts sleep_seconds=$sleep_seconds request_timeout=$request_timeout"

attempt=1
while [ "$attempt" -le "$max_attempts" ]; do
  body_file="/tmp/cloud-n8n-webhook.body.$$"
  response="$(curl -sS -L -m "$request_timeout" -o "$body_file" -w "%{http_code}" "$webhook_url" 2>&1 || true)"
  body_preview="$(tr "\n" " " < "$body_file" | cut -c1-240)"

  if [[ "$response" =~ ^2[0-9][0-9]$ ]] && grep -Eq "$expected_pattern" "$body_file"; then
    rm -f "$body_file"
    log "success attempt=$attempt status=$response body_preview=$(printf %q "$body_preview")"
    exit 0
  fi

  rm -f "$body_file"
  log "retry attempt=$attempt status_or_error=$(printf %q "$response") body_preview=$(printf %q "$body_preview")"

  if [ "$attempt" -lt "$max_attempts" ]; then
    sleep "$sleep_seconds"
  fi
  attempt=$((attempt + 1))
done

log "failure attempts=$max_attempts final_status_or_error=$(printf %q "$response")"
exit 1
