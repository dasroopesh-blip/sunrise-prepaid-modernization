-- ============================================================================
-- BEFORE: business logic trapped in a SQL Server stored procedure (T-SQL).
-- This is the kind of proc we RELOCATE into a Spring Boot service.
--
-- What it does (Settlement posting):
--   1. Validate the transaction is AUTHORIZED and not already settled.
--   2. Mark the transaction SETTLED.
--   3. Insert a ledger entry (debit the account, credit settlement).
--   4. Everything in one transaction; roll back on any error.
-- ============================================================================
CREATE PROCEDURE dbo.usp_PostSettlement
    @TransactionId UNIQUEIDENTIFIER,
    @SettlementBatchId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Amount DECIMAL(19,4);
        DECLARE @AccountId UNIQUEIDENTIFIER;
        DECLARE @Status VARCHAR(20);

        SELECT @Amount = amount, @AccountId = account_id, @Status = status
        FROM dbo.payment_transaction WITH (UPDLOCK)
        WHERE transaction_id = @TransactionId;

        IF @Status IS NULL
        BEGIN
            RAISERROR('Transaction not found', 16, 1);
        END

        IF @Status <> 'AUTHORIZED'
        BEGIN
            RAISERROR('Transaction is not in AUTHORIZED state', 16, 1);
        END

        -- Mark settled
        UPDATE dbo.payment_transaction
        SET status = 'SETTLED', updated_at = SYSDATETIME()
        WHERE transaction_id = @TransactionId;

        -- Ledger: debit account, credit settlement
        INSERT INTO dbo.settlement_ledger
            (ledger_id, transaction_id, settlement_batch_id, account_id, amount, entry_type, created_at)
        VALUES
            (NEWID(), @TransactionId, @SettlementBatchId, @AccountId, @Amount, 'DEBIT', SYSDATETIME());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW; -- re-raise to caller
    END CATCH
END
GO
