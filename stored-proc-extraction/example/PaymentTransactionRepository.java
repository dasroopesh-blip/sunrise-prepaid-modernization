package com.fis.sunrise.settlement.repo;

import com.fis.sunrise.settlement.domain.PaymentTransaction;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

/**
 * CRUD-only repository. Spring Data JPA generates the SQL — the database does
 * pure Create/Read/Update/Delete, exactly as intended after the migration.
 * There is deliberately NO business logic here.
 */
public interface PaymentTransactionRepository
        extends JpaRepository<PaymentTransaction, UUID> {
    // findById / save / delete are inherited. Add derived queries as needed,
    // e.g. List<PaymentTransaction> findByStatus(String status);
}
