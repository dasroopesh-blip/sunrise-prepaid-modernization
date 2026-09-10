# DMS Data Validation

DMS can validate that the data it migrated matches the source, row by row. This is Layer 1 of
the validation harness. It is enabled in the task settings
(`ValidationSettings.EnableValidation = true`, `ValidationMode = ROW_LEVEL`).

## How it works

- After (and during) migration, DMS re-reads rows from source and target and compares them.
- Results appear per table with a **validation state** and counts of matched/mismatched rows.

## What to check

```bash
# Per-table statistics for a task (look at ValidationState + ValidationFailedRecords).
aws dms describe-table-statistics \
  --replication-task-arn <TASK_ARN> \
  --query "TableStatistics[].{Table:TableName,State:ValidationState,Failed:ValidationFailedRecords,Pending:ValidationPendingRecords}" \
  --output table
```

Target states:

| Field | Pass criteria |
|-------|---------------|
| `ValidationState` | `Validated` for every table |
| `ValidationFailedRecords` | `0` |
| `ValidationPendingRecords` | `0` (all reconciled) |
| `ValidationSuspendedRecords` | `0` |

## When there are failures

1. DMS writes failed keys to the `awsdms_validation_failures_v1` control table on the target.
2. Inspect those keys, compare source vs target rows manually.
3. Common causes: **collation/case differences** (handled via `HandleCollationDiff`), type
   precision (money!), trailing-space/NULL semantics, timezone handling on timestamps.
4. Fix mapping or data, then re-validate.

## Gotchas for this migration

- **Money:** ensure `numeric(19,4)` on the target — float would cause spurious mismatches.
- **Case:** DMS lowercases object names; the validator handles collation diffs, but verify.
- **Timestamps:** `DATETIME2 → timestamptz`; confirm no timezone shift changed values.
- **LOBs:** limited-LOB mode truncates beyond `LobMaxSize` — raise it if any column needs more.
