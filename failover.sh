#!/usr/bin/env bash
# Failover test: delete the pod of the current primary unit and measure how long
# until a different unit is reported as Primary and accepts writes again.
set -euo pipefail

primary_unit() {
  juju status postgresql-k8s --format=json \
    | jq -r '.applications["postgresql-k8s"].units | to_entries[]
             | select(.value["workload-status"].message == "Primary") | .key'
}

old=$(primary_unit)
pod="${old/\//-}"          # postgresql-k8s/0 -> postgresql-k8s-0
echo "Current primary: ${old} (pod ${pod})"
echo "Deleting pod ${pod} at $(date +%T)..."
start=$SECONDS
microk8s kubectl -n pg delete pod "${pod}" --wait=false

# 1) How long until the database accepts writes again (through the primary Service)?
until psql "$(cat ~/.pglab)" -qtAc "INSERT INTO events (label) VALUES ('probe')" >/dev/null 2>&1; do
  sleep 1
done
echo "Writes accepted again after $((SECONDS - start))s"

# 2) Which unit does Juju now report as primary?
new=""
until [[ -n "$new" && "$new" != "$old" ]] || (( SECONDS - start > 600 )); do
  new=$(primary_unit || true); sleep 5
done
echo "New primary reported by the charm: ${new:-unknown} ($((SECONDS - start))s)"
juju status postgresql-k8s
