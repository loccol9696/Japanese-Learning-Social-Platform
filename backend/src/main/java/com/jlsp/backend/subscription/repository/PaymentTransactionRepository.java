package com.jlsp.backend.subscription.repository;

import com.jlsp.backend.subscription.entity.PaymentTransaction;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PaymentTransactionRepository extends JpaRepository<PaymentTransaction, Long> {

    boolean existsByGatewayAndExternalId(String gateway, String externalId);

    Page<PaymentTransaction> findByStatus(PaymentTransaction.Status status, Pageable pageable);
}
