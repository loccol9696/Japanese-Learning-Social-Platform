package com.jlsp.backend.flashcard.repository;

import com.jlsp.backend.flashcard.entity.FlashcardSet;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface FlashcardSetRepository extends JpaRepository<FlashcardSet, Long> {

    @Query("SELECT s FROM FlashcardSet s WHERE s.user.id = :userId " +
           "ORDER BY s.isVideoSaved DESC, s.sortOrder ASC NULLS FIRST, s.createdAt DESC")
    Page<FlashcardSet> findUserSets(@Param("userId") Long userId, Pageable pageable);

    @Query("SELECT s FROM FlashcardSet s WHERE s.user.id = :userId " +
           "AND LOWER(s.title) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "ORDER BY s.isVideoSaved DESC, s.sortOrder ASC NULLS FIRST, s.createdAt DESC")
    Page<FlashcardSet> searchUserSets(@Param("userId") Long userId,
                                               @Param("keyword") String keyword,
                                               Pageable pageable);

    List<FlashcardSet> findByUserId(Long userId);

    /** Toàn bộ bộ thẻ của người dùng theo đúng thứ tự hiển thị trong thư viện. */
    @Query("SELECT s FROM FlashcardSet s WHERE s.user.id = :userId " +
           "ORDER BY s.isVideoSaved DESC, s.sortOrder ASC NULLS FIRST, s.createdAt DESC")
    List<FlashcardSet> findAllOrderedByUserId(@Param("userId") Long userId);

    Optional<FlashcardSet> findByUserIdAndIsVideoSavedTrue(Long userId);
}
