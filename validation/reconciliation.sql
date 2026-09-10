-- ============================================================================
-- Financial reconciliation queries — run the SAME logical query on BOTH the
-- source (SQL Server) and the target (Aurora PostgreSQL) and diff the results.
-- For a payments platform, settled-amount totals must match with ZERO drift.
--
-- Dialect notes:
--   * SQL Server: use CONVERT(date, event_time) and SUM(amount).
--   * PostgreSQL: use event_time::date and SUM(amount).
-- The column/table names differ only in case (DMS lowercases them).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. ROW COUNTS per table (fast smoke test)
-- ----------------------------------------------------------------------------
-- SQL Server:
--   SELECT COUNT(*) AS row_count FROM dbo.payment_transaction;
-- PostgreSQL:
--   SELECT COUNT(*) AS row_count FROM payment_transaction;

-- ----------------------------------------------------------------------------
-- 2. SETTLED TOTALS by day + currency (the money check — must match exactly)
-- ----------------------------------------------------------------------------
-- === SQL Server version ===
--   SELECT CONVERT(date, event_time) AS d,
--          currency,
--          COUNT(*)      AS txn_count,
--          SUM(amount)   AS settled_amount
--   FROM dbo.payment_transaction
--   WHERE status = 'SETTLED'
--   GROUP BY CONVERT(date, event_time), currency
--   ORDER BY d, currency;

-- === PostgreSQL version ===
SELECT event_time::date AS d,
       currency,
       COUNT(*)         AS txn_count,
       SUM(amount)      AS settled_amount
FROM payment_transaction
WHERE status = 'SETTLED'
GROUP BY event_time::date, currency
ORDER BY d, currency;

-- ----------------------------------------------------------------------------
-- 3. STATUS DISTRIBUTION (catch skew in state transitions)
-- ----------------------------------------------------------------------------
SELECT status, COUNT(*) AS n, SUM(amount) AS total_amount
FROM payment_transaction
GROUP BY status
ORDER BY status;

-- ----------------------------------------------------------------------------
-- 4. LEDGER BALANCE CHECK (debits vs credits net to expected)
-- ----------------------------------------------------------------------------
SELECT entry_type, COUNT(*) AS n, SUM(amount) AS total
FROM settlement_ledger
GROUP BY entry_type
ORDER BY entry_type;

-- ----------------------------------------------------------------------------
-- 5. HASH-STYLE per-day fingerprint (detect any row-level drift)
--    PostgreSQL: md5 of concatenated ordered rows per day.
-- ----------------------------------------------------------------------------
SELECT event_time::date AS d,
       md5(string_agg(
              transaction_id::text || '|' || amount::text || '|' || status,
              '' ORDER BY transaction_id)) AS day_fingerprint
FROM payment_transaction
GROUP BY event_time::date
ORDER BY d;
