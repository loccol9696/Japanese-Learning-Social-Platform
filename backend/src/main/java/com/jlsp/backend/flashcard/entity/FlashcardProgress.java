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
}
