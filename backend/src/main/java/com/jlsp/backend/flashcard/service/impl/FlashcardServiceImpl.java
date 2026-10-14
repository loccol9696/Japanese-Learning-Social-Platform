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
@RequiredArgsConstructor
public class FlashcardServiceImpl implements FlashcardService {

    private final FlashcardSetRepository setRepository;
    private final FlashcardRepository cardRepository;
    private final FlashcardProgressRepository progressRepository;
    private final UserRepository userRepository;

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
    @Transactional(readOnly = true)
    public PageResponse<FlashcardSetResponse> getSets(Long userId, String keyword, Pageable pageable) {
        Page<FlashcardSet> page;
        if (keyword != null && !keyword.trim().isEmpty()) {
            page = setRepository.searchUserAndPublicSets(userId, keyword.trim(), pageable);
        } else {
            page = setRepository.findUserAndPublicSets(userId, pageable);
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
        if (!set.getUser().getId().equals(userId)) {
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
        if (!set.getUser().getId().equals(userId)) {
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
        if (!card.getFlashcardSet().getUser().getId().equals(userId)) {
            throw new AppException(403, "You do not have permission to delete this card");
        }
        cardRepository.delete(card);
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

        for (Flashcard card : selectedCards) {
            String correctAnswer = (card.getReading() != null && !card.getReading().isBlank()) 
                    ? card.getReading() 
                    : card.getTerm();

            Set<String> optionSet = new LinkedHashSet<>();
            optionSet.add(correctAnswer);

            // Tìm 3 đáp án nhiễu từ các thẻ khác
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
                if (optionSet.size() == 4) break;
            }

            // Fallback nếu trong bộ có ít thẻ
            while (optionSet.size() < 4) {
                optionSet.add(correctAnswer + " (" + (optionSet.size() + 1) + ")");
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

        int count = (pairCount != null && pairCount > 0) ? Math.min(pairCount, cards.size()) : Math.min(5, cards.size());
        List<Flashcard> selected = cards.subList(0, count);

        List<MatchingGameResponse.MatchingTile> tiles = new ArrayList<>();
        int index = 0;
        for (Flashcard card : selected) {
            tiles.add(MatchingGameResponse.MatchingTile.builder()
                    .tileId("term_" + card.getCardId() + "_" + (++index))
                    .cardId(card.getCardId())
                    .text((card.getReading() != null && !card.getReading().isBlank()) ? card.getReading() : card.getTerm())
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
        if (userId != null) {
            java.util.Optional<User> found = userRepository.findById(userId);
            if (found.isPresent()) {
                return found.get();
            }
        }
        return userRepository.findAll().stream().findFirst()
                .orElseGet(() -> userRepository.save(User.builder()
                        .username("Loccol9696")
                        .email("loccol9696@example.com")
                        .passwordHash("password")
                        .displayName("Loccol9696")
                        .role(com.jlsp.backend.user.entity.UserRole.USER)
                        .isActive(true)
                        .build()));
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
