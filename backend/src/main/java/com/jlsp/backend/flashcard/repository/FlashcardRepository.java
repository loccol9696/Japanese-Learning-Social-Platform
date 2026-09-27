package com.jlsp.backend.flashcard.repository;

import com.jlsp.backend.flashcard.entity.Flashcard;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface FlashcardRepository extends JpaRepository<Flashcard, Long> {

    List<Flashcard> findByLessonId(Long lessonId);

    Page<Flashcard> findByLessonId(Long lessonId, Pageable pageable);
}
