package com.jlsp.backend.chat.repository;

import com.jlsp.backend.chat.entity.UserBlock;
import com.jlsp.backend.chat.entity.UserBlockId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;

@Repository
public interface UserBlockRepository extends JpaRepository<UserBlock, UserBlockId> {

    /** Một trong hai người đã chặn người kia. */
    @Query("SELECT COUNT(b) > 0 FROM UserBlock b " +
            "WHERE (b.id.blockerId = :first AND b.id.blockedId = :second) " +
            "OR (b.id.blockerId = :second AND b.id.blockedId = :first)")
    boolean existsBetween(@Param("first") Long first, @Param("second") Long second);

    /** Các lượt chặn theo cả hai chiều giữa userId và otherIds (một truy vấn cho cả trang Inbox). */
    @Query("SELECT b FROM UserBlock b " +
            "WHERE (b.id.blockerId = :userId AND b.id.blockedId IN :otherIds) " +
            "OR (b.id.blockedId = :userId AND b.id.blockerId IN :otherIds)")
    List<UserBlock> findBetween(@Param("userId") Long userId, @Param("otherIds") Collection<Long> otherIds);

    /** Mọi người đã chặn userId hoặc bị userId chặn. */
    @Query("SELECT CASE WHEN b.id.blockerId = :userId THEN b.id.blockedId ELSE b.id.blockerId END " +
            "FROM UserBlock b WHERE b.id.blockerId = :userId OR b.id.blockedId = :userId")
    List<Long> findRelatedUserIds(@Param("userId") Long userId);
}
