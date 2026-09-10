package com.fis.sunrise.settlement.service;

import com.fis.sunrise.settlement.domain.PaymentTransaction;
import com.fis.sunrise.settlement.domain.SettlementLedgerEntry;
import com.fis.sunrise.settlement.repo.PaymentTransactionRepository;
import com.fis.sunrise.settlement.repo.SettlementLedgerRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Unit + PARITY test for the relocated logic. The parity discipline: for the
 * same inputs, the new Spring Boot service must produce the SAME state changes
 * the old stored procedure did (status -> SETTLED, one DEBIT ledger entry with
 * the exact amount). During migration, run BOTH old proc and new service on the
 * same fixtures and diff results (see ../../validation/).
 */
class SettlementPostingServiceTest {

    private PaymentTransactionRepository txnRepo;
    private SettlementLedgerRepository ledgerRepo;
    private SettlementPostingService service;

    @BeforeEach
    void setUp() {
        txnRepo = mock(PaymentTransactionRepository.class);
        ledgerRepo = mock(SettlementLedgerRepository.class);
        service = new SettlementPostingService(txnRepo, ledgerRepo);
    }

    @Test
    void postsSettlement_marksSettled_andWritesExactDebit() {
        UUID txnId = UUID.randomUUID();
        UUID batchId = UUID.randomUUID();
        UUID acctId = UUID.randomUUID();

        PaymentTransaction txn = new PaymentTransaction();
        txn.setTransactionId(txnId);
        txn.setAccountId(acctId);
        txn.setAmount(new BigDecimal("125.5500")); // exact money
        txn.setCurrency("USD");
        txn.setStatus("AUTHORIZED");

        when(txnRepo.findById(txnId)).thenReturn(Optional.of(txn));

        service.postSettlement(txnId, batchId);

        // status flipped to SETTLED (parity with old UPDATE)
        assertEquals("SETTLED", txn.getStatus());
        verify(txnRepo).save(txn);

        // exactly one DEBIT ledger entry with the exact amount (parity with INSERT)
        ArgumentCaptor<SettlementLedgerEntry> cap = ArgumentCaptor.forClass(SettlementLedgerEntry.class);
        verify(ledgerRepo).save(cap.capture());
        SettlementLedgerEntry entry = cap.getValue();
        assertEquals("DEBIT", entry.getEntryType());
        assertEquals(0, new BigDecimal("125.5500").compareTo(entry.getAmount()));
        assertEquals(txnId, entry.getTransactionId());
    }

    @Test
    void rejects_whenNotAuthorized() {
        UUID txnId = UUID.randomUUID();
        PaymentTransaction txn = new PaymentTransaction();
        txn.setTransactionId(txnId);
        txn.setStatus("SETTLED"); // already settled -> should fail like RAISERROR

        when(txnRepo.findById(txnId)).thenReturn(Optional.of(txn));

        assertThrows(SettlementPostingService.InvalidTransactionStateException.class,
                () -> service.postSettlement(txnId, UUID.randomUUID()));
        verify(ledgerRepo, never()).save(any());
    }

    @Test
    void rejects_whenTransactionMissing() {
        UUID txnId = UUID.randomUUID();
        when(txnRepo.findById(txnId)).thenReturn(Optional.empty());

        assertThrows(SettlementPostingService.TransactionNotFoundException.class,
                () -> service.postSettlement(txnId, UUID.randomUUID()));
    }
}
