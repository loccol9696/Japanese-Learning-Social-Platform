package com.jlsp.backend.streak.repository;

import com.jlsp.backend.streak.entity.UserStreakDay;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface UserStreakDayRepository extends JpaRepository<UserStreakDay, UserStreakDay.Id> {

    /** Ghi nhận ngày học; học nhiều lần trong ngày hoặc đồng thời thì không lỗi (PostgreSQL). */
    @Modifying
    @Query(value = "INSERT INTO user_streak_days (user_id, activity_date) VALUES (:userId, :day) "
            + "ON CONFLICT DO NOTHING", nativeQuery = true)
    void insertIfAbsent(@Param("userId") Long userId, @Param("day") LocalDate day);

    @Query("SELECT d.id.activityDate FROM UserStreakDay d "
            + "WHERE d.id.userId = :userId AND d.id.activityDate BETWEEN :from AND :to "
            + "ORDER BY d.id.activityDate")
    List<LocalDate> findDays(@Param("userId") Long userId, @Param("from") LocalDate from, @Param("to") LocalDate to);
}
