#!/usr/bin/env bash
# Fetch credentials issued to data-integrator by the PostgreSQL charm and save a
# connection string to ~/.pglab (mode 600). The password is never printed.
set -euo pipefail

creds=$(juju run data-integrator/leader get-credentials --format=json)
user=$(jq -r '.[].results.postgresql.username' <<<"$creds")
pass=$(jq -r '.[].results.postgresql.password' <<<"$creds")
db=$(jq -r '.[].results.postgresql.database' <<<"$creds")

# The charm advertises in-cluster DNS names; from the VM we use the primary
# Service's ClusterIP, which always routes to whichever unit is primary.
host=$(microk8s kubectl -n pg get svc postgresql-k8s-primary -o jsonpath='{.spec.clusterIP}')

umask 077
echo "postgresql://${user}:${pass}@${host}:5432/${db}" > ~/.pglab
echo "Issued user: ${user}  database: ${db}  primary service: ${host}:5432"
echo "Connection string saved to ~/.pglab"
