package com.jlsp.backend.streak.repository;

import com.jlsp.backend.streak.entity.UserStreak;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserStreakRepository extends JpaRepository<UserStreak, Long> {

    /**
     * Tạo dòng rỗng nếu chưa có. Dùng ON CONFLICT để hai hoạt động đồng thời của người dùng mới không đụng
     * khoá chính (PostgreSQL).
     */
    @Modifying
    @Query(value = "INSERT INTO user_streaks (user_id, current_streak, longest_streak, updated_at) "
            + "VALUES (:userId, 0, 0, now()) ON CONFLICT (user_id) DO NOTHING", nativeQuery = true)
    void insertIfAbsent(@Param("userId") Long userId);

    /** Khoá dòng để các hoạt động đồng thời của cùng một người cập nhật tuần tự. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT s FROM UserStreak s WHERE s.userId = :userId")
    Optional<UserStreak> findForUpdate(@Param("userId") Long userId);
}
