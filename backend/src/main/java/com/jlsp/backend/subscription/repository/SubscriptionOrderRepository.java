package com.jlsp.backend.subscription.repository;

import com.jlsp.backend.common.projection.DailyTotal;
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

    Page<SubscriptionOrder> findByStatus(SubscriptionOrder.OrderStatus status, Pageable pageable);

    java.util.List<SubscriptionOrder> findByStatus(SubscriptionOrder.OrderStatus status);

    long countByStatus(SubscriptionOrder.OrderStatus status);

    /** Doanh thu theo từng ngày trong [from, to) của các đơn có trạng thái cho trước. */
    @org.springframework.data.jpa.repository.Query("SELECT CAST(o.createdAt AS LocalDate) AS day, COALESCE(SUM(o.amount), 0) AS total " +
            "FROM SubscriptionOrder o WHERE o.status = :status AND o.createdAt >= :from AND o.createdAt < :to " +
            "GROUP BY CAST(o.createdAt AS LocalDate)")
    java.util.List<DailyTotal> sumAmountPerDay(
            @org.springframework.data.repository.query.Param("status") SubscriptionOrder.OrderStatus status,
            @org.springframework.data.repository.query.Param("from") java.time.LocalDateTime from,
            @org.springframework.data.repository.query.Param("to") java.time.LocalDateTime to);

    /** Số đơn và doanh thu theo mã gói. */
    @org.springframework.data.jpa.repository.Query("SELECT o.plan.code AS planCode, COUNT(o) AS salesCount, " +
            "COALESCE(SUM(o.amount), 0) AS revenue FROM SubscriptionOrder o " +
            "WHERE o.status = :status AND o.plan IS NOT NULL GROUP BY o.plan.code")
    java.util.List<PlanSales> summarizeByPlan(
            @org.springframework.data.repository.query.Param("status") SubscriptionOrder.OrderStatus status);

    interface PlanSales {
        String getPlanCode();

        Long getSalesCount();

        Number getRevenue();
    }

    @org.springframework.data.jpa.repository.Query("SELECT COALESCE(SUM(o.amount), 0) FROM SubscriptionOrder o WHERE o.status = :status")
    java.math.BigDecimal sumTotalAmountByStatus(@org.springframework.data.repository.query.Param("status") SubscriptionOrder.OrderStatus status);
}
