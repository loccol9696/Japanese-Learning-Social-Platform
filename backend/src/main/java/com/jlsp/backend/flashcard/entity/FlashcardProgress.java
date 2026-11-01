package com.jlsp.backend.flashcard.entity;

import com.jlsp.backend.user.entity.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "flashcard_progress")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FlashcardProgress {

    @EmbeddedId
    private FlashcardProgressId id;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("userId")
    @JoinColumn(name = "user_id")
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("cardId")
    @JoinColumn(name = "card_id")
    private Flashcard flashcard;

    @Column(name = "box_level", nullable = false)
    @Builder.Default
    private Integer boxLevel = 0;

    @Column(name = "is_starred", nullable = false)
    @Builder.Default
    private Boolean isStarred = false;

    @Column(name = "correct_count", nullable = false)
    @Builder.Default
    private Integer correctCount = 0;

    @Column(name = "incorrect_count", nullable = false)
    @Builder.Default
    private Integer incorrectCount = 0;

    @Column(name = "next_review_at")
    private LocalDateTime nextReviewAt;

    @Column(name = "last_reviewed_at")
    private LocalDateTime lastReviewedAt;

    @Column(name = "ease_factor", nullable = false, columnDefinition = "double precision default 2.5 not null")
    @Builder.Default
    private Double easeFactor = 2.5;

    @Column(name = "interval_days", nullable = false, columnDefinition = "integer default 0 not null")
    @Builder.Default
    private Integer intervalDays = 0;

    @Column(name = "review_count", nullable = false, columnDefinition = "integer default 0 not null")
    @Builder.Default
    private Integer reviewCount = 0;

    @Column(name = "lapse_count", nullable = false, columnDefinition = "integer default 0 not null")
    @Builder.Default
    private Integer lapseCount = 0;

    @Enumerated(EnumType.STRING)
    @Column(name = "srs_state", nullable = false, length = 16, columnDefinition = "varchar(16) default 'NEW' not null")
    @Builder.Default
    private com.jlsp.backend.flashcard.srs.CardState srsState = com.jlsp.backend.flashcard.srs.CardState.NEW;
}
