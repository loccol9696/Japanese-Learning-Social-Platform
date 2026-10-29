package com.jlsp.backend.subscription.repository;

import com.jlsp.backend.subscription.entity.SubscriptionOrder;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Optional;

@Repository
public interface SubscriptionOrderRepository extends JpaRepository<SubscriptionOrder, Long> {

    @EntityGraph(attributePaths = {"user", "plan"})
    Optional<SubscriptionOrder> findByOrderCode(String orderCode);

    boolean existsByOrderCode(String orderCode);

    /**
     * Khoá dòng đơn để xử lý tiền về: hai webhook (hoặc webhook và admin duyệt tay) cho cùng một đơn chạy lần lượt.
     * Không dùng fetch join để chỉ khoá đúng dòng đơn.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT o FROM SubscriptionOrder o WHERE o.orderCode = :orderCode")
    Optional<SubscriptionOrder> findByOrderCodeForUpdate(@Param("orderCode") String orderCode);

    /** Đơn đang chờ còn hạn của người dùng cho một gói, để mở lại thay vì tạo đơn mới. */
    @EntityGraph(attributePaths = {"user", "plan"})
    Optional<SubscriptionOrder> findFirstByUserIdAndPlanIdAndStatusAndExpiresAtAfterOrderByCreatedAtDesc(
            Long userId, Long planId, SubscriptionOrder.OrderStatus status, LocalDateTime now);

    /** Số đơn người dùng đã tạo từ mốc [since]: giới hạn tạo đơn để không bị spam. */
    long countByUserIdAndCreatedAtAfter(Long userId, LocalDateTime since);

    @EntityGraph(attributePaths = {"user", "plan"})
    Page<SubscriptionOrder> findByUserId(Long userId, Pageable pageable);

    /** Chuyển các đơn chờ đã quá hạn sang EXPIRED (một câu lệnh, không tải từng đơn). */
    @Modifying
    @Query("UPDATE SubscriptionOrder o SET o.status = com.jlsp.backend.subscription.entity.SubscriptionOrder.OrderStatus.EXPIRED "
            + "WHERE o.status = com.jlsp.backend.subscription.entity.SubscriptionOrder.OrderStatus.PENDING "
            + "AND o.expiresAt IS NOT NULL AND o.expiresAt < :now")
    int expirePendingBefore(@Param("now") LocalDateTime now);

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
