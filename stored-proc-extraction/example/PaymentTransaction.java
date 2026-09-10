package com.fis.sunrise.settlement.domain;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * JPA entity mapping the CRUD-only `payment_transaction` table in Aurora
 * PostgreSQL. Note: NO business logic here — just state + persistence. All the
 * logic that used to live in the stored procedure now lives in the service.
 *
 * Money is BigDecimal (never double) to preserve exact precision, matching the
 * numeric(19,4) column type (see migration/type-mapping.md).
 */
@Entity
@Table(name = "payment_transaction")
public class PaymentTransaction {

    @Id
    @Column(name = "transaction_id")
    private UUID transactionId;

    @Column(name = "account_id", nullable = false)
    private UUID accountId;

    @Column(name = "amount", nullable = false, precision = 19, scale = 4)
    private BigDecimal amount;

    @Column(name = "currency", length = 3, nullable = false)
    private String currency;

    @Column(name = "status", length = 20, nullable = false)
    private String status; // AUTHORIZED, SETTLED, DECLINED, REFUNDED

    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;

    // Optimistic locking replaces the T-SQL UPDLOCK hint for safe concurrency.
    @Version
    @Column(name = "row_version")
    private Long rowVersion;

    protected PaymentTransaction() { } // for JPA

    // --- getters / setters ---
    public UUID getTransactionId() { return transactionId; }
    public void setTransactionId(UUID id) { this.transactionId = id; }
    public UUID getAccountId() { return accountId; }
    public void setAccountId(UUID accountId) { this.accountId = accountId; }
    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }
    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public OffsetDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(OffsetDateTime t) { this.updatedAt = t; }
}
