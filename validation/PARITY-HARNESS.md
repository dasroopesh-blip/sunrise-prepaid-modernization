# Logic Parity Harness

Layer 3: prove the **relocated Spring Boot logic behaves identically to the old stored
procedure** for the same inputs. This is what makes it safe to retire a stored proc.

## The principle

```
Same input fixtures
     │
     ├── OLD path: execute dbo.usp_XXX on a SQL Server fixture DB
     │
     └── NEW path: call the Spring Boot service on an equivalent fixture DB
                         │
                         ▼
             Diff the resulting state (rows changed, values, errors)
             PASS only if identical.
```

## What to compare

For each procedure, capture and diff the **post-execution state**, not just return values:

1. **Rows changed** — which tables/rows were inserted/updated/deleted.
2. **Exact values** — especially money (`numeric(19,4)`) to the cent.
3. **Error behavior** — same inputs that made the proc `RAISERROR` must make the service throw.
4. **Idempotency / re-run** — running twice yields the same end state where expected.

## Approaches

### A. Unit-level (fast, per service)
Mock the repositories and assert the service produces the same state transitions the proc did.
See the worked example:
`../stored-proc-extraction/example/SettlementPostingServiceTest.java`
(asserts status → SETTLED, exactly one DEBIT ledger row, exact amount, and the same rejection
cases the T-SQL `RAISERROR` produced).

### B. Golden-fixture (integration)
1. Load a curated fixture dataset into a SQL Server test DB and an Aurora test DB.
2. Run the old proc on SQL Server; snapshot affected tables.
3. Run the new service against Aurora; snapshot affected tables.
4. Normalize (case, ordering, timestamps) and **diff**. Any delta fails the slice.

### C. Shadow / dual-run (pre-cutover, production-like)
During the parallel-run window, route a copy of real requests to BOTH the legacy proc and the
new service (new service in read/compare-only mode), and log mismatches. Zero mismatches over
the window is the strongest evidence for cutover.

## Money & determinism rules

- All money is `BigDecimal` / `numeric(19,4)` end-to-end — compare with `compareTo == 0`,
  never `equals` (scale differences) and never float.
- Standardize rounding mode in the app tier and assert it matches the proc's behavior.
- Freeze clock/UUID sources in tests so runs are deterministic.

## Exit criteria

A procedure is cleared for retirement when unit parity is green AND golden-fixture (or shadow)
diff is zero over the agreed window. Record it on the cutover checklist in `../runbooks/`.
