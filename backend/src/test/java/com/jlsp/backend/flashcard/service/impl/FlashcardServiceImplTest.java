package com.jlsp.backend.flashcard.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.repository.IdCount;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.flashcard.dto.request.CreateFlashcardRequest;
import com.jlsp.backend.flashcard.dto.request.CreateFlashcardSetRequest;
import com.jlsp.backend.flashcard.dto.request.ReviewCardRequest;
import com.jlsp.backend.flashcard.dto.request.SaveVideoVocabRequest;
import com.jlsp.backend.flashcard.dto.request.SubmitCardAnswerRequest;
import com.jlsp.backend.flashcard.dto.response.FlashcardResponse;
import com.jlsp.backend.flashcard.dto.response.FlashcardSetResponse;
import com.jlsp.backend.flashcard.dto.response.MatchingGameResponse;
import com.jlsp.backend.flashcard.dto.response.QuizQuestionResponse;
import com.jlsp.backend.flashcard.entity.Flashcard;
import com.jlsp.backend.flashcard.entity.FlashcardProgress;
import com.jlsp.backend.flashcard.entity.FlashcardProgressId;
import com.jlsp.backend.flashcard.entity.FlashcardSet;
import com.jlsp.backend.flashcard.repository.FlashcardProgressRepository;
import com.jlsp.backend.flashcard.repository.FlashcardRepository;
import com.jlsp.backend.flashcard.repository.FlashcardSetRepository;
import com.jlsp.backend.flashcard.srs.ReviewRating;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class FlashcardServiceImplTest {

    private static final long OWNER_ID = 1L;
    private static final long STRANGER_ID = 2L;
    private static final long SET_ID = 10L;
    private static final long CARD_ID = 100L;

    private FlashcardSetRepository setRepository;
    private FlashcardRepository cardRepository;
    private FlashcardProgressRepository progressRepository;
    private UserRepository userRepository;
    private FlashcardServiceImpl service;
    private com.jlsp.backend.streak.service.StreakService streakService;

    private User owner;
    private User stranger;
    private FlashcardSet privateSet;

    @BeforeEach
    void setUp() {
        setRepository = mock(FlashcardSetRepository.class);
        cardRepository = mock(FlashcardRepository.class);
        progressRepository = mock(FlashcardProgressRepository.class);
        userRepository = mock(UserRepository.class);
        streakService = org.mockito.Mockito.mock(com.jlsp.backend.streak.service.StreakService.class);
        service = new FlashcardServiceImpl(setRepository, cardRepository, progressRepository, userRepository,
                streakService);

        owner = User.builder().id(OWNER_ID).username("owner").displayName("Owner").build();
        stranger = User.builder().id(STRANGER_ID).username("stranger").build();
        privateSet = FlashcardSet.builder().setId(SET_ID).user(owner).title("Bộ riêng").isPublic(false).build();

        when(userRepository.findById(OWNER_ID)).thenReturn(Optional.of(owner));
        when(userRepository.findById(STRANGER_ID)).thenReturn(Optional.of(stranger));
        when(setRepository.findById(SET_ID)).thenReturn(Optional.of(privateSet));
        when(setRepository.save(any(FlashcardSet.class))).thenAnswer(inv -> inv.getArgument(0));
        when(cardRepository.save(any(Flashcard.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    private Flashcard card(long id, String term, String reading, FlashcardSet set) {
        return Flashcard.builder().cardId(id).flashcardSet(set).term(term).reading(reading)
                .meaning("nghĩa " + id).build();
    }

    private List<Flashcard> cards(int count) {
        return IntStream.rangeClosed(1, count)
                .mapToObj(i -> card(i, "term" + i, "reading" + i, privateSet))
                .toList();
    }

    private static IdCount idCount(long id, long total) {
        return new IdCount() {
            @Override
            public Long getId() {
                return id;
            }

            @Override
            public Long getTotal() {
                return total;
            }
        };
    }

    // ================================================================== phân quyền: đọc

    @Test
    void strangerCannotSeeAPrivateSetNorItsCards() {
        assertThatThrownBy(() -> service.getSetById(STRANGER_ID, SET_ID))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> service.getCardsInSet(STRANGER_ID, SET_ID, false, false))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> service.generateQuiz(STRANGER_ID, SET_ID, 10))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> service.generateMatchingGame(STRANGER_ID, SET_ID, 5))
                .isInstanceOf(ResourceNotFoundException.class);

        // Không được chạm tới thẻ của bộ riêng tư.
        verify(cardRepository, never()).findByFlashcardSetSetId(anyLong());
        verify(cardRepository, never()).findByFlashcardSetSetId(anyLong(), any(Pageable.class));
    }

    @Test
    void strangerCanReadAPublicSet() {
        privateSet.setIsPublic(true);
        when(cardRepository.countByFlashcardSetSetId(SET_ID)).thenReturn(3L);
        when(cardRepository.findByFlashcardSetSetId(eq(SET_ID), any(Pageable.class)))
                .thenReturn(new PageImpl<>(cards(3)));

        FlashcardSetResponse response = service.getSetById(STRANGER_ID, SET_ID);

        assertThat(response.getTotalCards()).isEqualTo(3);
        assertThat(response.getPreviewCards()).hasSize(3);
    }

    @Test
    void ownerCanReadTheirPrivateSet() {
        when(cardRepository.countByFlashcardSetSetId(SET_ID)).thenReturn(0L);
        when(cardRepository.findByFlashcardSetSetId(eq(SET_ID), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of()));

        assertThat(service.getSetById(OWNER_ID, SET_ID).getTitle()).isEqualTo("Bộ riêng");
    }

    @Test
    void strangerCannotRecordProgressOnAPrivateCard() {
        Flashcard secret = card(CARD_ID, "bí mật", null, privateSet);
        when(cardRepository.findById(CARD_ID)).thenReturn(Optional.of(secret));
        SubmitCardAnswerRequest answer = new SubmitCardAnswerRequest();
        answer.setCardId(CARD_ID);
        answer.setIsCorrect(true);

        assertThatThrownBy(() -> service.submitCardAnswer(STRANGER_ID, answer))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> service.updateCardStar(STRANGER_ID, CARD_ID, true))
                .isInstanceOf(ResourceNotFoundException.class);

        verify(progressRepository, never()).save(any());
    }

    // ================================================================== phân quyền: sửa / học theo lịch

    @Test
    void onlyTheOwnerMayModifyASet() {
        privateSet.setIsPublic(true); // công khai cũng không cho người khác sửa
        Flashcard existing = card(CARD_ID, "từ", null, privateSet);
        when(cardRepository.findById(CARD_ID)).thenReturn(Optional.of(existing));
        CreateFlashcardSetRequest setRequest = new CreateFlashcardSetRequest();
        setRequest.setTitle("Đổi tên");
        CreateFlashcardRequest cardRequest = new CreateFlashcardRequest();
        cardRequest.setTerm("mới");
        cardRequest.setMeaning("nghĩa");

        for (var action : List.<Runnable>of(
                () -> service.updateSet(STRANGER_ID, SET_ID, setRequest),
                () -> service.deleteSet(STRANGER_ID, SET_ID),
                () -> service.addCardToSet(STRANGER_ID, SET_ID, cardRequest),
                () -> service.updateCard(STRANGER_ID, CARD_ID, cardRequest),
                () -> service.deleteCard(STRANGER_ID, CARD_ID))) {
            assertThatThrownBy(action::run)
                    .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(403));
        }

        verify(setRepository, never()).save(any());
        verify(setRepository, never()).delete(any());
        verify(cardRepository, never()).save(any());
        verify(cardRepository, never()).delete(any());
    }

    @Test
    void aSetWithoutAnOwnerCannotBeModifiedByAnyone() {
        FlashcardSet orphan = FlashcardSet.builder().setId(77L).user(null).title("Mồ côi").build();
        when(setRepository.findById(77L)).thenReturn(Optional.of(orphan));

        assertThatThrownBy(() -> service.deleteSet(OWNER_ID, 77L))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(403));
        verify(setRepository, never()).delete(any());
    }

    @Test
    void ownerCanModifyTheirSet() {
        CreateFlashcardSetRequest request = new CreateFlashcardSetRequest();
        request.setTitle("  Tên mới  ");
        when(cardRepository.countByFlashcardSetSetId(SET_ID)).thenReturn(4L);

        FlashcardSetResponse response = service.updateSet(OWNER_ID, SET_ID, request);

        assertThat(response.getTitle()).isEqualTo("Tên mới");
        assertThat(response.getTotalCards()).isEqualTo(4);
    }

    @Test
    void srsStudyAndReviewAreOwnerOnlyEvenForPublicSets() {
        privateSet.setIsPublic(true);
        Flashcard publicCard = card(CARD_ID, "từ", null, privateSet);
        when(cardRepository.findById(CARD_ID)).thenReturn(Optional.of(publicCard));
        ReviewCardRequest review = new ReviewCardRequest();
        review.setCardId(CARD_ID);
        review.setRating(ReviewRating.EASY);

        assertThatThrownBy(() -> service.getStudySession(STRANGER_ID, SET_ID, 20))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(403));
        assertThatThrownBy(() -> service.reviewCard(STRANGER_ID, review))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(403));
        verify(progressRepository, never()).save(any());
    }

    // ================================================================== streak

    @Test
    void bothReviewEndpointsRecordStreakActivityForTheReviewer() {
        when(cardRepository.findById(CARD_ID)).thenReturn(Optional.of(card(CARD_ID, "từ", null, privateSet)));
        SubmitCardAnswerRequest answer = new SubmitCardAnswerRequest();
        answer.setCardId(CARD_ID);
        answer.setIsCorrect(true);
        ReviewCardRequest review = new ReviewCardRequest();
        review.setCardId(CARD_ID);
        review.setRating(ReviewRating.GOOD);

        service.submitCardAnswer(OWNER_ID, answer);
        service.reviewCard(OWNER_ID, review);

        verify(streakService, times(2)).recordActivity(OWNER_ID);
    }

    @Test
    void rejectedReviewDoesNotCountTowardsTheStreak() {
        when(cardRepository.findById(CARD_ID)).thenReturn(Optional.of(card(CARD_ID, "từ", null, privateSet)));
        ReviewCardRequest review = new ReviewCardRequest();
        review.setCardId(CARD_ID);
        review.setRating(ReviewRating.GOOD);

        assertThatThrownBy(() -> service.reviewCard(STRANGER_ID, review)).isInstanceOf(AppException.class);

        verify(streakService, never()).recordActivity(any());
    }

    // ================================================================== danh sách bộ thẻ: đếm theo lô

    @Test
    void listingSetsCountsCardsAndMasteredInTwoBatchedQueriesNotPerSet() {
        FlashcardSet second = FlashcardSet.builder().setId(11L).user(owner).title("Bộ 2").build();
        Pageable pageable = PageRequest.of(0, 10);
        when(setRepository.findUserSets(OWNER_ID, pageable))
                .thenReturn(new PageImpl<>(List.of(privateSet, second), pageable, 2));
        when(cardRepository.countBySetIds(anyCollection())).thenReturn(List.of(idCount(SET_ID, 20), idCount(11L, 4)));
        when(progressRepository.countMasteredBySetIds(eq(OWNER_ID), anyCollection()))
                .thenReturn(List.of(idCount(SET_ID, 5)));

        PageResponse<FlashcardSetResponse> page = service.getSets(OWNER_ID, null, pageable);

        assertThat(page.getContent()).extracting(FlashcardSetResponse::getTotalCards).containsExactly(20, 4);
        assertThat(page.getContent()).extracting(FlashcardSetResponse::getLearnedCards).containsExactly(5, 0);
        assertThat(page.getContent().get(0).getProgressPercentage()).isEqualTo(25.0);
        assertThat(page.getContent().get(1).getProgressPercentage()).isEqualTo(0.0);

        verify(cardRepository, times(1)).countBySetIds(anyCollection());
        verify(progressRepository, times(1)).countMasteredBySetIds(eq(OWNER_ID), anyCollection());
        // Không còn đếm từng bộ, cũng không tải thẻ của từng bộ chỉ để đếm.
        verify(progressRepository, never()).countMasteredCards(anyLong(), anyLong());
        verify(cardRepository, never()).findByFlashcardSetSetId(anyLong());
        verify(cardRepository, never()).countByFlashcardSetSetId(anyLong());
    }

    @Test
    @SuppressWarnings("unchecked")
    void listingSetsAsksForTheIdsOfThePage() {
        Pageable pageable = PageRequest.of(0, 10);
        when(setRepository.findUserSets(OWNER_ID, pageable))
                .thenReturn(new PageImpl<>(List.of(privateSet), pageable, 1));
        when(cardRepository.countBySetIds(anyCollection())).thenReturn(List.of());
        when(progressRepository.countMasteredBySetIds(eq(OWNER_ID), anyCollection())).thenReturn(List.of());

        service.getSets(OWNER_ID, null, pageable);

        ArgumentCaptor<Collection<Long>> ids = ArgumentCaptor.forClass(Collection.class);
        verify(cardRepository).countBySetIds(ids.capture());
        assertThat(ids.getValue()).containsExactly(SET_ID);
    }

    @Test
    void anEmptyPageDoesNotRunAnyCountQuery() {
        Pageable pageable = PageRequest.of(0, 10);
        when(setRepository.findUserSets(OWNER_ID, pageable)).thenReturn(new PageImpl<>(List.of(), pageable, 0));

        assertThat(service.getSets(OWNER_ID, null, pageable).getContent()).isEmpty();

        verify(cardRepository, never()).countBySetIds(anyCollection());
        verify(progressRepository, never()).countMasteredBySetIds(anyLong(), anyCollection());
    }

    @Test
    void openingASetLoadsOnlyTenPreviewCardsInsteadOfAllOfThem() {
        when(cardRepository.countByFlashcardSetSetId(SET_ID)).thenReturn(1500L);
        when(cardRepository.findByFlashcardSetSetId(eq(SET_ID), any(Pageable.class)))
                .thenReturn(new PageImpl<>(cards(10)));

        FlashcardSetResponse response = service.getSetById(OWNER_ID, SET_ID);

        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(cardRepository).findByFlashcardSetSetId(eq(SET_ID), pageable.capture());
        assertThat(pageable.getValue().getPageSize()).isEqualTo(10);
        assertThat(response.getTotalCards()).isEqualTo(1500);
        verify(cardRepository, never()).findByFlashcardSetSetId(anyLong());
    }

    // ================================================================== phiên ôn tập đến hạn

    @Test
    void dueSessionIsLimitedInTheQueryNotAfterLoadingEverything() {
        when(progressRepository.findDueByUserId(eq(OWNER_ID), any(LocalDateTime.class), any(Pageable.class)))
                .thenReturn(List.of());

        service.getDueSession(OWNER_ID, null);
        service.getDueSession(OWNER_ID, 5000);
        service.getDueSession(OWNER_ID, 0);

        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(progressRepository, times(3)).findDueByUserId(eq(OWNER_ID), any(LocalDateTime.class), pageable.capture());
        assertThat(pageable.getAllValues()).extracting(Pageable::getPageSize).containsExactly(50, 200, 1);
    }

    @Test
    void dueSessionMapsTheLoadedProgress() {
        Flashcard due = card(CARD_ID, "期限", "きげん", privateSet);
        FlashcardProgress progress = FlashcardProgress.builder()
                .id(new FlashcardProgressId(OWNER_ID, CARD_ID)).user(owner).flashcard(due)
                .nextReviewAt(LocalDateTime.now().minusHours(1)).build();
        when(progressRepository.findDueByUserId(eq(OWNER_ID), any(LocalDateTime.class), any(Pageable.class)))
                .thenReturn(List.of(progress));

        var session = service.getDueSession(OWNER_ID, 50);

        assertThat(session.getCards()).hasSize(1);
        assertThat(session.getDueCount()).isEqualTo(1);
        assertThat(session.getCards().get(0).getCard().getTerm()).isEqualTo("期限");
    }

    // ================================================================== trắc nghiệm và ghép thẻ

    @Test
    void quizHasFourUniqueOptionsIncludingTheCorrectAnswer() {
        when(cardRepository.findByFlashcardSetSetId(SET_ID)).thenReturn(cards(8));

        List<QuizQuestionResponse> quiz = service.generateQuiz(OWNER_ID, SET_ID, null);

        assertThat(quiz).hasSize(8);
        for (QuizQuestionResponse q : quiz) {
            assertThat(q.getOptions()).hasSize(4).doesNotHaveDuplicates().contains(q.getCorrectAnswer());
        }
        assertThat(quiz).extracting(QuizQuestionResponse::getCardId).doesNotHaveDuplicates();
    }

    @Test
    void quizOfATinySetHasFewerOptions() {
        when(cardRepository.findByFlashcardSetSetId(SET_ID)).thenReturn(cards(2));

        List<QuizQuestionResponse> quiz = service.generateQuiz(OWNER_ID, SET_ID, 10);

        assertThat(quiz).hasSize(2);
        assertThat(quiz).allSatisfy(q -> assertThat(q.getOptions()).hasSize(2));
    }

    @Test
    void quizSizeIsCappedEvenForHugeSetsAndLimits() {
        when(cardRepository.findByFlashcardSetSetId(SET_ID)).thenReturn(cards(300));

        assertThat(service.generateQuiz(OWNER_ID, SET_ID, 1000)).hasSize(FlashcardServiceImpl.MAX_QUIZ_QUESTIONS);
        assertThat(service.generateQuiz(OWNER_ID, SET_ID, null)).hasSize(FlashcardServiceImpl.MAX_QUIZ_QUESTIONS);
        assertThat(service.generateQuiz(OWNER_ID, SET_ID, 20)).hasSize(20);
    }

    @Test
    void quizDoesNotLoopForeverWhenAllCardsLookTheSame() {
        List<Flashcard> same = IntStream.rangeClosed(1, 5)
                .mapToObj(i -> card(i, "同じ", "おなじ", privateSet)).toList();
        when(cardRepository.findByFlashcardSetSetId(SET_ID)).thenReturn(same);

        List<QuizQuestionResponse> quiz = service.generateQuiz(OWNER_ID, SET_ID, 5);

        assertThat(quiz).hasSize(5);
        assertThat(quiz).allSatisfy(q -> assertThat(q.getOptions()).containsExactly("おなじ"));
    }

    @Test
    void emptySetGivesAnEmptyQuiz() {
        when(cardRepository.findByFlashcardSetSetId(SET_ID)).thenReturn(List.of());

        assertThat(service.generateQuiz(OWNER_ID, SET_ID, 10)).isEmpty();
    }

    @Test
    void matchingGameIsCappedAndHasTwoTilesPerPair() {
        when(cardRepository.findByFlashcardSetSetId(SET_ID)).thenReturn(cards(50));

        MatchingGameResponse game = service.generateMatchingGame(OWNER_ID, SET_ID, 100);

        assertThat(game.getTotalPairs()).isEqualTo(FlashcardServiceImpl.MAX_MATCHING_PAIRS);
        assertThat(game.getTiles()).hasSize(FlashcardServiceImpl.MAX_MATCHING_PAIRS * 2);
        assertThat(service.generateMatchingGame(OWNER_ID, SET_ID, null).getTotalPairs()).isEqualTo(5);
    }

    // ================================================================== giới hạn và chống trùng

    @Test
    void cannotAddCardsBeyondTheSetLimit() {
        when(cardRepository.countByFlashcardSetSetId(SET_ID)).thenReturn((long) FlashcardServiceImpl.MAX_CARDS_PER_SET);
        CreateFlashcardRequest request = new CreateFlashcardRequest();
        request.setTerm("từ");
        request.setMeaning("nghĩa");

        assertThatThrownBy(() -> service.addCardToSet(OWNER_ID, SET_ID, request))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        verify(cardRepository, never()).save(any());
    }

    @Test
    void cannotCreateASetWithTooManyCards() {
        CreateFlashcardSetRequest request = new CreateFlashcardSetRequest();
        request.setTitle("Quá lớn");
        List<CreateFlashcardRequest> tooMany = new ArrayList<>();
        for (int i = 0; i <= FlashcardServiceImpl.MAX_CARDS_PER_SET; i++) {
            CreateFlashcardRequest c = new CreateFlashcardRequest();
            c.setTerm("t" + i);
            c.setMeaning("m");
            tooMany.add(c);
        }
        request.setCards(tooMany);

        assertThatThrownBy(() -> service.createSet(OWNER_ID, request))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        verify(setRepository, never()).save(any());
    }

    @Test
    void savingTheSameVideoWordAgainReturnsTheExistingCardWithoutDuplicating() {
        FlashcardSet videoSet = FlashcardSet.builder().setId(55L).user(owner).isVideoSaved(true).build();
        when(setRepository.findByUserIdAndIsVideoSavedTrue(OWNER_ID)).thenReturn(Optional.of(videoSet));
        Flashcard existing = card(CARD_ID, "勉強", "べんきょう", videoSet);
        when(cardRepository.findFirstByFlashcardSetSetIdAndTermIgnoreCase(55L, "勉強"))
                .thenReturn(Optional.of(existing));
        SaveVideoVocabRequest request = new SaveVideoVocabRequest();
        request.setTerm("  勉強 ");
        request.setMeaning("học");

        FlashcardResponse response = service.saveVideoVocab(OWNER_ID, request);

        assertThat(response.getCardId()).isEqualTo(CARD_ID);
        verify(cardRepository, never()).save(any());
    }

    @Test
    void savingANewVideoWordCreatesTheCardTrimmed() {
        FlashcardSet videoSet = FlashcardSet.builder().setId(55L).user(owner).isVideoSaved(true).build();
        when(setRepository.findByUserIdAndIsVideoSavedTrue(OWNER_ID)).thenReturn(Optional.of(videoSet));
        when(cardRepository.findFirstByFlashcardSetSetIdAndTermIgnoreCase(anyLong(), any()))
                .thenReturn(Optional.empty());
        SaveVideoVocabRequest request = new SaveVideoVocabRequest();
        request.setTerm("  新しい ");
        request.setMeaning("mới");

        FlashcardResponse response = service.saveVideoVocab(OWNER_ID, request);

        assertThat(response.getTerm()).isEqualTo("新しい");
        verify(cardRepository).save(any(Flashcard.class));
    }

    // ================================================================== sắp xếp thủ công

    private FlashcardSet setOf(long id) {
        return FlashcardSet.builder().setId(id).user(owner).title("Bộ " + id).build();
    }

    @Test
    void reorderingSetsNumbersThemInTheRequestedOrder() {
        FlashcardSet a = setOf(1), b = setOf(2), c = setOf(3);
        when(setRepository.findAllOrderedByUserId(OWNER_ID)).thenReturn(List.of(a, b, c));

        service.reorderSets(OWNER_ID, List.of(3L, 1L, 2L));

        assertThat(c.getSortOrder()).isEqualTo(0);
        assertThat(a.getSortOrder()).isEqualTo(1);
        assertThat(b.getSortOrder()).isEqualTo(2);
    }

    @Test
    void reorderingOnlyTheVisiblePartKeepsTheOtherSetsInTheirSlots() {
        FlashcardSet a = setOf(1), b = setOf(2), c = setOf(3), d = setOf(4);
        when(setRepository.findAllOrderedByUserId(OWNER_ID)).thenReturn(List.of(a, b, c, d));

        // Máy mới tải 2 bộ đầu và đảo chúng; bộ 3, 4 chưa tải phải giữ nguyên chỗ.
        service.reorderSets(OWNER_ID, List.of(2L, 1L));

        assertThat(b.getSortOrder()).isEqualTo(0);
        assertThat(a.getSortOrder()).isEqualTo(1);
        assertThat(c.getSortOrder()).isEqualTo(2);
        assertThat(d.getSortOrder()).isEqualTo(3);
    }

    @Test
    void reorderIgnoresUnknownAndDuplicateIds() {
        FlashcardSet a = setOf(1), b = setOf(2);
        when(setRepository.findAllOrderedByUserId(OWNER_ID)).thenReturn(List.of(a, b));

        service.reorderSets(OWNER_ID, List.of(2L, 999L, 2L, 1L));

        assertThat(b.getSortOrder()).isEqualTo(0);
        assertThat(a.getSortOrder()).isEqualTo(1);
    }

    @Test
    void reorderingCardsNumbersThemAndNewCardsStayLast() {
        Flashcard one = card(1, "t1", "r", privateSet), two = card(2, "t2", "r", privateSet),
                three = card(3, "t3", "r", privateSet);
        when(cardRepository.findOrderedBySetId(SET_ID)).thenReturn(List.of(one, two, three));

        service.reorderCards(OWNER_ID, SET_ID, List.of(3L, 2L, 1L));

        assertThat(three.getSortOrder()).isEqualTo(0);
        assertThat(two.getSortOrder()).isEqualTo(1);
        assertThat(one.getSortOrder()).isEqualTo(2);
    }

    @Test
    void onlyTheOwnerMayReorderCards() {
        assertThatThrownBy(() -> service.reorderCards(STRANGER_ID, SET_ID, List.of(1L)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(403));
        verify(cardRepository, never()).findOrderedBySetId(anyLong());
    }

    @Test
    void cardsAreListedInTheirSavedOrder() {
        Flashcard one = card(1, "t1", "r", privateSet), two = card(2, "t2", "r", privateSet);
        when(cardRepository.findOrderedBySetId(SET_ID)).thenReturn(List.of(two, one));
        when(progressRepository.findByUserIdAndSetId(OWNER_ID, SET_ID)).thenReturn(List.of());

        List<FlashcardResponse> result = service.getCardsInSet(OWNER_ID, SET_ID, false, false);

        assertThat(result).extracting(FlashcardResponse::getCardId).containsExactly(2L, 1L);
    }
}
