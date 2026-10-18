package com.jlsp.backend.user.repository;

import com.jlsp.backend.common.projection.DailyTotal;
import com.jlsp.backend.user.entity.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByUsername(String username);

    Optional<User> findByEmail(String email);

    boolean existsByUsername(String username);

    boolean existsByEmail(String email);

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

    long countByUsernameStartingWith(String prefix);

    long countByRole(com.jlsp.backend.user.entity.UserRole role);

    long countByRoleAndIsActive(com.jlsp.backend.user.entity.UserRole role, Boolean isActive);

    /** Số tài khoản tạo mới theo từng ngày trong [from, to). */
    @org.springframework.data.jpa.repository.Query("SELECT CAST(u.createdAt AS LocalDate) AS day, COUNT(u) AS total " +
            "FROM User u WHERE u.role = :role AND u.createdAt >= :from AND u.createdAt < :to " +
            "GROUP BY CAST(u.createdAt AS LocalDate)")
    java.util.List<DailyTotal> countCreatedPerDay(
            @org.springframework.data.repository.query.Param("role") com.jlsp.backend.user.entity.UserRole role,
            @org.springframework.data.repository.query.Param("from") java.time.LocalDateTime from,
            @org.springframework.data.repository.query.Param("to") java.time.LocalDateTime to);

    long countByIsActive(Boolean isActive);
}
