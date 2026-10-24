package com.jlsp.backend.subscription.repository;

import com.jlsp.backend.subscription.entity.SubscriptionOrder;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface SubscriptionOrderRepository extends JpaRepository<SubscriptionOrder, Long> {

    @EntityGraph(attributePaths = {"user", "plan"})
    Optional<SubscriptionOrder> findByOrderCode(String orderCode);

    @EntityGraph(attributePaths = {"user", "plan"})
    Optional<SubscriptionOrder> findByVerificationCode(String verificationCode);

    @EntityGraph(attributePaths = {"user", "plan"})
    Page<SubscriptionOrder> findByStatus(SubscriptionOrder.OrderStatus status, Pageable pageable);

    @EntityGraph(attributePaths = {"user", "plan"})
    java.util.List<SubscriptionOrder> findByStatus(SubscriptionOrder.OrderStatus status);

    @Override
    @EntityGraph(attributePaths = {"user", "plan"})
    Page<SubscriptionOrder> findAll(Pageable pageable);

    @org.springframework.data.jpa.repository.Query("SELECT COALESCE(SUM(o.amount), 0) FROM SubscriptionOrder o WHERE o.status = :status")
    java.math.BigDecimal sumTotalAmountByStatus(@org.springframework.data.repository.query.Param("status") SubscriptionOrder.OrderStatus status);
}
