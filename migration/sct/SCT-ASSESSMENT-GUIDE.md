# AWS SCT Assessment Guide (SQL Server → Aurora PostgreSQL)

AWS Schema Conversion Tool (SCT) is the first step. It assesses how much of the schema and
code converts automatically and produces the **inventory** that drives the whole migration.

> Modern equivalent: **DMS Schema Conversion** (in the DMS console) does the same job
> serverless; this guide applies to both the desktop SCT and DMS Schema Conversion.

## 1. What SCT does

- Connects to the source **SQL Server** and target **Aurora PostgreSQL**.
- Converts **schema objects** (tables, indexes, views) automatically where possible.
- Flags **code objects** (stored procedures, functions, triggers) that need manual work.
- Produces an **Assessment Report** with an effort estimate (simple / medium / complex).

## 2. Steps

1. **Create a project** in SCT: source = SQL Server, target = Aurora PostgreSQL.
2. **Connect** using read-only credentials (least privilege for assessment).
3. **Run "Create Report"** on the source schema(s).
4. **Read the Assessment Report:**
   - Green = auto-converts.
   - Yellow = converts with minor manual edits.
   - Red = manual rewrite required (most **stored procedures** land here).
5. **Export the report** (PDF/CSV) — this feeds the stored-proc inventory
   (`../../stored-proc-extraction/inventory-template.csv`).
6. **Convert schema** (tables/indexes/constraints) and **save as SQL** — apply to Aurora with
   `TargetTablePrepMode = DO_NOTHING` so DMS won't recreate tables.

## 3. What to do with the findings

| SCT verdict | Action | Where |
|-------------|--------|-------|
| Table/index/view auto-converts | Apply converted DDL to Aurora | pre-create before DMS |
| Simple function | Convert to PL/pgSQL (optional) | DB or app |
| **Stored procedure (business logic)** | **Relocate to Spring Boot** (do NOT port to PL/pgSQL) | `../../stored-proc-extraction/` |
| Trigger | Move to app-tier event handling or PL/pgSQL | evaluate per trigger |
| Pure data-movement proc | Drop; DMS + app CRUD replaces it | n/a |

## 4. Key reminders for the Sunrise estate

- **68 databases** → run SCT per database or in batches; consolidate the inventories.
- Map procedures to the **7 business purposes** so extraction can proceed as slices.
- SCT effort estimates are a starting point — validate complex payment logic manually.
- Anything not ready by cutover goes to **RDS SQL Server (Phase 2b)** instead of blocking.

## 5. Output artifacts (commit these, minus any secrets)

- `assessment-report.pdf` / `.csv` (per database)
- `converted-schema.sql` (the DDL to apply to Aurora)
- A populated `inventory-template.csv` for stored procedures
