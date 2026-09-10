# Validation & Reconciliation Harness

Payments migrations allow **zero financial drift**. This directory holds the three layers of
validation that gate the cutover.

## Three layers

| Layer | Question it answers | Asset |
|-------|---------------------|-------|
| **1. DMS data validation** | Did every row copy correctly? | `DMS-VALIDATION.md` |
| **2. Financial reconciliation** | Do the money totals match exactly? | `reconciliation.sql` |
| **3. Logic parity** | Does new code behave like the old stored proc? | `PARITY-HARNESS.md` |

All three must pass before the cutover gate (see `../runbooks/`).

## Layer 1 — DMS data validation

DMS row-level validation runs continuously (enabled in the task settings). Confirm every
table's validation state is `Validated` and `FailedRecords = 0`. See `DMS-VALIDATION.md`.

## Layer 2 — Financial reconciliation

Run `reconciliation.sql` (the SQL Server and PostgreSQL variants) and diff:
- Row counts per table.
- **Settled totals by day + currency — must match to the cent.**
- Status distribution.
- Ledger debit/credit balances.
- Per-day hash fingerprints to catch row-level drift.

Automate the diff in CI and fail the build on any mismatch in settled amounts.

## Layer 3 — Logic parity

For every relocated stored proc, feed identical inputs to the **old proc** and the **new
Spring Boot service**, then assert identical resulting state. See `PARITY-HARNESS.md` and the
unit example in `../stored-proc-extraction/example/SettlementPostingServiceTest.java`.

## Sign-off

A slice is ready to cut over only when: DMS `Validated`, reconciliation zero-drift, and
parity green — recorded on the cutover checklist in `../runbooks/`.
