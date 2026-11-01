package com.jlsp.backend.user.repository;

import com.jlsp.backend.user.entity.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    /** Khoá dòng người dùng khi cộng hạn VIP, để hai đơn thanh toán cùng lúc không ghi đè lên nhau. */
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @org.springframework.data.jpa.repository.Query("SELECT u FROM User u WHERE u.id = :id")
    Optional<User> findByIdForUpdate(@org.springframework.data.repository.query.Param("id") Long id);

    @EntityGraph(attributePaths = "subscriptionPlan")
    Optional<User> findByUsername(String username);

    @EntityGraph(attributePaths = "subscriptionPlan")
    Optional<User> findByEmail(String email);

    @Override
    @EntityGraph(attributePaths = "subscriptionPlan")
    Optional<User> findById(Long id);

    boolean existsByUsername(String username);

    boolean existsByEmail(String email);

    /**
     * Email so khớp không phân biệt hoa thường (dữ liệu cũ có thể còn chữ hoa). Đăng nhập dùng hàm này rồi map sang
     * UserResponse (đọc tên gói) ngoài phiên làm việc, nên phải nạp sẵn gói, nếu không người đã mua gói đăng nhập sẽ
     * bị lỗi 500 (LazyInitializationException).
     */
    @EntityGraph(attributePaths = "subscriptionPlan")
    Optional<User> findByEmailIgnoreCase(String email);

    @EntityGraph(attributePaths = "subscriptionPlan")
    Optional<User> findByGoogleSub(String googleSub);

    boolean existsByEmailIgnoreCase(String email);

    Page<User> findByIsActiveTrue(Pageable pageable);

    @org.springframework.data.jpa.repository.Query("SELECT u FROM User u WHERE " +
            "(:role IS NULL OR u.role = :role) AND " +
            "(:search IS NULL OR :search = '' OR " +
            "LOWER(u.username) LIKE LOWER(CONCAT('%', :search, '%')) OR " +
            "LOWER(u.email) LIKE LOWER(CONCAT('%', :search, '%')) OR " +
            "LOWER(u.displayName) LIKE LOWER(CONCAT('%', :search, '%')))")
    Page<User> searchUsers(
            @org.springframework.data.repository.query.Param("search") String search,
            @org.springframework.data.repository.query.Param("role") com.jlsp.backend.user.entity.UserRole role,
            Pageable pageable);

    /** Tìm công khai theo username / tên hiển thị, chỉ tài khoản đang hoạt động (không dò theo email). */
    @org.springframework.data.jpa.repository.Query("SELECT u FROM User u WHERE u.isActive = true " +
            "AND u.id NOT IN :excluded AND (" +
            "LOWER(u.username) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
            "LOWER(u.displayName) LIKE LOWER(CONCAT('%', :q, '%')))")
    Page<User> searchActivePublic(
            @org.springframework.data.repository.query.Param("q") String q,
            @org.springframework.data.repository.query.Param("excluded") java.util.Collection<Long> excluded,
            Pageable pageable);

    long countByUsernameStartingWith(String prefix);

    long countByRole(com.jlsp.backend.user.entity.UserRole role);

    long countByRoleAndIsActive(com.jlsp.backend.user.entity.UserRole role, Boolean isActive);

    long countByIsActive(Boolean isActive);

    /** Số tài khoản đăng ký mỗi ngày trong [from, to) — gộp ở DB, không tải người dùng về. */
    @org.springframework.data.jpa.repository.Query("SELECT year(u.createdAt) AS yr, month(u.createdAt) AS mo, " +
            "day(u.createdAt) AS dy, COUNT(u) AS total FROM User u " +
            "WHERE u.role = :role AND u.createdAt >= :from AND u.createdAt < :to " +
            "GROUP BY year(u.createdAt), month(u.createdAt), day(u.createdAt)")
    java.util.List<com.jlsp.backend.admin.dto.DayTotal> countRegistrationsByDay(
            @org.springframework.data.repository.query.Param("role") com.jlsp.backend.user.entity.UserRole role,
            @org.springframework.data.repository.query.Param("from") java.time.LocalDateTime from,
            @org.springframework.data.repository.query.Param("to") java.time.LocalDateTime to);
}
