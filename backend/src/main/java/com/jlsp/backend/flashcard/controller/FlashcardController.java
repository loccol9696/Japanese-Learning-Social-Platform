package com.jlsp.backend.flashcard.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.security.CurrentUser;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.flashcard.dto.request.*;
import com.jlsp.backend.flashcard.dto.response.*;
import com.jlsp.backend.flashcard.service.FlashcardService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/flashcards")
public class FlashcardController {

    private final FlashcardService flashcardService;

    public FlashcardController(FlashcardService flashcardService) {
        this.flashcardService = flashcardService;
    }

    // 1. Lấy danh sách bộ thẻ (Thư viện thẻ)
    @GetMapping("/sets")
    public ResponseEntity<ApiResponse<PageResponse<FlashcardSetResponse>>> getSets(
            @RequestParam(required = false) String search,
            @PageableDefault(size = 20) Pageable pageable) {
        Long userId = CurrentUser.requireId();
        PageResponse<FlashcardSetResponse> response = flashcardService.getSets(userId, search, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    // 2. Tạo bộ thẻ mới (nút +)
    @PostMapping("/sets")
    public ResponseEntity<ApiResponse<FlashcardSetResponse>> createSet(
            @Valid @RequestBody CreateFlashcardSetRequest request) {
        Long userId = CurrentUser.requireId();
        FlashcardSetResponse response = flashcardService.createSet(userId, request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "Set created successfully", response));
    }

    // 3. Chi tiết bộ thẻ (Flashcard Overview)
    @GetMapping("/sets/{setId}")
    public ResponseEntity<ApiResponse<FlashcardSetResponse>> getSetById(
            @PathVariable Long setId) {
        Long userId = CurrentUser.requireId();
        FlashcardSetResponse response = flashcardService.getSetById(userId, setId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    // 3b. Cập nhật thông tin bộ thẻ
    @PutMapping("/sets/{setId}")
    public ResponseEntity<ApiResponse<FlashcardSetResponse>> updateSet(
            @PathVariable Long setId,
            @Valid @RequestBody CreateFlashcardSetRequest request) {
        Long userId = CurrentUser.requireId();
        FlashcardSetResponse response = flashcardService.updateSet(userId, setId, request);
        return ResponseEntity.ok(ApiResponse.success(200, "Set updated successfully", response));
    }

    // 4. Xóa bộ thẻ
    @DeleteMapping("/sets/{setId}")
    public ResponseEntity<ApiResponse<Void>> deleteSet(
            @PathVariable Long setId) {
        Long userId = CurrentUser.requireId();
        flashcardService.deleteSet(userId, setId);
        return ResponseEntity.ok(ApiResponse.success(200, "Set deleted successfully", null));
    }

    // 4b. Sắp xếp lại bộ thẻ trong thư viện
    @PutMapping("/sets/order")
    public ResponseEntity<ApiResponse<Void>> reorderSets(@Valid @RequestBody ReorderRequest request) {
        flashcardService.reorderSets(CurrentUser.requireId(), request.getIds());
        return ResponseEntity.ok(ApiResponse.success(200, "Sets reordered successfully", null));
    }

    // 4c. Sắp xếp lại thẻ trong một bộ
    @PutMapping("/sets/{setId}/cards/order")
    public ResponseEntity<ApiResponse<Void>> reorderCards(
            @PathVariable Long setId,
            @Valid @RequestBody ReorderRequest request) {
        flashcardService.reorderCards(CurrentUser.requireId(), setId, request.getIds());
        return ResponseEntity.ok(ApiResponse.success(200, "Cards reordered successfully", null));
    }

    // 5. Lấy danh sách thẻ để học (Chế độ Thẻ ghi nhớ / Flashcard study)
    @GetMapping("/sets/{setId}/cards")
    public ResponseEntity<ApiResponse<List<FlashcardResponse>>> getCardsInSet(
            @PathVariable Long setId,
            @RequestParam(required = false, defaultValue = "false") Boolean starredOnly,
            @RequestParam(required = false, defaultValue = "false") Boolean shuffle) {
        Long userId = CurrentUser.requireId();
        List<FlashcardResponse> response = flashcardService.getCardsInSet(userId, setId, starredOnly, shuffle);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    // 6. Thêm thẻ vào bộ
    @PostMapping("/sets/{setId}/cards")
    public ResponseEntity<ApiResponse<FlashcardResponse>> addCard(
            @PathVariable Long setId,
            @Valid @RequestBody CreateFlashcardRequest request) {
        Long userId = CurrentUser.requireId();
        FlashcardResponse response = flashcardService.addCardToSet(userId, setId, request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "Card added successfully", response));
    }

    // 7. Xóa thẻ
    @DeleteMapping("/cards/{cardId}")
    public ResponseEntity<ApiResponse<Void>> deleteCard(
            @PathVariable Long cardId) {
        Long userId = CurrentUser.requireId();
        flashcardService.deleteCard(userId, cardId);
        return ResponseEntity.ok(ApiResponse.success(200, "Card deleted successfully", null));
    }

    // 7b. Cập nhật thẻ
    @PutMapping("/cards/{cardId}")
    public ResponseEntity<ApiResponse<FlashcardResponse>> updateCard(
            @PathVariable Long cardId,
            @Valid @RequestBody CreateFlashcardRequest request) {
        Long userId = CurrentUser.requireId();
        FlashcardResponse response = flashcardService.updateCard(userId, cardId, request);
        return ResponseEntity.ok(ApiResponse.success(200, "Card updated successfully", response));
    }

    // 8. Đánh dấu sao / Bỏ sao (Favorite / Starred)
    @PostMapping("/cards/{cardId}/star")
    public ResponseEntity<ApiResponse<FlashcardResponse>> updateCardStar(
            @PathVariable Long cardId,
            @Valid @RequestBody UpdateCardStarRequest request) {
        Long userId = CurrentUser.requireId();
        FlashcardResponse response = flashcardService.updateCardStar(userId, cardId, request.getIsStarred());
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    // 9. Nộp kết quả ôn tập (Spaced Repetition / Leitner box level)
    @PostMapping("/study/answer")
    public ResponseEntity<ApiResponse<Void>> submitCardAnswer(
            @Valid @RequestBody SubmitCardAnswerRequest request) {
        Long userId = CurrentUser.requireId();
        flashcardService.submitCardAnswer(userId, request);
        return ResponseEntity.ok(ApiResponse.success(200, "Answer recorded successfully", null));
    }

    // 9b. Phiên học ngắt quãng: thẻ đang học + thẻ đến hạn + thẻ mới
    @GetMapping("/sets/{setId}/study-session")
    public ResponseEntity<ApiResponse<StudySessionResponse>> getStudySession(
            @PathVariable Long setId,
            @RequestParam(required = false, defaultValue = "20") Integer newLimit) {
        Long userId = CurrentUser.requireId();
        return ResponseEntity.ok(ApiResponse.success(flashcardService.getStudySession(userId, setId, newLimit)));
    }

    // 9b'. Phiên ôn các thẻ đã tới hạn của mọi bộ (không gồm thẻ mới)
    @GetMapping("/study/due-session")
    public ResponseEntity<ApiResponse<StudySessionResponse>> getDueSession(
            @RequestParam(required = false, defaultValue = "50") Integer limit) {
        Long userId = CurrentUser.requireId();
        return ResponseEntity.ok(ApiResponse.success(flashcardService.getDueSession(userId, limit)));
    }

    // 9c. Ghi nhận một lần đánh giá (Xem lại / Khó / Ổn / Dễ)
    @PostMapping("/study/review")
    public ResponseEntity<ApiResponse<ReviewResultResponse>> reviewCard(
            @Valid @RequestBody ReviewCardRequest request) {
        Long userId = CurrentUser.requireId();
        return ResponseEntity.ok(ApiResponse.success(flashcardService.reviewCard(userId, request)));
    }

    // 9d. Tóm tắt thẻ cần ôn (dùng cho huy hiệu và nhắc nhở)
    @GetMapping("/study/due-summary")
    public ResponseEntity<ApiResponse<DueSummaryResponse>> getDueSummary() {
        Long userId = CurrentUser.requireId();
        return ResponseEntity.ok(ApiResponse.success(flashcardService.getDueSummary(userId)));
    }

    // 10. Chế độ Trắc nghiệm (Sinh câu hỏi 4 lựa chọn)
    @GetMapping("/sets/{setId}/quiz")
    public ResponseEntity<ApiResponse<List<QuizQuestionResponse>>> generateQuiz(
            @PathVariable Long setId,
            @RequestParam(required = false, defaultValue = "32") Integer limit) {
        Long userId = CurrentUser.requireId();
        List<QuizQuestionResponse> response = flashcardService.generateQuiz(userId, setId, limit);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    // 11. Chế độ Ghép thẻ (Sinh 10 ô bài ghép đôi)
    @GetMapping("/sets/{setId}/matching")
    public ResponseEntity<ApiResponse<MatchingGameResponse>> generateMatchingGame(
            @PathVariable Long setId,
            @RequestParam(required = false, defaultValue = "5") Integer pairCount) {
        Long userId = CurrentUser.requireId();
        MatchingGameResponse response = flashcardService.generateMatchingGame(userId, setId, pairCount);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    // 12. Đặt lại tiến trình thẻ (Reset Progress)
    @PostMapping("/sets/{setId}/reset")
    public ResponseEntity<ApiResponse<Void>> resetProgress(
            @PathVariable Long setId) {
        Long userId = CurrentUser.requireId();
        flashcardService.resetSetProgress(userId, setId);
        return ResponseEntity.ok(ApiResponse.success(200, "Progress reset successfully", null));
    }

    // 13. Lưu từ vựng từ Video vào bộ "Từ vựng đã lưu từ Video"
    @PostMapping("/video/save")
    public ResponseEntity<ApiResponse<FlashcardResponse>> saveVideoVocab(
            @Valid @RequestBody SaveVideoVocabRequest request) {
        Long userId = CurrentUser.requireId();
        FlashcardResponse response = flashcardService.saveVideoVocab(userId, request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "Vocab saved from video successfully", response));
    }
}
