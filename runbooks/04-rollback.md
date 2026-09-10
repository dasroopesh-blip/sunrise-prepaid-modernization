# Runbook 04 — Rollback

**Goal:** Safely revert if any cutover fails its post-checks. For a payments system-of-record,
a rehearsed rollback is mandatory before every cutover.

**Owners:** Release manager, DBA lead, SRE.

---

## Decision: when to roll back

Trigger rollback if, within the post-cutover window, ANY of these occur and can't be
mitigated quickly:

- Financial reconciliation shows **settled-amount drift** (any non-zero).
- Sustained elevated error rate / latency beyond the agreed SLO.
- Data corruption or missing rows detected.
- A critical payment flow (authorization / settlement) is broken.

## Rollback — Phase 1 (AG cutover) 

1. **Freeze** writes on the AWS AG primary.
2. **Repoint** the application connection strings back to the **on-prem** SQL Server
   (retained read-only during the window → re-enable writes).
3. **Reconcile** any transactions that occurred on AWS after the flip; re-apply to on-prem if
   needed (from CDC/logs captured during the window).
4. **Smoke test** on-prem; resume traffic.
5. Post-mortem; fix; reschedule.

> This is why we keep on-prem available (read-only) through the post-cutover window.

## Rollback — Phase 2a (Aurora cutover, per slice)

1. **Freeze** writes for the slice on Aurora.
2. **Reverse the flip:** point the slice's Spring Boot services back at **SQL Server** (the
   slice was retained during the window; its replication articles are NOT yet retired if you
   followed Runbook 02→03 ordering).
3. **Re-sync** SQL Server with any changes written to Aurora after the flip:
   - If a reverse DMS task (Aurora → SQL Server) was pre-staged, start it to replay changes.
   - Otherwise replay from the app's event log / SQS to SQL Server.
4. **Reconcile** the slice; smoke test; resume traffic on SQL Server.
5. Do **not** retire that slice's replication articles until the retry succeeds.

## Key safeguards that make rollback possible

- **On-prem / SQL Server retained read-only** through each post-cutover window.
- **Replication articles retired only AFTER** a slice is confirmed stable (Runbook 03 after 02).
- **CDC kept current** to the cutover instant (minimal divergence to reconcile).
- **Optional reverse DMS task** pre-staged for fast re-sync.
- **Versioned publication/subscription scripts** so replication can be re-enabled.

## Success criteria

- Traffic restored to the previous system with reconciled data.
- Root cause captured; corrective actions logged; new cutover date set.
