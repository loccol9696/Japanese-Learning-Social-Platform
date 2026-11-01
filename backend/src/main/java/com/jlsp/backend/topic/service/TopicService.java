package com.jlsp.backend.topic.service;

import com.jlsp.backend.topic.dto.TopicRequest;
import com.jlsp.backend.topic.dto.TopicResponse;
import com.jlsp.backend.topic.entity.Topic;

import java.util.Collection;
import java.util.List;
import java.util.Set;

public interface TopicService {

    /** Chủ đề đang hiển thị (cho app). */
    List<TopicResponse> getActiveTopics();

    /** Toàn bộ chủ đề kể cả đã ẩn (cho admin). */
    List<TopicResponse> getAllTopics();

    TopicResponse create(TopicRequest request);

    TopicResponse update(Long id, TopicRequest request);

    /** Ẩn chủ đề (xoá mềm). */
    void deactivate(Long id);

    /** Tìm chủ đề đang hiển thị; ném 400 nếu id không tồn tại hoặc đã ẩn. */
    Topic requireActive(Long id);

    /** Tìm các chủ đề đang hiển thị theo id; ném 400 nếu có id không hợp lệ. */
    Set<Topic> requireActive(Collection<Long> ids);

    TopicResponse toResponse(Topic topic);
}
