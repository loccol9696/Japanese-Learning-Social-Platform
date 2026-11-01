package com.jlsp.backend.flashcard.dto.response;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StudySessionResponse {

    private Long setId;
    private List<StudyCardResponse> cards;
    private int newCount;
    private int dueCount;
}
