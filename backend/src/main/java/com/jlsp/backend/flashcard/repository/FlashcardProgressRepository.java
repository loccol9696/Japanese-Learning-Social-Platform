package com.jlsp.backend.flashcard.repository;

import com.jlsp.backend.flashcard.entity.FlashcardProgress;
import com.jlsp.backend.flashcard.entity.FlashcardProgressId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface FlashcardProgressRepository extends JpaRepository<FlashcardProgress, FlashcardProgressId> {

    Optional<FlashcardProgress> findByIdUserIdAndIdCardId(Long userId, Long cardId);

    @Query("SELECT p FROM FlashcardProgress p WHERE p.user.id = :userId AND p.flashcard.flashcardSet.setId = :setId")
    List<FlashcardProgress> findByUserIdAndSetId(@Param("userId") Long userId, @Param("setId") Long setId);

    @Query("SELECT p FROM FlashcardProgress p WHERE p.user.id = :userId AND p.flashcard.flashcardSet.setId = :setId AND p.isStarred = true")
    List<FlashcardProgress> findStarredByUserIdAndSetId(@Param("userId") Long userId, @Param("setId") Long setId);

    @Query("SELECT COUNT(p) FROM FlashcardProgress p WHERE p.user.id = :userId AND p.flashcard.flashcardSet.setId = :setId AND p.srsState = com.jlsp.backend.flashcard.srs.CardState.REVIEW AND p.intervalDays >= 21")
    long countMasteredCards(@Param("userId") Long userId, @Param("setId") Long setId);

    @Modifying
    @Query("DELETE FROM FlashcardProgress p WHERE p.user.id = :userId AND p.flashcard.flashcardSet.setId = :setId")
    void deleteByUserIdAndSetId(@Param("userId") Long userId, @Param("setId") Long setId);

    /** Đặt lại tiến độ học nhưng giữ dấu sao: xóa các dòng không gắn sao. */
    @Modifying
    @Query("DELETE FROM FlashcardProgress p WHERE p.user.id = :userId AND p.flashcard.flashcardSet.setId = :setId " +
           "AND p.isStarred = false")
    void deleteUnstarredByUserIdAndSetId(@Param("userId") Long userId, @Param("setId") Long setId);

    /** Đặt lại tiến độ học của các thẻ gắn sao về như chưa học, vẫn giữ dấu sao. */
    @Modifying
    @Query("UPDATE FlashcardProgress p SET p.boxLevel = 0, p.correctCount = 0, p.incorrectCount = 0, " +
           "p.nextReviewAt = NULL, p.lastReviewedAt = NULL, p.easeFactor = 2.5, p.intervalDays = 0, " +
           "p.reviewCount = 0, p.lapseCount = 0, p.srsState = com.jlsp.backend.flashcard.srs.CardState.NEW " +
           "WHERE p.user.id = :userId AND p.flashcard.flashcardSet.setId = :setId AND p.isStarred = true")
    void resetStarredByUserIdAndSetId(@Param("userId") Long userId, @Param("setId") Long setId);

    /** Xóa tiến độ của MỌI người dùng trên một bộ thẻ (khóa ngoại card_id không tự xóa dây chuyền). */
    @Modifying
    @Query("DELETE FROM FlashcardProgress p WHERE p.flashcard.flashcardSet.setId = :setId")
    void deleteAllBySetId(@Param("setId") Long setId);

    /** Xóa tiến độ của mọi người dùng trên một thẻ trước khi xóa thẻ. */
    @Modifying
    @Query("DELETE FROM FlashcardProgress p WHERE p.flashcard.cardId = :cardId")
    void deleteByCardId(@Param("cardId") Long cardId);

    @Query("SELECT COUNT(p) FROM FlashcardProgress p WHERE p.user.id = :userId AND p.nextReviewAt IS NOT NULL AND p.nextReviewAt <= :now")
    long countDue(@Param("userId") Long userId, @Param("now") java.time.LocalDateTime now);

    @Query("SELECT MIN(p.nextReviewAt) FROM FlashcardProgress p WHERE p.user.id = :userId AND p.nextReviewAt > :now")
    java.time.LocalDateTime findNextDueAt(@Param("userId") Long userId, @Param("now") java.time.LocalDateTime now);

    @Query("SELECT COUNT(p) FROM FlashcardProgress p WHERE p.user.id = :userId AND p.nextReviewAt >= :from AND p.nextReviewAt < :to")
    long countDueBetween(@Param("userId") Long userId, @Param("from") java.time.LocalDateTime from, @Param("to") java.time.LocalDateTime to);

    /** Thẻ đã đến hạn của người dùng (cũ nhất trước), kèm thẻ và bộ thẻ trong cùng truy vấn; giới hạn bằng [pageable]. */
    @Query("SELECT p FROM FlashcardProgress p JOIN FETCH p.flashcard f JOIN FETCH f.flashcardSet " +
           "WHERE p.user.id = :userId AND p.nextReviewAt IS NOT NULL AND p.nextReviewAt <= :now " +
           "ORDER BY p.nextReviewAt ASC")
    List<FlashcardProgress> findDueByUserId(@Param("userId") Long userId,
                                            @Param("now") java.time.LocalDateTime now,
                                            org.springframework.data.domain.Pageable pageable);

    /** Số thẻ đã thuộc của người dùng cho nhiều bộ trong MỘT truy vấn. */
    @Query("SELECT p.flashcard.flashcardSet.setId AS id, COUNT(p) AS total FROM FlashcardProgress p " +
           "WHERE p.user.id = :userId AND p.srsState = com.jlsp.backend.flashcard.srs.CardState.REVIEW AND p.intervalDays >= 21 " +
           "AND p.flashcard.flashcardSet.setId IN :setIds " +
           "GROUP BY p.flashcard.flashcardSet.setId")
    List<com.jlsp.backend.common.repository.IdCount> countMasteredBySetIds(
            @Param("userId") Long userId, @Param("setIds") java.util.Collection<Long> setIds);
}
