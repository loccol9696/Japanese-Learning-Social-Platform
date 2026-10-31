package com.jlsp.backend.flashcard.repository;

import com.jlsp.backend.common.repository.IdCount;
import com.jlsp.backend.flashcard.entity.Flashcard;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface FlashcardRepository extends JpaRepository<Flashcard, Long> {

    List<Flashcard> findByFlashcardSetSetId(Long setId);

    Page<Flashcard> findByFlashcardSetSetId(Long setId, Pageable pageable);

    /** Thẻ của bộ theo thứ tự hiển thị: đã sắp xếp trước, thẻ mới (chưa có thứ tự) theo thứ tự tạo. */
    @Query("SELECT f FROM Flashcard f WHERE f.flashcardSet.setId = :setId " +
           "ORDER BY f.sortOrder ASC NULLS LAST, f.cardId ASC")
    List<Flashcard> findOrderedBySetId(@Param("setId") Long setId);

    long countByFlashcardSetSetId(Long setId);

    /** Số thẻ của nhiều bộ trong MỘT truy vấn (bộ không có thẻ sẽ không có dòng). */
    @Query("SELECT f.flashcardSet.setId AS id, COUNT(f) AS total FROM Flashcard f " +
           "WHERE f.flashcardSet.setId IN :setIds GROUP BY f.flashcardSet.setId")
    List<IdCount> countBySetIds(@Param("setIds") Collection<Long> setIds);

    /** Thẻ cùng từ (không phân biệt hoa thường) trong một bộ, dùng để không lưu trùng. */
    Optional<Flashcard> findFirstByFlashcardSetSetIdAndTermIgnoreCase(Long setId, String term);

    @Query("SELECT f FROM Flashcard f WHERE f.flashcardSet.setId = :setId AND f.cardId != :excludeCardId")
    List<Flashcard> findPotentialDistractors(@Param("setId") Long setId, @Param("excludeCardId") Long excludeCardId);
}
