package com.jlsp.backend.flashcard.repository;

import com.jlsp.backend.flashcard.entity.Flashcard;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface FlashcardRepository extends JpaRepository<Flashcard, Long> {

    List<Flashcard> findByFlashcardSetSetId(Long setId);

    Page<Flashcard> findByFlashcardSetSetId(Long setId, Pageable pageable);

    long countByFlashcardSetSetId(Long setId);

    @Query("SELECT f FROM Flashcard f WHERE f.flashcardSet.setId = :setId AND f.cardId != :excludeCardId")
    List<Flashcard> findPotentialDistractors(@Param("setId") Long setId, @Param("excludeCardId") Long excludeCardId);
}
