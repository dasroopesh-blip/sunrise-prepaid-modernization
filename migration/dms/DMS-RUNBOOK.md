# DMS Runbook — Full Load + CDC (SQL Server → Aurora PostgreSQL)

Operational steps to run the data migration. The infrastructure (replication instance,
endpoints, task) is provisioned by Terraform in `../../infra/terraform/modules/dms/`; this
runbook covers **operating** it.

## 0. Prerequisites

- [ ] **Enable MS-CDC on the source** for each table to be replicated:
      ```sql
      EXEC sys.sp_cdc_enable_db;
      EXEC sys.sp_cdc_enable_table
           @source_schema = N'dbo',
           @source_name   = N'payment_transaction',
           @role_name     = NULL;
      ```
- [ ] Source account has transaction-log read access (`db_owner` or equivalent for setup).
- [ ] Target Aurora schema **pre-created** from SCT output (tables/indexes/constraints).
- [ ] Credentials in **Secrets Manager**; injected to Terraform via `TF_VAR_dms_*_password`.
- [ ] Network path open: DMS SG → source 1433, DMS SG → Aurora 5432 (handled by `security` module).

## 1. Validate endpoint connectivity

In the DMS console (or CLI), run **Test connection** on both the source (SQL Server) and
target (Aurora PostgreSQL) endpoints. Both must succeed before starting the task.

```bash
aws dms test-connection \
  --replication-instance-arn <RI_ARN> \
  --endpoint-arn <SOURCE_ENDPOINT_ARN>
```

## 2. Start the full-load + CDC task

```bash
aws dms start-replication-task \
  --replication-task-arn <TASK_ARN> \
  --start-replication-task-type start-replication
```

- **Full load** copies existing rows (parallelized: `MaxFullLoadSubTasks=8`).
- **CDC** then streams ongoing changes, keeping Aurora in sync during the parallel-run window.

## 3. Monitor

| Metric (CloudWatch, `AWS/DMS`) | Watch for |
|--------------------------------|-----------|
| `FullLoadThroughputRowsTarget` | load progress |
| `CDCLatencySource` / `CDCLatencyTarget` | replication lag (alarm if high) |
| `CDCIncomingChanges` | change volume |
| Table statistics (per-table) | rows loaded / validation state |

- Validation is **enabled** (`ValidationSettings.EnableValidation=true`, ROW_LEVEL) — check
  the per-table **validation state** = `Validated`.

## 4. Reconcile

Run the financial reconciliation in `../../validation/` and confirm row + total parity.

## 5. Cutover & stop

Once logic relocation + parity are signed off (see `../../runbooks/`), stop the task:

```bash
aws dms stop-replication-task --replication-task-arn <TASK_ARN>
```

## Task-settings files

- `task-settings.full-load-cdc.json` — initial migration (load then CDC).
- `task-settings.cdc-only.json` — if the full load was done separately and you only need CDC.
- `table-mappings.json` — selection + lowercase transforms (mirrors the Terraform module).
