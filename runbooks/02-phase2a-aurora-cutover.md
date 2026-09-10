# Runbook 02 — Phase 2a: SQL Server → Aurora PostgreSQL Cutover (per slice)

**Goal:** Cut a business-purpose **slice** over to Aurora PostgreSQL, once its stored-proc
logic has been relocated to the Spring Boot app tier and the database is CRUD-only for that
slice.

**Owners:** App eng lead, DBA lead, SRE, Release manager.
**Approach:** phased / trickle by the **7 business purposes** — never big-bang.

---

## Entry gate (must ALL be true for the slice)

- [ ] Stored-proc logic for this slice relocated to Spring Boot (`../stored-proc-extraction/`).
- [ ] **Parity green** (unit + golden-fixture/shadow) — `../validation/PARITY-HARNESS.md`.
- [ ] Aurora schema for this slice created (SCT-converted DDL applied).
- [ ] **DMS full-load + CDC** running for this slice; `ValidationState = Validated`, 0 failures.
- [ ] **Financial reconciliation** zero-drift — `../validation/reconciliation.sql`.
- [ ] Rollback validated (`04-rollback.md`).

## Cutover (T-0)

1. **Announce** slice freeze; pause writes for the tables in this slice only.
2. **Drain** in-flight work; let DMS CDC apply the final changes (confirm CDC latency ≈ 0).
3. **Stop** the slice's writes on SQL Server (route the slice to maintenance/read-only).
4. **Final reconcile** for the slice (row counts + settled totals to the cent).
5. **Flip** the app: point the slice's Spring Boot services at the **Aurora writer endpoint**.
6. **Smoke test** the slice's payment operations against Aurora (read + write + settle path).
7. **Enable** writes; resume traffic for the slice.
8. **Retire** the slice's replication articles (hand off to `03-replication-decommission.md`).

## Post-cutover (T+0 → T+7)

- [ ] Monitor Aurora (Perf Insights), app error rates, latency.
- [ ] Keep the SQL Server slice available (read-only) for the rollback window.
- [ ] Confirm KMS encryption in place (TDE retired for this data).
- [ ] Steering Committee sign-off; mark the slice complete in the inventory.

## Notes on Phase 2b

If a slice's logic is **not ready** by its target date, do **not** force it. Park it on
**RDS SQL Server** (managed lift) so it still exits on-prem and keeps HA, and schedule the
Aurora conversion later. This keeps the program moving and off the EOL risk.

## Success criteria

- Slice served from Aurora; parity + reconciliation clean; KMS encryption on.
- Replication articles for the slice retired.
- SQL Server slice retained (read-only) until sign-off.
