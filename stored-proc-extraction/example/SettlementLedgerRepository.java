package com.fis.sunrise.settlement.repo;

import com.fis.sunrise.settlement.domain.SettlementLedgerEntry;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

/** CRUD-only repository for settlement ledger entries. */
public interface SettlementLedgerRepository
        extends JpaRepository<SettlementLedgerEntry, UUID> {
}
