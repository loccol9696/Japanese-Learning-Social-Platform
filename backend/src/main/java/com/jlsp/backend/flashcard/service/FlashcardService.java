package com.jlsp.backend.flashcard.service;

import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.flashcard.dto.request.*;
import com.jlsp.backend.flashcard.dto.response.*;
import org.springframework.data.domain.Pageable;

import java.util.List;

public interface FlashcardService {

    FlashcardSetResponse createSet(Long userId, CreateFlashcardSetRequest request);

    PageResponse<FlashcardSetResponse> getSets(Long userId, String keyword, Pageable pageable);

    FlashcardSetResponse getSetById(Long userId, Long setId);

    void deleteSet(Long userId, Long setId);

    List<FlashcardResponse> getCardsInSet(Long userId, Long setId, Boolean starredOnly, Boolean shuffle);

    FlashcardResponse addCardToSet(Long userId, Long setId, CreateFlashcardRequest request);

    void deleteCard(Long userId, Long cardId);

    FlashcardResponse updateCardStar(Long userId, Long cardId, Boolean isStarred);

    void submitCardAnswer(Long userId, SubmitCardAnswerRequest request);

    List<QuizQuestionResponse> generateQuiz(Long userId, Long setId, Integer limit);

    MatchingGameResponse generateMatchingGame(Long setId, Integer pairCount);

    void resetSetProgress(Long userId, Long setId);

    FlashcardResponse saveVideoVocab(Long userId, SaveVideoVocabRequest request);
}
