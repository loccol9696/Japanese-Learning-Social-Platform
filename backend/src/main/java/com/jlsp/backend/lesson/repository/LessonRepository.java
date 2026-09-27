package com.jlsp.backend.lesson.repository;

import com.jlsp.backend.lesson.entity.Lesson;
import com.jlsp.backend.lesson.entity.LessonCategory;
import com.jlsp.backend.user.entity.JLPTLevel;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface LessonRepository extends JpaRepository<Lesson, Long> {

    Page<Lesson> findByLevel(JLPTLevel level, Pageable pageable);

    Page<Lesson> findByCategory(LessonCategory category, Pageable pageable);

    Page<Lesson> findByLevelAndCategory(JLPTLevel level, LessonCategory category, Pageable pageable);

    Page<Lesson> findByTitleContainingIgnoreCase(String keyword, Pageable pageable);
}
