package com.jlsp.backend.topic.service;

import com.jlsp.backend.topic.dto.response.TopicResponse;

import java.util.List;

public interface TopicService {
    List<TopicResponse> getAllTopics();
    TopicResponse createTopic(String name);
}
