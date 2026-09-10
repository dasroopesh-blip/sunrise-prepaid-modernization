# Stored-Procedure Extraction → Spring Boot (Phase 2)

The core re-architecture: **move business logic OUT of SQL Server stored procedures INTO the
existing Java/Spring Boot application**, leaving the database **CRUD-only**. This is a *logic
relocation* (same language, Java), not a greenfield rewrite.

> Why this matters: it's the key that unlocks the Aurora PostgreSQL cutover (a CRUD-only DB is
> portable), enables horizontal scaling on EKS, and removes SQL Server lock-in.

## Workflow

```
1. INVENTORY   -> list every SP across the 68 DBs        (inventory-template.csv)
2. CLASSIFY    -> tag each by business purpose + strategy (CLASSIFICATION-GUIDE.md)
3. SLICE       -> group by the 7 business purposes
4. EXTRACT     -> reimplement logic in a Spring Boot service (example/)
5. PARITY TEST -> old SP vs new service, identical outputs (../validation/)
6. RETIRE      -> drop the SP + its replication articles
```

## Contents

```
stored-proc-extraction/
├── README.md
├── inventory-template.csv         <- one row per stored procedure
├── CLASSIFICATION-GUIDE.md        <- how to decide each SP's fate
└── example/                       <- a concrete before/after
    ├── before_usp_PostSettlement.sql        (T-SQL stored proc)
    ├── SettlementPostingService.java        (Spring Boot service = the logic)
    ├── PaymentTransactionRepository.java    (CRUD-only repo)
    ├── PaymentTransaction.java              (JPA entity)
    └── SettlementPostingServiceTest.java     (parity/unit test)
```

## The decision, in one line

- **Business logic** → Spring Boot service (Option: relocate).
- **Analytical/settlement batch** → Glue Spark (already built in `infra`).
- **Pure data movement** → drop; DMS + repository CRUD replaces it.
- **Not ready by cutover** → leave on RDS SQL Server (Phase 2b).
