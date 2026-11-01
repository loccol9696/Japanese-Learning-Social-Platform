package com.jlsp.backend.flashcard.entity;

import com.jlsp.backend.user.entity.User;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "flashcard_sets")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FlashcardSet {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "set_id")
    private Long setId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 255)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "is_public", nullable = false)
    @Builder.Default
    private Boolean isPublic = false;

    @Column(name = "is_video_saved", nullable = false)
    @Builder.Default
    private Boolean isVideoSaved = false;

    @OneToMany(mappedBy = "flashcardSet", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<Flashcard> flashcards = new ArrayList<>();

    /** Thứ tự người dùng tự sắp xếp trong thư viện; null (bộ mới) hiện trên cùng. */
    @Column(name = "sort_order")
    private Integer sortOrder;

    /** Bộ thẻ gốc nếu đây là bản sao "Lưu về thư viện" từ bộ của người khác; null nếu tự tạo. */
    @Column(name = "source_set_id")
    private Long sourceSetId;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}
