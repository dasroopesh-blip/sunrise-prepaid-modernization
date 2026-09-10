package com.fis.sunrise.settlement.domain;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/** CRUD-only JPA entity for the settlement_ledger table. */
@Entity
@Table(name = "settlement_ledger")
public class SettlementLedgerEntry {

    @Id
    @Column(name = "ledger_id")
    private UUID ledgerId;

    @Column(name = "transaction_id", nullable = false)
    private UUID transactionId;

    @Column(name = "settlement_batch_id")
    private UUID settlementBatchId;

    @Column(name = "account_id", nullable = false)
    private UUID accountId;

    @Column(name = "amount", nullable = false, precision = 19, scale = 4)
    private BigDecimal amount;

    @Column(name = "entry_type", length = 10, nullable = false)
    private String entryType; // DEBIT / CREDIT

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    protected SettlementLedgerEntry() { } // for JPA

    public SettlementLedgerEntry(UUID ledgerId, UUID transactionId, UUID settlementBatchId,
                                 UUID accountId, BigDecimal amount, String entryType,
                                 OffsetDateTime createdAt) {
        this.ledgerId = ledgerId;
        this.transactionId = transactionId;
        this.settlementBatchId = settlementBatchId;
        this.accountId = accountId;
        this.amount = amount;
        this.entryType = entryType;
        this.createdAt = createdAt;
    }

    public UUID getLedgerId() { return ledgerId; }
    public UUID getTransactionId() { return transactionId; }
    public BigDecimal getAmount() { return amount; }
    public String getEntryType() { return entryType; }
}
