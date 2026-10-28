package com.jlsp.backend.video.service;

import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.video.dto.request.CreateVideoRequest;
import com.jlsp.backend.video.dto.request.ShadowingSubmissionRequest;
import com.jlsp.backend.video.dto.request.UpdateVideoRequest;
import com.jlsp.backend.video.dto.response.ShadowingPracticeResponse;
import com.jlsp.backend.video.dto.response.VideoDetailResponse;
import com.jlsp.backend.video.dto.response.VideoResponse;
import org.springframework.data.domain.Pageable;

import java.util.List;

/**
 * Service Interface định nghĩa các nghiệp vụ xử lý cho phân hệ Video học tiếng
 * Nhật.
 */
public interface VideoService {

    /**
     * Đăng tải bài học video mới.
     *
     * @param currentUserId ID người dùng thực hiện tạo video
     * @param request       DTO thông tin video
     * @return Thông tin chi tiết video vừa tạo
     */
    VideoDetailResponse createVideo(Long currentUserId, CreateVideoRequest request);

    /**
     * Lấy chi tiết một video theo ID.
     *
     * @param id            ID của video
     * @param currentUserId ID người dùng hiện tại (nếu có, để kiểm tra trạng thái
     *                      isLiked, isSaved)
     * @return Chi tiết video kèm phụ đề JSON
     */
    VideoDetailResponse getVideoById(Long id, Long currentUserId);

    /**
     * Chỉnh sửa thông tin video bài học (chỉ chủ sở hữu video mới có quyền).
     *
     * @param id            ID video cần sửa
     * @param currentUserId ID người dùng thực hiện sửa
     * @param request       DTO thông tin cập nhật
     * @return Chi tiết video sau khi sửa
     */
    VideoDetailResponse updateVideo(Long id, Long currentUserId, UpdateVideoRequest request);

    /**
     * Xóa video (chỉ chủ sở hữu hoặc admin mới có quyền).
     *
     * @param id            ID video cần xóa
     * @param currentUserId ID người dùng thực hiện xóa
     */
    void deleteVideo(Long id, Long currentUserId);

    /**
     * Lấy danh sách video đề xuất "Dành cho bạn" (For-You Feed) theo dạng cuộn vô
     * tận TikTok.
     * Có thể lọc theo cấp độ JLPT phù hợp với người học.
     *
     * @param currentUserId ID người dùng hiện tại (nếu đã đăng nhập)
     * @param jlptLevel     Cấp độ JLPT muốn lọc (nếu null sẽ lấy tổng hợp)
     * @param pageable      Thông tin phân trang (page, size, sort)
     * @return Danh sách video phân trang
     */
    PageResponse<VideoResponse> getForYouFeed(Long currentUserId, JLPTLevel jlptLevel, Pageable pageable);

    /**
     * Lấy danh sách video từ những Creator mà người dùng đang theo dõi (Following
     * Feed).
     *
     * @param currentUserId ID người dùng hiện tại
     * @param pageable      Thông tin phân trang
     * @return Danh sách video phân trang
     */
    PageResponse<VideoResponse> getFollowingFeed(Long currentUserId, Pageable pageable);

    /**
     * Lấy danh sách video của một Creator cụ thể.
     *
     * @param userId        ID của Creator
     * @param currentUserId ID người dùng đang xem
     * @param pageable      Thông tin phân trang
     * @return Danh sách video phân trang
     */
    PageResponse<VideoResponse> getVideosByUserId(Long userId, Long currentUserId, Pageable pageable);
    PageResponse<VideoResponse> getLikedVideos(Long userId, Pageable pageable);
    PageResponse<VideoResponse> getSavedVideos(Long userId, Pageable pageable);

    /**
     * Thả tim hoặc Bỏ thích video (Toggle Like).
     * Tự động cập nhật số đếm like_count trên video một cách nguyên tử.
     *
     * @param videoId       ID của video
     * @param currentUserId ID người dùng thực hiện
     * @return true nếu đã Like thành công, false nếu đã Bỏ thích (Unlike)
     */
    boolean toggleLike(Long videoId, Long currentUserId);

    /**
     * Lưu hoặc Bỏ lưu video vào bộ sưu tập cá nhân (Toggle Bookmark/Save).
     * Tự động cập nhật số đếm save_count trên video một cách nguyên tử.
     *
     * @param videoId       ID của video
     * @param currentUserId ID người dùng thực hiện
     * @return true nếu đã Lưu thành công, false nếu đã Hủy lưu
     */
    boolean toggleSave(Long videoId, Long currentUserId);

    /**
     * Ghi nhận lượt xem hợp lệ cho video. Mỗi người xem (tài khoản, hoặc IP với khách) chỉ được tính một
     * lượt cho mỗi video trong một khoảng thời gian, để không bơm lượt xem bằng cách gọi lặp.
     *
     * @param videoId   ID của video
     * @param viewerKey định danh người xem (vd. "u12" hoặc "ip203.0.113.9"); null thì luôn tính
     */
    void incrementViewCount(Long videoId, String viewerKey);

    /**
     * Cập nhật dữ liệu phụ đề tương tác JSON (chứa phân đoạn start/end, text,
     * ruby/furigana).
     * Sẵn sàng để nhận dữ liệu từ module AI trích xuất giọng nói sau này.
     *
     * @param videoId       ID của video
     * @param currentUserId ID người dùng thực hiện
     * @param subtitlesJson Chuỗi JSON phụ đề
     * @return Chi tiết video sau khi nạp phụ đề
     */
    VideoDetailResponse updateSubtitles(Long videoId, Long currentUserId, String subtitlesJson);

    /**
     * Nộp bài luyện nói nhại theo (Shadowing).
     * Lưu trữ link file ghi âm vào bảng shadowing_practice, để trống score và
     * feedback chờ AI chấm.
     *
     * @param videoId       ID video bài học
     * @param currentUserId ID người học
     * @param request       DTO chứa link file ghi âm
     * @return Kết quả ghi nhận bài luyện tập
     */
    ShadowingPracticeResponse submitShadowing(Long videoId, Long currentUserId, ShadowingSubmissionRequest request);

    /**
     * Lấy lịch sử các lần luyện nói Shadowing của người dùng đối với một video cụ
     * thể.
     *
     * @param videoId       ID video bài học
     * @param currentUserId ID người học
     * @return Danh sách các lần luyện tập trước đó
     */
    List<ShadowingPracticeResponse> getShadowingHistory(Long videoId, Long currentUserId);

    /**
     * Lấy danh sách video tổng hợp.
     * Hỗ trợ lọc theo feed type ("for-you", "following"), cấp độ JLPT, hoặc Creator
     * ID.
     *
     * @param currentUserId ID người dùng hiện tại (nếu có)
     * @param feed          Loại feed ("for-you" hoặc "following")
     * @param jlptLevel     Cấp độ JLPT cần lọc (tuỳ chọn)
     * @param userId        ID Creator cần lọc (tuỳ chọn)
     * @param search        Từ khoá tìm theo tiêu đề / mô tả (tuỳ chọn)
     * @param topicId       Lọc theo chủ đề (tuỳ chọn; bị bỏ qua khi có từ khoá tìm kiếm hoặc feed following)
     * @param pageable      Phân trang và sắp xếp
     * @return Danh sách video phân trang
     */
    PageResponse<VideoResponse> getAllVideos(Long currentUserId, String feed, JLPTLevel jlptLevel, Long userId,
            String search, Long topicId, Pageable pageable);

    /**
     * Thả tim (Like) video
     *
     * @param videoId       ID của video
     * @param currentUserId ID người dùng thực hiện
     */
    void likeVideo(Long videoId, Long currentUserId);

    /**
     * Bỏ thích (Unlike) video
     *
     * @param videoId       ID của video
     * @param currentUserId ID người dùng thực hiện
     */
    void unlikeVideo(Long videoId, Long currentUserId);

    /**
     * Lưu video vào bộ sưu tập cá nhân (Save/Bookmark)
     *
     * @param videoId       ID của video
     * @param currentUserId ID người dùng thực hiện
     */
    void saveVideo(Long videoId, Long currentUserId);

    /**
     * Bỏ lưu video khỏi bộ sưu tập (Unsave)
     *
     * @param videoId       ID của video
     * @param currentUserId ID người dùng thực hiện
     */
    void unsaveVideo(Long videoId, Long currentUserId);

    /**
     * Lấy phụ đề tương tác JSON của một video.
     *
     * @param videoId ID của video
     * @return Chuỗi JSON phụ đề
     */
    String getSubtitles(Long videoId);

    /**
     * Duyệt video bài học (Chuyển sang trạng thái PUBLIC).
     *
     * @param videoId      ID video cần duyệt
     * @param moderatorId  ID của Admin/Moderator duyệt
     * @return Thông tin video đã duyệt
     */
    VideoDetailResponse approveVideo(Long videoId, Long moderatorId);

    /**
     * Từ chối video bài học do vi phạm tiêu chuẩn (Chuyển sang trạng thái REJECTED).
     *
     * @param videoId         ID video cần từ chối
     * @param moderatorId     ID của Admin/Moderator từ chối
     * @param rejectionReason Lý do vi phạm
     * @return Thông tin video bị từ chối
     */
    VideoDetailResponse rejectVideo(Long videoId, Long moderatorId, String rejectionReason);

    /**
     * Lấy danh sách video phục vụ kiểm duyệt cho Moderator.
     *
     * @param modStatus Trạng thái kiểm duyệt (mặc định PENDING nếu null)
     * @param pageable  Phân trang
     * @return Danh sách video theo phân trang
     */
    PageResponse<VideoResponse> getModerationVideos(com.jlsp.backend.video.entity.VideoModStatus modStatus, Pageable pageable);

    /**
     * Lấy danh sách video của người dùng hiện tại kèm theo trạng thái duyệt và lý do nếu bị từ chối.
     *
     * @param userId   ID người dùng
     * @param pageable Phân trang
     * @return Danh sách video của chính mình
     */
    PageResponse<VideoResponse> getMyVideosStatus(Long userId, Pageable pageable);
}
