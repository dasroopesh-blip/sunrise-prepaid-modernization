# Migration Package — SQL Server 2016 → Aurora PostgreSQL (E2E)

Operational assets that turn the strategy in [`../docs/04-migration-strategy.md`](../docs/04-migration-strategy.md)
into runnable steps. Two workstreams run in parallel:

| Workstream | Owner | Assets |
|------------|-------|--------|
| **Data movement** | DBA / migration eng | `sct/`, `dms/`, `type-mapping.md` |
| **Logic relocation** | App eng (Java/Spring Boot) | `../stored-proc-extraction/` |
| **Validation** | QA / data eng | `../validation/` |
| **Cutover** | Release / SRE | `../runbooks/` |

## Contents

```
migration/
├── README.md                <- this file
├── type-mapping.md          <- SQL Server -> PostgreSQL type conversion rules
├── sct/
│   └── SCT-ASSESSMENT-GUIDE.md   <- how to run AWS SCT + read the report
└── dms/
    ├── DMS-RUNBOOK.md            <- step-by-step DMS operation
    ├── table-mappings.json       <- which tables to migrate (+ transforms)
    ├── task-settings.full-load-cdc.json
    └── task-settings.cdc-only.json
```

## The golden rule

**DMS moves DATA. It does NOT move stored procedures, functions, triggers, or T-SQL logic.**
That logic is relocated into the Spring Boot app tier (see `../stored-proc-extraction/`).
Keep the two workstreams distinct but synchronized at the cutover gate.
