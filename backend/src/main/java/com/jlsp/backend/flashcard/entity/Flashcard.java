package com.jlsp.backend.flashcard.entity;

import jakarta.persistence.*;
import lombok.*;

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
    private Long id;

    @Column(name = "lesson_id")
    private Long lessonId;

    @Column(name = "front_text", nullable = false, columnDefinition = "NTEXT")
    private String frontText;

    @Column(name = "back_text", nullable = false, columnDefinition = "NTEXT")
    private String backText;

    @Column(columnDefinition = "NVARCHAR(255)")
    private String reading;

    @Column(columnDefinition = "NTEXT")
    private String example;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}
