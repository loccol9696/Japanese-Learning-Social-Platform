package com.jlsp.backend.flashcard.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.*;

import java.io.Serializable;

@Embeddable
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode
@Builder
public class FlashcardProgressId implements Serializable {

    @Column(name = "user_id")
    private Long userId;

    @Column(name = "card_id")
    private Long cardId;
}
