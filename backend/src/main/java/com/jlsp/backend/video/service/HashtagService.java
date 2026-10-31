package com.jlsp.backend.video.service;

import com.jlsp.backend.video.dto.response.HashtagSuggestionResponse;
import com.jlsp.backend.video.entity.Hashtag;

import java.util.Collection;
import java.util.List;
import java.util.Set;

public interface HashtagService {

    /** Số hashtag tối đa trên một video. */
    int MAX_PER_VIDEO = 5;

    /**
     * Chuẩn hoá danh sách người dùng gửi lên và trả các thẻ tương ứng (tạo mới nếu chưa có).
     * Ném 400 nếu có thẻ sai định dạng hoặc vượt quá {@link #MAX_PER_VIDEO}.
     */
    Set<Hashtag> resolve(Collection<String> rawNames);

    /** Gợi ý theo tiền tố, không phân biệt dấu; {@code query} trống thì trả thẻ phổ biến nhất. */
    List<HashtagSuggestionResponse> suggest(String query, int limit);
}
