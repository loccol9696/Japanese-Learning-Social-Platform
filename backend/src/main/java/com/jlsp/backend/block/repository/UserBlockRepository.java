package com.jlsp.backend.block.repository;

import com.jlsp.backend.block.entity.UserBlock;
import com.jlsp.backend.block.entity.UserBlockId;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface UserBlockRepository extends JpaRepository<UserBlock, UserBlockId> {

    boolean existsByIdBlockerIdAndIdBlockedId(Long blockerId, Long blockedId);

    /** Những người mà {@code userId} đã chặn. */
    @Query("SELECT b.id.blockedId FROM UserBlock b WHERE b.id.blockerId = :userId")
    List<Long> findBlockedIds(@Param("userId") Long userId);

    /** Những người đã chặn {@code userId}. */
    @Query("SELECT b.id.blockerId FROM UserBlock b WHERE b.id.blockedId = :userId")
    List<Long> findBlockerIds(@Param("userId") Long userId);

    @EntityGraph(attributePaths = "blocked")
    List<UserBlock> findByIdBlockerIdOrderByCreatedAtDesc(Long blockerId);
}
