package com.jlsp.backend.flashcard.dto.response;

import lombok.*;

import java.time.LocalDateTime;
import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FlashcardSetResponse {

    private Long setId;
    private String title;
    private String description;
    private Boolean isPublic;
    private Boolean isVideoSaved;
    
    // Author info
    private Long authorId;
    private String authorName;
    private String authorAvatarUrl;
    private Boolean isAuthorPro;

    /** Người xem chính là chủ bộ thẻ (chỉ có ở API chi tiết). */
    private Boolean isOwner;
    /** Id bản sao người xem đã lưu về thư viện từ bộ này; null nếu chưa lưu hoặc là chủ bộ (chỉ có ở API chi tiết). */
    private Long savedSetId;

    // Progress & counts
    private Integer totalCards;
    private Integer learnedCards;
    private Double progressPercentage;

    // Preview cards for Overview Carousel
    private List<FlashcardResponse> previewCards;

    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
