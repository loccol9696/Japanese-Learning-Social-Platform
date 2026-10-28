package com.jlsp.backend.user.repository;

import com.jlsp.backend.user.entity.Follow;
import com.jlsp.backend.user.entity.FollowId;
import com.jlsp.backend.user.entity.User;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Set;

@Repository
public interface FollowRepository extends JpaRepository<Follow, FollowId> {

    /**
     * Lấy danh sách ID của những người dùng mà followerId đang theo dõi.
     * Sử dụng cho việc lấy Following Feed của Video.
     *
     * @param followerId ID của người dùng hiện tại
     * @return Danh sách user_id được theo dõi
     */
    @Query("SELECT f.id.followingId FROM Follow f WHERE f.id.followerId = :followerId")
    List<Long> findFollowingIdsByFollowerId(@Param("followerId") Long followerId);

    /**
     * Kiểm tra xem followerId có đang theo dõi followingId hay không.
     */
    boolean existsByIdFollowerIdAndIdFollowingId(Long followerId, Long followingId);

    /**
     * Trong số userIds, những người mà followerId đang theo dõi — thay cho mỗi người một lần {@code exists}.
     */
    @Query("SELECT f.id.followingId FROM Follow f " +
            "WHERE f.id.followerId = :followerId AND f.id.followingId IN :userIds")
    Set<Long> findFollowingIdsAmong(@Param("followerId") Long followerId,
                                    @Param("userIds") Collection<Long> userIds);

    /**
     * Trong số otherIds, những người follow lẫn nhau với userId — một truy vấn cho cả danh sách hội thoại.
     */
    @Query("SELECT f.id.followingId FROM Follow f " +
            "WHERE f.id.followerId = :userId AND f.id.followingId IN :otherIds " +
            "AND EXISTS (SELECT 1 FROM Follow r WHERE r.id.followerId = f.id.followingId " +
            "AND r.id.followingId = :userId)")
    Set<Long> findMutualIdsAmong(@Param("userId") Long userId, @Param("otherIds") Collection<Long> otherIds);

    /**
     * Số quan hệ follow giữa hai người theo cả hai chiều (2 = follow lẫn nhau).
     * Một câu truy vấn thay cho hai lần {@code exists} để bớt một lượt gọi DB.
     */
    @Query("SELECT COUNT(f) FROM Follow f " +
            "WHERE (f.id.followerId = :userId AND f.id.followingId = :otherId) " +
            "OR (f.id.followerId = :otherId AND f.id.followingId = :userId)")
    long countFollowsBetween(@Param("userId") Long userId, @Param("otherId") Long otherId);

    /**
     * Số người mà user này đang theo dõi (following)
     */
    long countByIdFollowerId(Long followerId);

    /**
     * Số người đang theo dõi user này (followers)
     */
    long countByIdFollowingId(Long followingId);

    /** ID những người đang theo dõi userId. */
    @Query("SELECT f.id.followerId FROM Follow f WHERE f.id.followingId = :userId")
    List<Long> findFollowerIdsByFollowingId(@Param("userId") Long userId);

    /** Trong số userIds, những người đang theo dõi followedId — thay cho tải toàn bộ danh sách follower. */
    @Query("SELECT f.id.followerId FROM Follow f " +
            "WHERE f.id.followingId = :followedId AND f.id.followerId IN :userIds")
    Set<Long> findFollowerIdsAmong(@Param("followedId") Long followedId,
                                   @Param("userIds") Collection<Long> userIds);

    /** Một trang những người đang theo dõi userId (chỉ tài khoản đang hoạt động), mới nhất trước. */
    @Query("SELECT f FROM Follow f JOIN FETCH f.follower u " +
            "WHERE f.id.followingId = :userId AND u.isActive = true " +
            "ORDER BY f.createdAt DESC")
    List<Follow> findFollowersOf(@Param("userId") Long userId, Pageable pageable);

    /** Một trang những người userId đang theo dõi (chỉ tài khoản đang hoạt động), mới nhất trước. */
    @Query("SELECT f FROM Follow f JOIN FETCH f.following u " +
            "WHERE f.id.followerId = :userId AND u.isActive = true " +
            "ORDER BY f.createdAt DESC")
    List<Follow> findFollowingOf(@Param("userId") Long userId, Pageable pageable);

    /**
     * Những người dùng (đang hoạt động) mà userId và họ follow lẫn nhau.
     * Chỉ những người này mới được nhắn tin / nhận video share từ userId.
     */
    @Query("SELECT u FROM User u WHERE u.isActive = true " +
            "AND u.id IN (SELECT f.id.followingId FROM Follow f WHERE f.id.followerId = :userId) " +
            "AND u.id IN (SELECT r.id.followerId FROM Follow r WHERE r.id.followingId = :userId) " +
            "ORDER BY COALESCE(u.displayName, u.username)")
    List<User> findMutualFollows(@Param("userId") Long userId);
}
