# Charmed PostgreSQL lab

A hands-on lab for learning how a database **operator** runs PostgreSQL on Kubernetes:
deploying a highly available cluster with Juju, getting credentials through an
integration, and watching the charm handle the failure of the primary.

Everything runs locally in a single Ubuntu VM.

## What's in here

| File | Purpose |
|---|---|
| [`cloud-init.yaml`](cloud-init.yaml) | Provisions the VM declaratively: MicroK8s, Juju, LXD, charmcraft, `psql` |
| [`wait-active.sh`](wait-active.sh) | Waits until every unit of an application is `active`/`idle` |
| [`pg-connect.sh`](pg-connect.sh) | Fetches credentials issued through the `data-integrator` integration and saves a connection string (password never printed) |
| [`pg-write.sh`](pg-write.sh) | Writes 100 labelled rows through the primary and reports which server answered |
| [`failover.sh`](failover.sh) | Deletes the primary's pod and reports which unit becomes the new primary |

## Running it

### 1. Create the VM (Windows/macOS/Linux with Multipass)

```bash
multipass launch 24.04 --name lab --cpus 4 --memory 12G --disk 60G --cloud-init cloud-init.yaml
multipass transfer *.sh lab:/home/ubuntu/
multipass shell lab
```

### 2. Bootstrap Juju and deploy a three-unit cluster

```bash
juju bootstrap microk8s lab-k8s
juju add-model pg
juju deploy postgresql-k8s --channel 16/stable --trust -n 3
./wait-active.sh postgresql-k8s
```

### 3. Get credentials through an integration

```bash
juju deploy data-integrator --config database-name=labdb
juju integrate data-integrator postgresql-k8s
./wait-active.sh data-integrator
./pg-connect.sh
./pg-write.sh before-failover
```

### 4. Kill the primary

```bash
./failover.sh
./pg-write.sh after-failover
```

## What I observed

- **Credentials by integration.** Connecting `data-integrator` to PostgreSQL made the charm
  create a database user and the `labdb` database automatically. No manual SQL or password handling.
- **Automatic failover.** After I deleted the primary's pod (`postgresql-k8s-0`), the charm
  promoted a replica (`postgresql-k8s/2`) to primary. All 100 rows written before the failure
  were still there, and new writes succeeded through the new primary.
- **The old primary came back as a replica, not as primary.** By the time it restarted, the
  cluster had moved on with a new primary. Bringing it back as primary would risk *split-brain*
  (two primaries with diverging data), so it rejoined as a replica and caught up.
- **Stable identity, not stable IP.** The recreated pod kept its name and storage
  (`postgresql-k8s-0`) but got a new IP address, which is why clients connect through a
  Service name rather than pod IPs.

### Caveats about timing

`failover.sh` doesn't yet give an accurate failover time. Its first write probe was answered by
the old primary before the pod finished terminating, and Juju's status display only refreshes
periodically, so the "new primary reported" time reflects the status refresh, not the promotion
itself. Measuring promotion directly, by polling `pg_is_in_recovery()` on each unit, is a next step.

## Next steps

- [ ] Measure failover time precisely
- [ ] Backups to S3-compatible storage and a verified restore
- [ ] Repeat on VMs with the machine charm (`postgresql`) via LXD
- [ ] Write a small charm with the `ops` framework
