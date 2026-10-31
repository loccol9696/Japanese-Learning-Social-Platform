package com.jlsp.backend.video.service;

import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.video.dto.response.VideoResponse;
import org.springframework.data.domain.Pageable;

import java.util.List;

/**
 * Thùng rác video: xóa mềm video cùng bình luận và tương tác của nó, khôi phục trong hạn lưu,
 * và xóa hẳn khi hết hạn hoặc khi người dùng yêu cầu.
 */
public interface VideoTrashService {

    /**
     * Chuyển video vào thùng rác (chỉ chủ sở hữu hoặc admin).
     *
     * @param videoId       ID video cần xóa
     * @param currentUserId ID người dùng thực hiện xóa
     */
    void moveToTrash(Long videoId, Long currentUserId);

    /**
     * Video còn trong hạn lưu của một người, mới xóa trước.
     *
     * @param userId   ID chủ video
     * @param pageable Thông tin phân trang
     * @return Trang video kèm thời điểm xóa và thời điểm sẽ xóa hẳn
     */
    PageResponse<VideoResponse> listTrash(Long userId, Pageable pageable);

    /**
     * Khôi phục video cùng dữ liệu phụ thuộc (chỉ chủ sở hữu hoặc admin, trong hạn lưu).
     *
     * @param videoId       ID video cần khôi phục
     * @param currentUserId ID người dùng thực hiện
     */
    void restore(Long videoId, Long currentUserId);

    /**
     * Xóa hẳn video đang trong thùng rác (chỉ chủ sở hữu hoặc admin).
     *
     * @param videoId       ID video cần xóa hẳn
     * @param currentUserId ID người dùng thực hiện
     */
    void deletePermanently(Long videoId, Long currentUserId);

    /**
     * Một lô video đã quá hạn lưu, cũ nhất trước.
     *
     * @return ID các video cần xóa hẳn
     */
    List<Long> findExpiredIds();

    /**
     * Xóa hẳn một video nếu nó vẫn đang quá hạn lưu.
     *
     * @param videoId ID video
     */
    void purgeExpired(Long videoId);
}
