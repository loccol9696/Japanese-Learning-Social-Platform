package com.jlsp.backend.topic.service.impl;

import com.jlsp.backend.topic.dto.response.TopicResponse;
import com.jlsp.backend.topic.entity.Topic;
import com.jlsp.backend.topic.repository.TopicRepository;
import com.jlsp.backend.topic.service.TopicService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class TopicServiceImpl implements TopicService {

    private final TopicRepository topicRepository;

    @Override
    @Transactional(readOnly = true)
    public List<TopicResponse> getAllTopics() {
        return topicRepository.findAll().stream()
                .map(topic -> TopicResponse.builder()
                        .id(topic.getTopicId())
                        .name(topic.getTopicName())
                        .build())
                .collect(Collectors.toList());
    }

    @Override
    @Transactional
    public TopicResponse createTopic(String name) {
        String trimmed = name.trim();
        Topic topic = topicRepository.findByTopicNameIgnoreCase(trimmed)
                .orElseGet(() -> topicRepository.save(Topic.builder().topicName(trimmed).build()));

        return TopicResponse.builder()
                .id(topic.getTopicId())
                .name(topic.getTopicName())
                .build();
    }
}
