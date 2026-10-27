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

    long countByStatus(SubscriptionOrder.OrderStatus status);

    /** Doanh thu mỗi ngày của đơn có trạng thái status trong [from, to) — gộp ở DB. */
    @org.springframework.data.jpa.repository.Query("SELECT year(o.createdAt) AS yr, month(o.createdAt) AS mo, " +
            "day(o.createdAt) AS dy, SUM(o.amount) AS total FROM SubscriptionOrder o " +
            "WHERE o.status = :status AND o.createdAt >= :from AND o.createdAt < :to " +
            "GROUP BY year(o.createdAt), month(o.createdAt), day(o.createdAt)")
    java.util.List<com.jlsp.backend.admin.dto.DayTotal> sumRevenueByDay(
            @org.springframework.data.repository.query.Param("status") SubscriptionOrder.OrderStatus status,
            @org.springframework.data.repository.query.Param("from") java.time.LocalDateTime from,
            @org.springframework.data.repository.query.Param("to") java.time.LocalDateTime to);

    /** Số đơn và doanh thu theo mã gói, chỉ tính đơn có trạng thái status. */
    @org.springframework.data.jpa.repository.Query("SELECT o.plan.code AS planCode, COUNT(o) AS salesCount, " +
            "SUM(o.amount) AS revenue FROM SubscriptionOrder o WHERE o.status = :status AND o.plan IS NOT NULL " +
            "GROUP BY o.plan.code")
    java.util.List<PlanSales> summarizeByPlan(
            @org.springframework.data.repository.query.Param("status") SubscriptionOrder.OrderStatus status);

    interface PlanSales {
        String getPlanCode();

        Long getSalesCount();

        java.math.BigDecimal getRevenue();
    }

    @org.springframework.data.jpa.repository.Query("SELECT COALESCE(SUM(o.amount), 0) FROM SubscriptionOrder o WHERE o.status = :status")
    java.math.BigDecimal sumTotalAmountByStatus(@org.springframework.data.repository.query.Param("status") SubscriptionOrder.OrderStatus status);
}
