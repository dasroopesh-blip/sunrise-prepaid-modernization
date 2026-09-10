# Runbook 01 — Phase 1: SQL Server → EC2 Always On AG Cutover

**Goal:** Move the on-prem SQL Server workload to AWS (EC2 Multi-AZ) with Always On
Availability Groups, achieving the 99.99% availability objective and getting off the
Simple-recovery / no-HA / SQL-2016-EOL situation.

**Owners:** DBA lead, SRE, Release manager.
**Change window:** low-traffic window; expect a short freeze at the flip.

---

## Pre-checks (T-7 days → T-1 day)

- [ ] EC2 AG nodes provisioned (Terraform `sqlserver-ec2-ag`), one per AZ, encrypted EBS.
- [ ] Windows Failover Cluster + Always On AG + **Listener** configured on the nodes.
- [ ] Databases moved off **Simple** recovery → **Full** recovery model.
- [ ] Backups + point-in-time recovery verified (restore test passed).
- [ ] Replication/log-shipping from on-prem → AWS primary caught up (low lag).
- [ ] App connection strings updated to use the **AG Listener** (not a node IP).
- [ ] Monitoring/alarms live (CloudWatch); ops runbook + escalation path confirmed.
- [ ] Rollback plan reviewed (`04-rollback.md`).

## Cutover (T-0)

1. **Announce** freeze; pause batch jobs and non-critical writes.
2. **Drain** in-flight transactions; confirm on-prem and AWS primary are in sync (0 lag).
3. **Stop** writes to the on-prem instance (put app in maintenance/read-only).
4. **Fail forward:** promote the AWS AG primary as the system of record.
5. **Repoint** the application to the **AG Listener** endpoint (DNS/connection string).
6. **Smoke test:** run health checks + a scripted set of read/write payment operations.
7. **Verify HA:** force an AG failover in a test transaction path; confirm 10–30s recovery.
8. **Resume** batch + full traffic.

## Post-cutover (T+0 → T+7)

- [ ] Monitor CloudWatch: CPU, AG health, failover events, error rates.
- [ ] Run reconciliation (`../validation/reconciliation.sql`) vs the last on-prem snapshot.
- [ ] Keep on-prem available (read-only) as rollback target for the agreed window.
- [ ] Sign-off at the Steering Committee once stable.

## Success criteria

- App serving from AWS via the AG Listener; automatic failover verified (10–30s).
- Backups + PITR in place; reconciliation clean.
- On-prem retained as rollback until sign-off.
