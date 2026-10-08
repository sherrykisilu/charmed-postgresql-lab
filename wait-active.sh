#!/usr/bin/env bash
# Wait until every unit of an application reports workload "active" and agent "idle".
# Usage: wait-active.sh <application> [timeout-seconds]
app="${1:-postgresql-k8s}"
timeout="${2:-1500}"
end=$((SECONDS + timeout))
while (( SECONDS < end )); do
  not_ready=$(juju status "$app" --format=json \
    | jq -r --arg a "$app" '.applications[$a].units // {} | to_entries[]
        | select(.value["workload-status"].current != "active" or .value["juju-status"].current != "idle")
        | .key')
  total=$(juju status "$app" --format=json | jq -r --arg a "$app" '.applications[$a].units // {} | length')
  if [[ -z "$not_ready" && "$total" -gt 0 ]]; then
    echo "All $total units of $app are active/idle."
    juju status "$app"
    exit 0
  fi
  echo "$(date +%T) waiting on: $(echo $not_ready | tr '\n' ' ')"
  sleep 20
done
echo "Timed out waiting for $app"
juju status "$app"
exit 1
