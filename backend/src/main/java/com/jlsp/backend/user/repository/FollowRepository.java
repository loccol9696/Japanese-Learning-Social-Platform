package com.jlsp.backend.user.repository;

import com.jlsp.backend.user.entity.Follow;
import com.jlsp.backend.user.entity.FollowId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

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
}
