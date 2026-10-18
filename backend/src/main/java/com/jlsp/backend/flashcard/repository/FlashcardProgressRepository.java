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
}
