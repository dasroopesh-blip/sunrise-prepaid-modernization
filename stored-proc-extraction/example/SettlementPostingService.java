package com.fis.sunrise.settlement.service;

import com.fis.sunrise.settlement.domain.PaymentTransaction;
import com.fis.sunrise.settlement.domain.SettlementLedgerEntry;
import com.fis.sunrise.settlement.repo.PaymentTransactionRepository;
import com.fis.sunrise.settlement.repo.SettlementLedgerRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * AFTER: the business logic from dbo.usp_PostSettlement, relocated into the
 * Spring Boot application. The database is now CRUD-only (via repositories).
 *
 * Mapping from the old T-SQL proc:
 *   - BEGIN TRANSACTION / COMMIT / ROLLBACK  -> @Transactional (Spring manages it)
 *   - WITH (UPDLOCK)                          -> JPA @Version optimistic locking
 *   - RAISERROR                               -> typed Java exceptions
 *   - SYSDATETIME()                           -> OffsetDateTime.now()
 *   - NEWID()                                 -> UUID.randomUUID()
 *
 * Money stays BigDecimal end-to-end to match numeric(19,4) exactly.
 */
@Service
public class SettlementPostingService {

    private final PaymentTransactionRepository txnRepo;
    private final SettlementLedgerRepository ledgerRepo;

    public SettlementPostingService(PaymentTransactionRepository txnRepo,
                                    SettlementLedgerRepository ledgerRepo) {
        this.txnRepo = txnRepo;
        this.ledgerRepo = ledgerRepo;
    }

    /**
     * Post a settlement for one transaction. Whole method is one DB transaction;
     * any exception rolls it back (equivalent to the old TRY/CATCH + ROLLBACK).
     */
    @Transactional
    public void postSettlement(UUID transactionId, UUID settlementBatchId) {
        // 1. Load (repository = CRUD read). Optimistic lock via @Version.
        PaymentTransaction txn = txnRepo.findById(transactionId)
                .orElseThrow(() -> new TransactionNotFoundException(transactionId));

        // 2. Validate state (was: RAISERROR checks).
        if (!"AUTHORIZED".equals(txn.getStatus())) {
            throw new InvalidTransactionStateException(
                    transactionId, txn.getStatus(), "AUTHORIZED");
        }

        // 3. Mark settled (was: UPDATE ... SET status).
        txn.setStatus("SETTLED");
        txn.setUpdatedAt(OffsetDateTime.now());
        txnRepo.save(txn);

        // 4. Ledger debit entry (was: INSERT INTO settlement_ledger).
        SettlementLedgerEntry entry = new SettlementLedgerEntry(
                UUID.randomUUID(),
                transactionId,
                settlementBatchId,
                txn.getAccountId(),
                txn.getAmount(),      // BigDecimal — exact money
                "DEBIT",
                OffsetDateTime.now());
        ledgerRepo.save(entry);
    }

    // --- typed exceptions replace RAISERROR ---
    public static class TransactionNotFoundException extends RuntimeException {
        public TransactionNotFoundException(UUID id) {
            super("Transaction not found: " + id);
        }
    }

    public static class InvalidTransactionStateException extends RuntimeException {
        public InvalidTransactionStateException(UUID id, String actual, String expected) {
            super("Transaction " + id + " is in state " + actual + ", expected " + expected);
        }
    }
}
