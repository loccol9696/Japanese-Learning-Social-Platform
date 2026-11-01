package com.jlsp.backend.flashcard.service;

import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.flashcard.dto.request.*;
import com.jlsp.backend.flashcard.dto.response.*;
import org.springframework.data.domain.Pageable;

import java.util.List;

public interface FlashcardService {

    FlashcardSetResponse createSet(Long userId, CreateFlashcardSetRequest request);

    FlashcardSetResponse updateSet(Long userId, Long setId, CreateFlashcardSetRequest request);

    PageResponse<FlashcardSetResponse> getSets(Long userId, String keyword, Pageable pageable);

    FlashcardSetResponse getSetById(Long userId, Long setId);

    void deleteSet(Long userId, Long setId);

    /** Lưu thứ tự bộ thẻ trong thư viện sau khi người dùng kéo thả. */
    void reorderSets(Long userId, java.util.List<Long> orderedSetIds);

    /** Lưu thứ tự thẻ trong một bộ (chỉ chủ bộ thẻ). */
    void reorderCards(Long userId, Long setId, java.util.List<Long> orderedCardIds);

    List<FlashcardResponse> getCardsInSet(Long userId, Long setId, Boolean starredOnly, Boolean shuffle);

    FlashcardResponse addCardToSet(Long userId, Long setId, CreateFlashcardRequest request);

    void deleteCard(Long userId, Long cardId);

    FlashcardResponse updateCard(Long userId, Long cardId, CreateFlashcardRequest request);

    FlashcardResponse updateCardStar(Long userId, Long cardId, Boolean isStarred);

    StudySessionResponse getStudySession(Long userId, Long setId, Integer newLimit);

    StudySessionResponse getDueSession(Long userId, Integer limit);

    ReviewResultResponse reviewCard(Long userId, ReviewCardRequest request);

    DueSummaryResponse getDueSummary(Long userId);

    void submitCardAnswer(Long userId, SubmitCardAnswerRequest request);

    List<QuizQuestionResponse> generateQuiz(Long userId, Long setId, Integer limit);

    MatchingGameResponse generateMatchingGame(Long userId, Long setId, Integer pairCount);

    void resetSetProgress(Long userId, Long setId);

    FlashcardResponse saveVideoVocab(Long userId, SaveVideoVocabRequest request);
}
