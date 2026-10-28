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

    @Query("SELECT COUNT(p) FROM FlashcardProgress p WHERE p.user.id = :userId AND p.flashcard.flashcardSet.setId = :setId AND p.boxLevel >= 3")
    long countMasteredCards(@Param("userId") Long userId, @Param("setId") Long setId);

    @Modifying
    @Query("DELETE FROM FlashcardProgress p WHERE p.user.id = :userId AND p.flashcard.flashcardSet.setId = :setId")
    void deleteByUserIdAndSetId(@Param("userId") Long userId, @Param("setId") Long setId);

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
           "WHERE p.user.id = :userId AND p.boxLevel >= 3 AND p.flashcard.flashcardSet.setId IN :setIds " +
           "GROUP BY p.flashcard.flashcardSet.setId")
    List<com.jlsp.backend.common.repository.IdCount> countMasteredBySetIds(
            @Param("userId") Long userId, @Param("setIds") java.util.Collection<Long> setIds);
}
