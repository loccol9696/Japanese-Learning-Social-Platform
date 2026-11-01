package com.jlsp.backend.streak.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.io.Serializable;
import java.time.LocalDate;

/** Một ngày người dùng đã học; nguồn dữ liệu cho lịch chuỗi học. */
@Entity
@Table(name = "user_streak_days")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class UserStreakDay {

    @EmbeddedId
    private Id id;

    @Embeddable
    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    @EqualsAndHashCode
    public static class Id implements Serializable {

        @Column(name = "user_id")
        private Long userId;

        @Column(name = "activity_date")
        private LocalDate activityDate;
    }
}
