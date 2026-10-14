package com.jlsp.backend.flashcard.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.flashcard.dto.request.*;
import com.jlsp.backend.flashcard.dto.response.*;
import com.jlsp.backend.flashcard.service.FlashcardService;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/flashcards")
@RequiredArgsConstructor
public class FlashcardController {

    private final FlashcardService flashcardService;
    private final UserRepository userRepository;

    private Long resolveUserId(Authentication authentication) {
        if (authentication == null || authentication.getName() == null || "anonymousUser".equals(authentication.getName())) {
            return userRepository.findAll().stream().findFirst().map(User::getId).orElse(1L);
        }
        return userRepository.findByUsername(authentication.getName())
                .map(User::getId)
                .orElseGet(() -> userRepository.findAll().stream().findFirst().map(User::getId).orElse(1L));
    }

    // 1. Lấy danh sách bộ thẻ (Thư viện thẻ)
    @GetMapping("/sets")
    public ResponseEntity<ApiResponse<PageResponse<FlashcardSetResponse>>> getSets(
            @RequestParam(required = false) String search,
            @PageableDefault(size = 20) Pageable pageable,
            Authentication authentication) {
        Long userId = resolveUserId(authentication);
        PageResponse<FlashcardSetResponse> response = flashcardService.getSets(userId, search, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    // 2. Tạo bộ thẻ mới (nút +)
    @PostMapping("/sets")
    public ResponseEntity<ApiResponse<FlashcardSetResponse>> createSet(
            @Valid @RequestBody CreateFlashcardSetRequest request,
            Authentication authentication) {
        Long userId = resolveUserId(authentication);
        FlashcardSetResponse response = flashcardService.createSet(userId, request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "Set created successfully", response));
    }

    // 3. Chi tiết bộ thẻ (Flashcard Overview)
    @GetMapping("/sets/{setId}")
    public ResponseEntity<ApiResponse<FlashcardSetResponse>> getSetById(
            @PathVariable Long setId,
            Authentication authentication) {
        Long userId = resolveUserId(authentication);
        FlashcardSetResponse response = flashcardService.getSetById(userId, setId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    // 4. Xóa bộ thẻ
    @DeleteMapping("/sets/{setId}")
    public ResponseEntity<ApiResponse<Void>> deleteSet(
            @PathVariable Long setId,
            Authentication authentication) {
        Long userId = resolveUserId(authentication);
        flashcardService.deleteSet(userId, setId);
        return ResponseEntity.ok(ApiResponse.success(200, "Set deleted successfully", null));
    }

    // 5. Lấy danh sách thẻ để học (Chế độ Thẻ ghi nhớ / Flashcard study)
    @GetMapping("/sets/{setId}/cards")
    public ResponseEntity<ApiResponse<List<FlashcardResponse>>> getCardsInSet(
            @PathVariable Long setId,
            @RequestParam(required = false, defaultValue = "false") Boolean starredOnly,
            @RequestParam(required = false, defaultValue = "false") Boolean shuffle,
            Authentication authentication) {
        Long userId = resolveUserId(authentication);
        List<FlashcardResponse> response = flashcardService.getCardsInSet(userId, setId, starredOnly, shuffle);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    // 6. Thêm thẻ vào bộ
    @PostMapping("/sets/{setId}/cards")
    public ResponseEntity<ApiResponse<FlashcardResponse>> addCard(
            @PathVariable Long setId,
            @Valid @RequestBody CreateFlashcardRequest request,
            Authentication authentication) {
        Long userId = resolveUserId(authentication);
        FlashcardResponse response = flashcardService.addCardToSet(userId, setId, request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "Card added successfully", response));
    }

    // 7. Xóa thẻ
    @DeleteMapping("/cards/{cardId}")
    public ResponseEntity<ApiResponse<Void>> deleteCard(
            @PathVariable Long cardId,
            Authentication authentication) {
        Long userId = resolveUserId(authentication);
        flashcardService.deleteCard(userId, cardId);
        return ResponseEntity.ok(ApiResponse.success(200, "Card deleted successfully", null));
    }

    // 8. Đánh dấu sao / Bỏ sao (Favorite / Starred)
    @PostMapping("/cards/{cardId}/star")
    public ResponseEntity<ApiResponse<FlashcardResponse>> updateCardStar(
            @PathVariable Long cardId,
            @Valid @RequestBody UpdateCardStarRequest request,
            Authentication authentication) {
        Long userId = resolveUserId(authentication);
        FlashcardResponse response = flashcardService.updateCardStar(userId, cardId, request.getIsStarred());
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    // 9. Nộp kết quả ôn tập (Spaced Repetition / Leitner box level)
    @PostMapping("/study/answer")
    public ResponseEntity<ApiResponse<Void>> submitCardAnswer(
            @Valid @RequestBody SubmitCardAnswerRequest request,
            Authentication authentication) {
        Long userId = resolveUserId(authentication);
        flashcardService.submitCardAnswer(userId, request);
        return ResponseEntity.ok(ApiResponse.success(200, "Answer recorded successfully", null));
    }

    // 10. Chế độ Trắc nghiệm (Sinh câu hỏi 4 lựa chọn)
    @GetMapping("/sets/{setId}/quiz")
    public ResponseEntity<ApiResponse<List<QuizQuestionResponse>>> generateQuiz(
            @PathVariable Long setId,
            @RequestParam(required = false, defaultValue = "32") Integer limit,
            Authentication authentication) {
        Long userId = resolveUserId(authentication);
        List<QuizQuestionResponse> response = flashcardService.generateQuiz(userId, setId, limit);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    // 11. Chế độ Ghép thẻ (Sinh 10 ô bài ghép đôi)
    @GetMapping("/sets/{setId}/matching")
    public ResponseEntity<ApiResponse<MatchingGameResponse>> generateMatchingGame(
            @PathVariable Long setId,
            @RequestParam(required = false, defaultValue = "5") Integer pairCount) {
        MatchingGameResponse response = flashcardService.generateMatchingGame(setId, pairCount);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    // 12. Đặt lại tiến trình thẻ (Reset Progress)
    @PostMapping("/sets/{setId}/reset")
    public ResponseEntity<ApiResponse<Void>> resetProgress(
            @PathVariable Long setId,
            Authentication authentication) {
        Long userId = resolveUserId(authentication);
        flashcardService.resetSetProgress(userId, setId);
        return ResponseEntity.ok(ApiResponse.success(200, "Progress reset successfully", null));
    }

    // 13. Lưu từ vựng từ Video vào bộ "Từ vựng đã lưu từ Video"
    @PostMapping("/video/save")
    public ResponseEntity<ApiResponse<FlashcardResponse>> saveVideoVocab(
            @Valid @RequestBody SaveVideoVocabRequest request,
            Authentication authentication) {
        Long userId = resolveUserId(authentication);
        FlashcardResponse response = flashcardService.saveVideoVocab(userId, request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "Vocab saved from video successfully", response));
    }
}
