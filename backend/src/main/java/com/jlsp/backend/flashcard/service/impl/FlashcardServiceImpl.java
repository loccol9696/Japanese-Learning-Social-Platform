package com.jlsp.backend.flashcard.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
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
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class FlashcardServiceImpl implements FlashcardService {

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

    @Override
    @Transactional
    public FlashcardSetResponse createSet(Long userId, CreateFlashcardSetRequest request) {
        User user = getUserOrThrow(userId);

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
        return mapToSetResponse(saved, userId, 5);
    }

    @Override
    @Transactional
    public FlashcardSetResponse updateSet(Long userId, Long setId, CreateFlashcardSetRequest request) {
        FlashcardSet set = setRepository.findById(setId)
                .orElseThrow(() -> new ResourceNotFoundException("FlashcardSet", "id", setId));
        if (set.getUser() != null && userId != null && !set.getUser().getId().equals(userId)) {
            throw new AppException(403, "You do not have permission to update this set");
        }
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
        return mapToSetResponse(saved, userId, 0);
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
        List<FlashcardSetResponse> content = page.getContent().stream()
                .map(set -> mapToSetResponse(set, userId, 0))
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
        FlashcardSet set = setRepository.findById(setId)
                .orElseThrow(() -> new ResourceNotFoundException("FlashcardSet", "id", setId));
        return mapToSetResponse(set, userId, 10);
    }

    @Override
    @Transactional
    public void deleteSet(Long userId, Long setId) {
        FlashcardSet set = setRepository.findById(setId)
                .orElseThrow(() -> new ResourceNotFoundException("FlashcardSet", "id", setId));
        if (set.getUser() != null && userId != null && !set.getUser().getId().equals(userId)) {
            throw new AppException(403, "You do not have permission to delete this set");
        }
        progressRepository.deleteByUserIdAndSetId(userId, setId);
        setRepository.delete(set);
    }

    @Override
    @Transactional(readOnly = true)
    public List<FlashcardResponse> getCardsInSet(Long userId, Long setId, Boolean starredOnly, Boolean shuffle) {
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
        FlashcardSet set = setRepository.findById(setId)
                .orElseThrow(() -> new ResourceNotFoundException("FlashcardSet", "id", setId));
        if (set.getUser() != null && userId != null && !set.getUser().getId().equals(userId)) {
            throw new AppException(403, "You do not have permission to add cards to this set");
        }

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
        Flashcard card = cardRepository.findById(cardId)
                .orElseThrow(() -> new ResourceNotFoundException("Flashcard", "id", cardId));
        if (card.getFlashcardSet() != null && card.getFlashcardSet().getUser() != null && userId != null
                && !card.getFlashcardSet().getUser().getId().equals(userId)) {
            throw new AppException(403, "You do not have permission to delete this card");
        }
        cardRepository.delete(card);
    }

    @Override
    @Transactional
    public FlashcardResponse updateCard(Long userId, Long cardId, CreateFlashcardRequest request) {
        Flashcard card = cardRepository.findById(cardId)
                .orElseThrow(() -> new ResourceNotFoundException("Flashcard", "id", cardId));
        if (card.getFlashcardSet() != null && card.getFlashcardSet().getUser() != null && userId != null
                && !card.getFlashcardSet().getUser().getId().equals(userId)) {
            throw new AppException(403, "You do not have permission to update this card");
        }
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
        Flashcard card = cardRepository.findById(cardId)
                .orElseThrow(() -> new ResourceNotFoundException("Flashcard", "id", cardId));

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
        Flashcard card = cardRepository.findById(request.getCardId())
                .orElseThrow(() -> new ResourceNotFoundException("Flashcard", "id", request.getCardId()));

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

    @Override
    @Transactional(readOnly = true)
    public List<QuizQuestionResponse> generateQuiz(Long userId, Long setId, Integer limit) {
        List<Flashcard> allCards = cardRepository.findByFlashcardSetSetId(setId);
        if (allCards.isEmpty()) {
            return Collections.emptyList();
        }

        List<Flashcard> quizPool = new ArrayList<>(allCards);
        Collections.shuffle(quizPool);
        int takeCount = (limit != null && limit > 0) ? Math.min(limit, quizPool.size()) : quizPool.size();
        List<Flashcard> selectedCards = quizPool.subList(0, takeCount);

        List<QuizQuestionResponse> questions = new ArrayList<>();
        Random random = new Random();

        int optionCount = Math.min(4, allCards.size());

        for (Flashcard card : selectedCards) {
            String correctAnswer = (card.getReading() != null && !card.getReading().isBlank())
                    ? card.getReading()
                    : card.getTerm();

            Set<String> optionSet = new LinkedHashSet<>();
            optionSet.add(correctAnswer);

            // Tìm các đáp án nhiễu từ các thẻ khác
            if (optionCount > 1) {
                List<Flashcard> otherCards = allCards.stream()
                        .filter(c -> !c.getCardId().equals(card.getCardId()))
                        .collect(Collectors.toList());
                Collections.shuffle(otherCards);

                for (Flashcard other : otherCards) {
                    String distractor = (other.getReading() != null && !other.getReading().isBlank())
                            ? other.getReading()
                            : other.getTerm();
                    if (!distractor.equalsIgnoreCase(correctAnswer)) {
                        optionSet.add(distractor);
                    }
                    if (optionSet.size() >= optionCount) {
                        break;
                    }
                }
            }

            List<String> options = new ArrayList<>(optionSet);
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

    @Override
    @Transactional(readOnly = true)
    public MatchingGameResponse generateMatchingGame(Long setId, Integer pairCount) {
        List<Flashcard> cards = cardRepository.findByFlashcardSetSetId(setId);
        Collections.shuffle(cards);

        int count = (pairCount != null && pairCount > 0) ? Math.min(pairCount, cards.size())
                : Math.min(5, cards.size());
        List<Flashcard> selected = cards.subList(0, count);

        List<MatchingGameResponse.MatchingTile> tiles = new ArrayList<>();
        int index = 0;
        for (Flashcard card : selected) {
            tiles.add(MatchingGameResponse.MatchingTile.builder()
                    .tileId("term_" + card.getCardId() + "_" + (++index))
                    .cardId(card.getCardId())
                    .text((card.getReading() != null && !card.getReading().isBlank()) ? card.getReading()
                            : card.getTerm())
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

    @Override
    @Transactional(readOnly = true)
    public StudySessionResponse getStudySession(Long userId, Long setId, Integer newLimit) {
        getUserOrThrow(userId);
        FlashcardSet set = setRepository.findById(setId)
                .orElseThrow(() -> new ResourceNotFoundException("FlashcardSet", "id", setId));
        if (set.getUser() != null && !set.getUser().getId().equals(userId)) {
            throw new AppException(403, "Bạn không có quyền học bộ thẻ này");
        }

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
    @Transactional
    public ReviewResultResponse reviewCard(Long userId, ReviewCardRequest request) {
        User user = getUserOrThrow(userId);
        Flashcard card = cardRepository.findById(request.getCardId())
                .orElseThrow(() -> new ResourceNotFoundException("Flashcard", "id", request.getCardId()));
        User owner = card.getFlashcardSet().getUser();
        if (owner != null && !owner.getId().equals(userId)) {
            throw new AppException(403, "Bạn không có quyền học thẻ này");
        }

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

        Flashcard card = Flashcard.builder()
                .flashcardSet(videoSet)
                .term(request.getTerm())
                .reading(request.getReading())
                .sinoVietnamese(request.getSinoVietnamese())
                .meaning(request.getMeaning())
                .example(request.getExample())
                .build();

        Flashcard savedCard = cardRepository.save(card);
        return mapToCardResponse(savedCard, null);
    }

    // Helpers
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

    private FlashcardSetResponse mapToSetResponse(FlashcardSet set, Long userId, int previewLimit) {
        List<Flashcard> cards = set.getFlashcards() != null ? set.getFlashcards() : Collections.emptyList();
        int totalCards = cards.size();

        long masteredCount = progressRepository.countMasteredCards(userId, set.getSetId());
        double progressPercentage = totalCards > 0 ? ((double) masteredCount / totalCards) * 100.0 : 0.0;

        List<FlashcardResponse> preview = previewLimit > 0
                ? cards.stream().limit(previewLimit).map(c -> mapToCardResponse(c, null)).collect(Collectors.toList())
                : Collections.emptyList();

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
                .totalCards(totalCards)
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
