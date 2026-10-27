package com.jlsp.backend.flashcard.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.repository.IdCount;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.flashcard.dto.request.*;
import com.jlsp.backend.flashcard.dto.response.*;
import com.jlsp.backend.flashcard.entity.Flashcard;
import com.jlsp.backend.flashcard.entity.FlashcardProgress;
import com.jlsp.backend.flashcard.entity.FlashcardProgressId;
import com.jlsp.backend.flashcard.entity.FlashcardSet;
import com.jlsp.backend.flashcard.repository.FlashcardProgressRepository;
import com.jlsp.backend.flashcard.repository.FlashcardRepository;
import com.jlsp.backend.flashcard.repository.FlashcardSetRepository;
import com.jlsp.backend.flashcard.srs.*;
import com.jlsp.backend.flashcard.service.FlashcardService;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Quy tắc truy cập: <b>đọc / luyện tập</b> một bộ thẻ cần là chủ sở hữu hoặc bộ đó công khai (người khác
 * không thấy bộ riêng tư, coi như không tồn tại); <b>sửa / xoá / học theo lịch ôn</b> chỉ dành cho chủ sở hữu.
 */
@Service
public class FlashcardServiceImpl implements FlashcardService {

    /** Số thẻ tối đa trong một bộ (chặn tạo vô hạn, giữ các thao tác tải cả bộ ở mức chấp nhận được). */
    static final int MAX_CARDS_PER_SET = 2000;
    /** Số câu tối đa của một bài trắc nghiệm trong một lần gọi. */
    static final int MAX_QUIZ_QUESTIONS = 100;
    /** Số cặp tối đa của một ván ghép thẻ. */
    static final int MAX_MATCHING_PAIRS = 20;
    /** Số thẻ xem trước khi mở chi tiết một bộ. */
    private static final int DETAIL_PREVIEW_CARDS = 10;
    private static final int CREATE_PREVIEW_CARDS = 5;

    private final FlashcardSetRepository setRepository;
    private final FlashcardRepository cardRepository;
    private final FlashcardProgressRepository progressRepository;
    private final UserRepository userRepository;

    public FlashcardServiceImpl(
            FlashcardSetRepository setRepository,
            FlashcardRepository cardRepository,
            FlashcardProgressRepository progressRepository,
            UserRepository userRepository) {
        this.setRepository = setRepository;
        this.cardRepository = cardRepository;
        this.progressRepository = progressRepository;
        this.userRepository = userRepository;
    }

    // ------------------------------------------------------------------ bộ thẻ

    @Override
    @Transactional
    public FlashcardSetResponse createSet(Long userId, CreateFlashcardSetRequest request) {
        User user = getUserOrThrow(userId);
        if (request.getCards() != null && request.getCards().size() > MAX_CARDS_PER_SET) {
            throw new AppException(400, "Một bộ thẻ tối đa " + MAX_CARDS_PER_SET + " thẻ");
        }

        FlashcardSet set = FlashcardSet.builder()
                .user(user)
                .title(request.getTitle())
                .description(request.getDescription())
                .isPublic(Boolean.TRUE.equals(request.getIsPublic()))
                .isVideoSaved(false)
                .build();

        if (request.getCards() != null && !request.getCards().isEmpty()) {
            List<Flashcard> cards = request.getCards().stream().map(c -> Flashcard.builder()
                    .flashcardSet(set)
                    .term(c.getTerm())
                    .reading(c.getReading())
                    .sinoVietnamese(c.getSinoVietnamese())
                    .meaning(c.getMeaning())
                    .example(c.getExample())
                    .audioUrl(c.getAudioUrl())
                    .build()).collect(Collectors.toList());
            set.setFlashcards(cards);
        }

        FlashcardSet saved = setRepository.save(set);
        List<Flashcard> savedCards = saved.getFlashcards() != null ? saved.getFlashcards() : List.of();
        List<FlashcardResponse> preview = savedCards.stream()
                .limit(CREATE_PREVIEW_CARDS)
                .map(c -> mapToCardResponse(c, null))
                .collect(Collectors.toList());
        return mapToSetResponse(saved, savedCards.size(), 0, preview);
    }

    @Override
    @Transactional
    public FlashcardSetResponse updateSet(Long userId, Long setId, CreateFlashcardSetRequest request) {
        FlashcardSet set = requireOwnedSet(userId, setId, "You do not have permission to update this set");
        if (request.getTitle() != null && !request.getTitle().trim().isEmpty()) {
            set.setTitle(request.getTitle().trim());
        }
        if (request.getDescription() != null) {
            set.setDescription(request.getDescription().trim());
        }
        if (request.getIsPublic() != null) {
            set.setIsPublic(request.getIsPublic());
        }
        FlashcardSet saved = setRepository.save(set);
        return mapToSetResponse(saved, cardRepository.countByFlashcardSetSetId(setId),
                progressRepository.countMasteredCards(userId, setId), List.of());
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<FlashcardSetResponse> getSets(Long userId, String keyword, Pageable pageable) {
        Page<FlashcardSet> page;
        if (keyword != null && !keyword.trim().isEmpty()) {
            page = setRepository.searchUserSets(userId, keyword.trim(), pageable);
        } else {
            page = setRepository.findUserSets(userId, pageable);
        }

        // Đếm số thẻ và số thẻ đã thuộc cho cả trang bằng hai truy vấn gộp, không tải từng bộ thẻ lên chỉ để đếm.
        List<Long> setIds = page.getContent().stream().map(FlashcardSet::getSetId).toList();
        Map<Long, Long> totals = setIds.isEmpty()
                ? Map.of() : IdCount.toMap(cardRepository.countBySetIds(setIds));
        Map<Long, Long> mastered = setIds.isEmpty()
                ? Map.of() : IdCount.toMap(progressRepository.countMasteredBySetIds(userId, setIds));

        List<FlashcardSetResponse> content = page.getContent().stream()
                .map(set -> mapToSetResponse(set,
                        totals.getOrDefault(set.getSetId(), 0L),
                        mastered.getOrDefault(set.getSetId(), 0L),
                        List.of()))
                .collect(Collectors.toList());

        return PageResponse.<FlashcardSetResponse>builder()
                .content(content)
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public FlashcardSetResponse getSetById(Long userId, Long setId) {
        FlashcardSet set = requireReadableSet(userId, setId);
        List<FlashcardResponse> preview = cardRepository
                .findByFlashcardSetSetId(setId, PageRequest.of(0, DETAIL_PREVIEW_CARDS, Sort.by("cardId")))
                .getContent().stream()
                .map(c -> mapToCardResponse(c, null))
                .collect(Collectors.toList());
        return mapToSetResponse(set, cardRepository.countByFlashcardSetSetId(setId),
                progressRepository.countMasteredCards(userId, setId), preview);
    }

    @Override
    @Transactional
    public void deleteSet(Long userId, Long setId) {
        FlashcardSet set = requireOwnedSet(userId, setId, "You do not have permission to delete this set");
        progressRepository.deleteByUserIdAndSetId(userId, setId);
        setRepository.delete(set);
    }

    // ------------------------------------------------------------------ thẻ

    @Override
    @Transactional(readOnly = true)
    public List<FlashcardResponse> getCardsInSet(Long userId, Long setId, Boolean starredOnly, Boolean shuffle) {
        requireReadableSet(userId, setId);
        List<Flashcard> cards = cardRepository.findByFlashcardSetSetId(setId);
        Map<Long, FlashcardProgress> progressMap = progressRepository.findByUserIdAndSetId(userId, setId).stream()
                .collect(Collectors.toMap(p -> p.getId().getCardId(), p -> p));

        List<FlashcardResponse> responses = cards.stream()
                .filter(card -> {
                    if (Boolean.TRUE.equals(starredOnly)) {
                        FlashcardProgress p = progressMap.get(card.getCardId());
                        return p != null && Boolean.TRUE.equals(p.getIsStarred());
                    }
                    return true;
                })
                .map(card -> mapToCardResponse(card, progressMap.get(card.getCardId())))
                .collect(Collectors.toList());

        if (Boolean.TRUE.equals(shuffle)) {
            Collections.shuffle(responses);
        }
        return responses;
    }

    @Override
    @Transactional
    public FlashcardResponse addCardToSet(Long userId, Long setId, CreateFlashcardRequest request) {
        FlashcardSet set = requireOwnedSet(userId, setId, "You do not have permission to add cards to this set");
        ensureRoomForCard(setId);

        Flashcard card = Flashcard.builder()
                .flashcardSet(set)
                .term(request.getTerm())
                .reading(request.getReading())
                .sinoVietnamese(request.getSinoVietnamese())
                .meaning(request.getMeaning())
                .example(request.getExample())
                .audioUrl(request.getAudioUrl())
                .build();

        Flashcard saved = cardRepository.save(card);
        return mapToCardResponse(saved, null);
    }

    @Override
    @Transactional
    public void deleteCard(Long userId, Long cardId) {
        Flashcard card = requireOwnedCard(userId, cardId, "You do not have permission to delete this card");
        cardRepository.delete(card);
    }

    @Override
    @Transactional
    public FlashcardResponse updateCard(Long userId, Long cardId, CreateFlashcardRequest request) {
        Flashcard card = requireOwnedCard(userId, cardId, "You do not have permission to update this card");
        if (request.getTerm() != null)
            card.setTerm(request.getTerm().trim());
        if (request.getReading() != null)
            card.setReading(request.getReading().trim());
        if (request.getMeaning() != null)
            card.setMeaning(request.getMeaning().trim());
        if (request.getSinoVietnamese() != null)
            card.setSinoVietnamese(request.getSinoVietnamese().trim());
        if (request.getExample() != null)
            card.setExample(request.getExample().trim());
        Flashcard saved = cardRepository.save(card);
        return mapToCardResponse(saved, null);
    }

    @Override
    @Transactional
    public FlashcardResponse updateCardStar(Long userId, Long cardId, Boolean isStarred) {
        User user = getUserOrThrow(userId);
        Flashcard card = requireReadableCard(userId, cardId);

        FlashcardProgress progress = progressRepository.findByIdUserIdAndIdCardId(userId, cardId)
                .orElseGet(() -> FlashcardProgress.builder()
                        .id(new FlashcardProgressId(userId, cardId))
                        .user(user)
                        .flashcard(card)
                        .boxLevel(0)
                        .correctCount(0)
                        .incorrectCount(0)
                        .build());

        progress.setIsStarred(Boolean.TRUE.equals(isStarred));
        FlashcardProgress saved = progressRepository.save(progress);
        return mapToCardResponse(card, saved);
    }

    @Override
    @Transactional
    public void submitCardAnswer(Long userId, SubmitCardAnswerRequest request) {
        User user = getUserOrThrow(userId);
        Flashcard card = requireReadableCard(userId, request.getCardId());

        FlashcardProgress progress = progressRepository.findByIdUserIdAndIdCardId(userId, request.getCardId())
                .orElseGet(() -> FlashcardProgress.builder()
                        .id(new FlashcardProgressId(userId, request.getCardId()))
                        .user(user)
                        .flashcard(card)
                        .boxLevel(0)
                        .correctCount(0)
                        .incorrectCount(0)
                        .isStarred(false)
                        .build());

        int currentLevel = progress.getBoxLevel() != null ? progress.getBoxLevel() : 0;
        LocalDateTime now = LocalDateTime.now();
        progress.setLastReviewedAt(now);

        if (Boolean.TRUE.equals(request.getIsCorrect())) {
            int newLevel = Math.min(5, currentLevel + 1);
            progress.setBoxLevel(newLevel);
            progress.setCorrectCount((progress.getCorrectCount() != null ? progress.getCorrectCount() : 0) + 1);
            progress.setNextReviewAt(calculateNextReview(now, newLevel));
        } else {
            int newLevel = Math.max(0, currentLevel - 1);
            progress.setBoxLevel(newLevel);
            progress.setIncorrectCount((progress.getIncorrectCount() != null ? progress.getIncorrectCount() : 0) + 1);
            progress.setNextReviewAt(now.plusHours(12));
        }

        progressRepository.save(progress);
    }

    // ------------------------------------------------------------------ trò chơi

    @Override
    @Transactional(readOnly = true)
    public List<QuizQuestionResponse> generateQuiz(Long userId, Long setId, Integer limit) {
        requireReadableSet(userId, setId);
        List<Flashcard> allCards = cardRepository.findByFlashcardSetSetId(setId);
        if (allCards.isEmpty()) {
            return Collections.emptyList();
        }

        List<Flashcard> quizPool = new ArrayList<>(allCards);
        Collections.shuffle(quizPool);
        int takeCount = (limit != null && limit > 0) ? Math.min(limit, quizPool.size()) : quizPool.size();
        takeCount = Math.min(takeCount, MAX_QUIZ_QUESTIONS);
        List<Flashcard> selectedCards = quizPool.subList(0, takeCount);

        // Một danh sách xáo trộn dùng chung để lấy đáp án nhiễu: mỗi câu duyệt từ một vị trí ngẫu nhiên,
        // tổng chi phí tuyến tính theo số câu thay vì dựng lại danh sách "các thẻ khác" cho từng câu.
        List<Flashcard> distractorPool = new ArrayList<>(allCards);
        Collections.shuffle(distractorPool);
        Random random = new Random();
        int optionCount = Math.min(4, allCards.size());

        List<QuizQuestionResponse> questions = new ArrayList<>(selectedCards.size());
        for (Flashcard card : selectedCards) {
            String correctAnswer = answerOf(card);

            List<String> options = new ArrayList<>(optionCount);
            options.add(correctAnswer);
            int start = random.nextInt(distractorPool.size());
            for (int i = 0; i < distractorPool.size() && options.size() < optionCount; i++) {
                Flashcard other = distractorPool.get((start + i) % distractorPool.size());
                if (other.getCardId().equals(card.getCardId())) {
                    continue;
                }
                String distractor = answerOf(other);
                if (options.stream().noneMatch(o -> o.equalsIgnoreCase(distractor))) {
                    options.add(distractor);
                }
            }
            Collections.shuffle(options);

            questions.add(QuizQuestionResponse.builder()
                    .cardId(card.getCardId())
                    .term(card.getTerm())
                    .sinoVietnamese(card.getSinoVietnamese())
                    .meaning(card.getMeaning())
                    .correctAnswer(correctAnswer)
                    .options(options)
                    .build());
        }

        return questions;
    }

    /** Đáp án hiển thị của một thẻ: cách đọc nếu có, không thì chính từ. */
    private static String answerOf(Flashcard card) {
        return (card.getReading() != null && !card.getReading().isBlank()) ? card.getReading() : card.getTerm();
    }

    @Override
    @Transactional(readOnly = true)
    public MatchingGameResponse generateMatchingGame(Long userId, Long setId, Integer pairCount) {
        requireReadableSet(userId, setId);
        List<Flashcard> cards = new ArrayList<>(cardRepository.findByFlashcardSetSetId(setId));
        Collections.shuffle(cards);

        int wanted = (pairCount != null && pairCount > 0) ? pairCount : 5;
        int count = Math.min(Math.min(wanted, MAX_MATCHING_PAIRS), cards.size());
        List<Flashcard> selected = cards.subList(0, count);

        List<MatchingGameResponse.MatchingTile> tiles = new ArrayList<>();
        int index = 0;
        for (Flashcard card : selected) {
            tiles.add(MatchingGameResponse.MatchingTile.builder()
                    .tileId("term_" + card.getCardId() + "_" + (++index))
                    .cardId(card.getCardId())
                    .text(answerOf(card))
                    .type("TERM")
                    .build());

            tiles.add(MatchingGameResponse.MatchingTile.builder()
                    .tileId("meaning_" + card.getCardId() + "_" + (++index))
                    .cardId(card.getCardId())
                    .text(card.getMeaning())
                    .type("MEANING")
                    .build());
        }

        Collections.shuffle(tiles);

        return MatchingGameResponse.builder()
                .setId(setId)
                .totalPairs(count)
                .tiles(tiles)
                .build();
    }

    // ------------------------------------------------------------------ học theo lịch ôn (SRS)

    @Override
    @Transactional(readOnly = true)
    public StudySessionResponse getStudySession(Long userId, Long setId, Integer newLimit) {
        getUserOrThrow(userId);
        requireOwnedSet(userId, setId, "Bạn không có quyền học bộ thẻ này");

        int limit = newLimit == null ? 20 : Math.max(0, Math.min(newLimit, 200));
        LocalDateTime now = LocalDateTime.now();
        Map<Long, FlashcardProgress> progressMap = progressRepository.findByUserIdAndSetId(userId, setId).stream()
                .collect(Collectors.toMap(p -> p.getId().getCardId(), p -> p));

        List<StudyCardResponse> learning = new ArrayList<>();
        List<StudyCardResponse> due = new ArrayList<>();
        List<StudyCardResponse> fresh = new ArrayList<>();

        for (Flashcard card : cardRepository.findByFlashcardSetSetId(setId)) {
            FlashcardProgress p = progressMap.get(card.getCardId());
            CardState state = p == null || p.getSrsState() == null ? CardState.NEW : p.getSrsState();
            boolean scheduled = p != null && p.getNextReviewAt() != null;

            // Thẻ có lịch ôn (kể cả dữ liệu cũ trước khi có SRS) mà chưa tới hạn thì bỏ qua.
            if (state != CardState.LEARNING && scheduled && p.getNextReviewAt().isAfter(now)) {
                continue;
            }

            StudyCardResponse item = toStudyCard(card, p, state);
            if (state == CardState.LEARNING) {
                learning.add(item);
            } else if (scheduled) {
                due.add(item);
            } else {
                fresh.add(item);
            }
        }

        due.sort(Comparator.comparing(c -> c.getCard().getNextReviewAt(),
                Comparator.nullsLast(Comparator.naturalOrder())));
        List<StudyCardResponse> newCards = fresh.size() > limit ? new ArrayList<>(fresh.subList(0, limit)) : fresh;

        List<StudyCardResponse> cards = new ArrayList<>(learning);
        cards.addAll(due);
        cards.addAll(newCards);

        return StudySessionResponse.builder()
                .setId(setId)
                .cards(cards)
                .newCount(newCards.size())
                .dueCount(due.size() + learning.size())
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public StudySessionResponse getDueSession(Long userId, Integer limit) {
        getUserOrThrow(userId);
        int max = limit == null ? 50 : Math.max(1, Math.min(limit, 200));
        // Giới hạn ngay ở truy vấn (kèm thẻ và bộ thẻ bằng JOIN FETCH) thay vì tải mọi thẻ đến hạn rồi cắt.
        List<StudyCardResponse> cards = progressRepository
                .findDueByUserId(userId, LocalDateTime.now(), PageRequest.of(0, max)).stream()
                .map(p -> toStudyCard(p.getFlashcard(), p,
                        p.getSrsState() == null ? CardState.NEW : p.getSrsState()))
                .collect(Collectors.toList());
        return StudySessionResponse.builder()
                .setId(null)
                .cards(cards)
                .newCount(0)
                .dueCount(cards.size())
                .build();
    }

    @Override
    @Transactional
    public ReviewResultResponse reviewCard(Long userId, ReviewCardRequest request) {
        User user = getUserOrThrow(userId);
        Flashcard card = requireOwnedCard(userId, request.getCardId(), "Bạn không có quyền học thẻ này");

        FlashcardProgress progress = progressRepository.findByIdUserIdAndIdCardId(userId, request.getCardId())
                .orElseGet(() -> FlashcardProgress.builder()
                        .id(new FlashcardProgressId(userId, request.getCardId()))
                        .user(user)
                        .flashcard(card)
                        .build());

        CardState state = progress.getSrsState() == null ? CardState.NEW : progress.getSrsState();
        double ease = progress.getEaseFactor() == null ? SrsScheduler.DEFAULT_EASE : progress.getEaseFactor();
        int interval = nz(progress.getIntervalDays());
        LocalDateTime now = LocalDateTime.now();

        CardSchedule next = SrsScheduler.apply(state, ease, interval, request.getRating(), now);

        progress.setSrsState(next.state());
        progress.setEaseFactor(next.easeFactor());
        progress.setIntervalDays(next.intervalDays());
        progress.setNextReviewAt(next.nextReviewAt());
        progress.setLastReviewedAt(now);
        progress.setReviewCount(nz(progress.getReviewCount()) + 1);
        if (next.lapsed()) {
            progress.setLapseCount(nz(progress.getLapseCount()) + 1);
        }
        // Giữ các chỉ số cũ để phần "đã thuộc" ở Thư viện thẻ vẫn chạy.
        int box = nz(progress.getBoxLevel());
        if (next.graduated()) {
            progress.setCorrectCount(nz(progress.getCorrectCount()) + 1);
            progress.setBoxLevel(Math.min(5, box + 1));
        } else if (request.getRating() == ReviewRating.AGAIN) {
            progress.setIncorrectCount(nz(progress.getIncorrectCount()) + 1);
            progress.setBoxLevel(Math.max(0, box - 1));
        }
        progressRepository.save(progress);

        return ReviewResultResponse.builder()
                .cardId(card.getCardId())
                .state(next.state().name())
                .graduated(next.graduated())
                .intervalDays(next.intervalDays())
                .nextReviewAt(next.nextReviewAt())
                .intervalLabels(labels(next.state(), next.easeFactor(), next.intervalDays()))
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public DueSummaryResponse getDueSummary(Long userId) {
        getUserOrThrow(userId);
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime nextDueAt = progressRepository.findNextDueAt(userId, now);
        long atNext = nextDueAt == null ? 0
                : progressRepository.countDueBetween(userId, nextDueAt, nextDueAt.plusHours(24));
        return DueSummaryResponse.builder()
                .dueCount(progressRepository.countDue(userId, now))
                .nextDueAt(nextDueAt)
                .dueAtNextCount(atNext)
                .build();
    }

    private StudyCardResponse toStudyCard(Flashcard card, FlashcardProgress p, CardState state) {
        double ease = p == null || p.getEaseFactor() == null ? SrsScheduler.DEFAULT_EASE : p.getEaseFactor();
        int interval = p == null ? 0 : nz(p.getIntervalDays());
        return StudyCardResponse.builder()
                .card(mapToCardResponse(card, p))
                .state(state.name())
                .intervalLabels(labels(state, ease, interval))
                .build();
    }

    private Map<String, String> labels(CardState state, double ease, int interval) {
        Map<String, String> out = new LinkedHashMap<>();
        SrsScheduler.previewLabels(state, ease, interval).forEach((k, v) -> out.put(k.name(), v));
        return out;
    }

    private static int nz(Integer v) {
        return v == null ? 0 : v;
    }

    @Override
    @Transactional
    public void resetSetProgress(Long userId, Long setId) {
        progressRepository.deleteByUserIdAndSetId(userId, setId);
    }

    // ------------------------------------------------------------------ lưu từ vựng từ video

    @Override
    @Transactional
    public FlashcardResponse saveVideoVocab(Long userId, SaveVideoVocabRequest request) {
        User user = getUserOrThrow(userId);

        FlashcardSet videoSet = setRepository.findByUserIdAndIsVideoSavedTrue(userId)
                .orElseGet(() -> {
                    FlashcardSet newSet = FlashcardSet.builder()
                            .user(user)
                            .title("Từ vựng đã lưu từ Video")
                            .description("Tự động lưu từ các video học tập trên bảng tin")
                            .isPublic(false)
                            .isVideoSaved(true)
                            .build();
                    return setRepository.save(newSet);
                });

        String term = request.getTerm().trim();
        // Lưu cùng một từ nhiều lần (bấm lại, hoặc ở nhiều video) thì trả về thẻ đã có thay vì tạo bản sao.
        Optional<Flashcard> existing = cardRepository
                .findFirstByFlashcardSetSetIdAndTermIgnoreCase(videoSet.getSetId(), term);
        if (existing.isPresent()) {
            return mapToCardResponse(existing.get(), null);
        }
        ensureRoomForCard(videoSet.getSetId());

        Flashcard card = Flashcard.builder()
                .flashcardSet(videoSet)
                .term(term)
                .reading(request.getReading())
                .sinoVietnamese(request.getSinoVietnamese())
                .meaning(request.getMeaning())
                .example(request.getExample())
                .build();

        Flashcard savedCard = cardRepository.save(card);
        return mapToCardResponse(savedCard, null);
    }

    // ------------------------------------------------------------------ kiểm tra quyền

    private static boolean isOwner(FlashcardSet set, Long userId) {
        return userId != null && set.getUser() != null && userId.equals(set.getUser().getId());
    }

    private FlashcardSet findSet(Long setId) {
        return setRepository.findById(setId)
                .orElseThrow(() -> new ResourceNotFoundException("FlashcardSet", "id", setId));
    }

    /** Chủ sở hữu hoặc bộ công khai; còn lại coi như không tồn tại để không lộ bộ thẻ riêng tư. */
    private FlashcardSet requireReadableSet(Long userId, Long setId) {
        FlashcardSet set = findSet(setId);
        if (!isOwner(set, userId) && !Boolean.TRUE.equals(set.getIsPublic())) {
            throw new ResourceNotFoundException("FlashcardSet", "id", setId);
        }
        return set;
    }

    /** Chỉ chủ sở hữu; bộ không có chủ cũng không ai sửa được (không "mở" khi thiếu dữ liệu). */
    private FlashcardSet requireOwnedSet(Long userId, Long setId, String forbiddenMessage) {
        FlashcardSet set = findSet(setId);
        if (!isOwner(set, userId)) {
            throw new AppException(403, forbiddenMessage);
        }
        return set;
    }

    private Flashcard findCard(Long cardId) {
        return cardRepository.findById(cardId)
                .orElseThrow(() -> new ResourceNotFoundException("Flashcard", "id", cardId));
    }

    private Flashcard requireReadableCard(Long userId, Long cardId) {
        Flashcard card = findCard(cardId);
        FlashcardSet set = card.getFlashcardSet();
        if (set == null || (!isOwner(set, userId) && !Boolean.TRUE.equals(set.getIsPublic()))) {
            throw new ResourceNotFoundException("Flashcard", "id", cardId);
        }
        return card;
    }

    private Flashcard requireOwnedCard(Long userId, Long cardId, String forbiddenMessage) {
        Flashcard card = findCard(cardId);
        if (card.getFlashcardSet() == null || !isOwner(card.getFlashcardSet(), userId)) {
            throw new AppException(403, forbiddenMessage);
        }
        return card;
    }

    private void ensureRoomForCard(Long setId) {
        if (cardRepository.countByFlashcardSetSetId(setId) >= MAX_CARDS_PER_SET) {
            throw new AppException(400, "Bộ thẻ đã đạt giới hạn " + MAX_CARDS_PER_SET + " thẻ");
        }
    }

    // ------------------------------------------------------------------ helper

    private User getUserOrThrow(Long userId) {
        if (userId == null) {
            throw new AppException(401, "Vui lòng đăng nhập để tiếp tục");
        }
        return userRepository.findById(userId)
                .orElseThrow(() -> new AppException(404, "Không tìm thấy tài khoản"));
    }

    private LocalDateTime calculateNextReview(LocalDateTime now, int boxLevel) {
        return switch (boxLevel) {
            case 1 -> now.plusDays(1);
            case 2 -> now.plusDays(3);
            case 3 -> now.plusDays(7);
            case 4 -> now.plusDays(14);
            case 5 -> now.plusDays(30);
            default -> now.plusHours(12);
        };
    }

    private FlashcardSetResponse mapToSetResponse(FlashcardSet set, long totalCards, long masteredCount,
                                                  List<FlashcardResponse> preview) {
        double progressPercentage = totalCards > 0 ? ((double) masteredCount / totalCards) * 100.0 : 0.0;
        User author = set.getUser();

        return FlashcardSetResponse.builder()
                .setId(set.getSetId())
                .title(set.getTitle())
                .description(set.getDescription())
                .isPublic(set.getIsPublic())
                .isVideoSaved(set.getIsVideoSaved())
                .authorId(author.getId())
                .authorName(author.getDisplayName() != null ? author.getDisplayName() : author.getUsername())
                .authorAvatarUrl(author.getAvatarUrl())
                .isAuthorPro(true)
                .totalCards((int) totalCards)
                .learnedCards((int) masteredCount)
                .progressPercentage(Math.round(progressPercentage * 10.0) / 10.0)
                .previewCards(preview)
                .createdAt(set.getCreatedAt())
                .updatedAt(set.getUpdatedAt())
                .build();
    }

    private FlashcardResponse mapToCardResponse(Flashcard card, FlashcardProgress progress) {
        return FlashcardResponse.builder()
                .cardId(card.getCardId())
                .setId(card.getFlashcardSet() != null ? card.getFlashcardSet().getSetId() : null)
                .term(card.getTerm())
                .reading(card.getReading())
                .sinoVietnamese(card.getSinoVietnamese())
                .meaning(card.getMeaning())
                .example(card.getExample())
                .audioUrl(card.getAudioUrl())
                .isStarred(progress != null && Boolean.TRUE.equals(progress.getIsStarred()))
                .boxLevel(progress != null ? progress.getBoxLevel() : 0)
                .correctCount(progress != null ? progress.getCorrectCount() : 0)
                .incorrectCount(progress != null ? progress.getIncorrectCount() : 0)
                .nextReviewAt(progress != null ? progress.getNextReviewAt() : null)
                .build();
    }
}
