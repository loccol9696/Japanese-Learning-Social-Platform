package com.jlsp.backend.subscription.repository;

import com.jlsp.backend.subscription.entity.SubscriptionOrder;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface SubscriptionOrderRepository extends JpaRepository<SubscriptionOrder, Long> {

    Optional<SubscriptionOrder> findByOrderCode(String orderCode);

    Optional<SubscriptionOrder> findByVerificationCode(String verificationCode);

    Optional<SubscriptionOrder> findFirstByStatusOrderByCreatedAtDesc(SubscriptionOrder.OrderStatus status);

    Page<SubscriptionOrder> findByStatus(SubscriptionOrder.OrderStatus status, Pageable pageable);

    java.util.List<SubscriptionOrder> findByStatus(SubscriptionOrder.OrderStatus status);

    @org.springframework.data.jpa.repository.Query("SELECT COALESCE(SUM(o.amount), 0) FROM SubscriptionOrder o WHERE o.status = :status")
    java.math.BigDecimal sumTotalAmountByStatus(@org.springframework.data.repository.query.Param("status") SubscriptionOrder.OrderStatus status);
}
