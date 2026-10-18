package com.jlsp.backend.flashcard.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "flashcards")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Flashcard {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "card_id")
    private Long cardId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "set_id", nullable = false)
    private FlashcardSet flashcardSet;

    @Column(nullable = false, length = 255)
    private String term;

    @Column(length = 255)
    private String reading;

    @Column(name = "sino_vietnamese", length = 100)
    private String sinoVietnamese;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String meaning;

    @Column(columnDefinition = "TEXT")
    private String example;

    @Column(name = "audio_url", length = 500)
    private String audioUrl;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}
