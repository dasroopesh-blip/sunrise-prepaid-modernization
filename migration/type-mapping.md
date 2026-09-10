# Type Mapping — SQL Server → PostgreSQL

Precise type conversion rules. **Money precision is non-negotiable for payments** — always
map to `numeric(19,4)` (or wider scale if the source uses more), never to `float`/`double`.

## Data types

| SQL Server | PostgreSQL | Notes |
|------------|-----------|-------|
| `BIT` | `boolean` | 0/1 → false/true |
| `TINYINT` | `smallint` | PG has no 1-byte int |
| `SMALLINT` | `smallint` | |
| `INT` | `integer` | |
| `BIGINT` | `bigint` | |
| `DECIMAL(p,s)` / `NUMERIC(p,s)` | `numeric(p,s)` | Exact; keep precision/scale |
| `MONEY` | `numeric(19,4)` | **Never** float — exact money |
| `SMALLMONEY` | `numeric(10,4)` | Exact money |
| `FLOAT` | `double precision` | Only for genuinely approximate values |
| `REAL` | `real` | |
| `CHAR(n)` | `char(n)` | |
| `VARCHAR(n)` | `varchar(n)` | |
| `VARCHAR(MAX)` | `text` | |
| `NCHAR(n)` | `char(n)` | PG is Unicode by default (UTF-8) |
| `NVARCHAR(n)` | `varchar(n)` | |
| `NVARCHAR(MAX)` | `text` | |
| `TEXT` / `NTEXT` | `text` | Deprecated in SQL Server anyway |
| `DATE` | `date` | |
| `DATETIME` | `timestamp(3)` | ~3ms precision |
| `DATETIME2` | `timestamptz` | Prefer timezone-aware for payments |
| `SMALLDATETIME` | `timestamp(0)` | Minute precision |
| `DATETIMEOFFSET` | `timestamptz` | |
| `TIME` | `time` | |
| `UNIQUEIDENTIFIER` | `uuid` | |
| `VARBINARY(n)` / `VARBINARY(MAX)` | `bytea` | |
| `IMAGE` | `bytea` | Deprecated |
| `XML` | `xml` | |
| `ROWVERSION` / `TIMESTAMP` | `bytea` or drop | SQL Server row-version, not a real timestamp |

## Identity & sequences

| SQL Server | PostgreSQL |
|------------|-----------|
| `IDENTITY(1,1)` | `GENERATED ALWAYS AS IDENTITY` or `bigserial` |
| `SEQUENCE` | `CREATE SEQUENCE` (mostly compatible) |
| `NEWID()` default | `gen_random_uuid()` (pgcrypto) |
| `GETDATE()` default | `now()` / `current_timestamp` |
| `SYSDATETIME()` | `clock_timestamp()` |

## Semantics gotchas (validate these!)

1. **Case sensitivity:** SQL Server is often case-insensitive by collation; PostgreSQL is
   case-sensitive. Decide on `citext` or explicit `lower()` where needed.
2. **NULL + concatenation:** `'a' + NULL` → `NULL` in both, but empty-string handling differs
   in ISNULL vs COALESCE — use `COALESCE`.
3. **Implicit conversions:** SQL Server auto-casts more freely; PostgreSQL is stricter — add
   explicit casts.
4. **Rounding:** confirm banker's vs arithmetic rounding for money; standardize in the app tier.
5. **Empty string vs NULL:** SQL Server sometimes treats `''` like a value; verify per column.
6. **Default schema:** `dbo` → `public` (or a named schema). Our DMS mapping lowercases names.

## Where these rules live in code

- DMS applies the structural mapping during migration (see `dms/table-mappings.json`).
- Aurora DDL uses these target types (see `../validation/` reconciliation expects them).
- Any rounding/case semantics that were in stored procs move to the **Spring Boot** layer.
