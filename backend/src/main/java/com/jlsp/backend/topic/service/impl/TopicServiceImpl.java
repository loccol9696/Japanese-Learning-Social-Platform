package com.jlsp.backend.topic.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.topic.dto.TopicRequest;
import com.jlsp.backend.topic.dto.TopicResponse;
import com.jlsp.backend.topic.entity.Topic;
import com.jlsp.backend.topic.repository.TopicRepository;
import com.jlsp.backend.topic.service.TopicService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class TopicServiceImpl implements TopicService {

    private final TopicRepository topicRepository;

    @Override
    public List<TopicResponse> getActiveTopics() {
        return topicRepository.findByIsActiveTrueOrderBySortOrderAscIdAsc().stream()
                .map(this::toResponse).toList();
    }

    @Override
    public List<TopicResponse> getAllTopics() {
        return topicRepository.findAllByOrderBySortOrderAscIdAsc().stream()
                .map(this::toResponse).toList();
    }

    @Override
    @Transactional
    public TopicResponse create(TopicRequest request) {
        String name = request.getName().trim();
        if (topicRepository.existsByNameIgnoreCase(name)) {
            throw new AppException(400, "Chủ đề \"" + name + "\" đã tồn tại");
        }
        int nextOrder = topicRepository.findAllByOrderBySortOrderAscIdAsc().stream()
                .mapToInt(Topic::getSortOrder).max().orElse(0) + 1;
        Topic topic = Topic.builder()
                .name(name)
                .isActive(request.getIsActive() == null || request.getIsActive())
                .sortOrder(request.getSortOrder() != null ? request.getSortOrder() : nextOrder)
                .build();
        return toResponse(topicRepository.save(topic));
    }

    @Override
    @Transactional
    public TopicResponse update(Long id, TopicRequest request) {
        Topic topic = topicRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Topic", "id", id));
        String name = request.getName().trim();
        if (topicRepository.existsByNameIgnoreCaseAndIdNot(name, id)) {
            throw new AppException(400, "Chủ đề \"" + name + "\" đã tồn tại");
        }
        topic.setName(name);
        if (request.getIsActive() != null) topic.setIsActive(request.getIsActive());
        if (request.getSortOrder() != null) topic.setSortOrder(request.getSortOrder());
        return toResponse(topicRepository.save(topic));
    }

    @Override
    @Transactional
    public void deactivate(Long id) {
        Topic topic = topicRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Topic", "id", id));
        topic.setIsActive(false);
        topicRepository.save(topic);
    }

    @Override
    public Topic requireActive(Long id) {
        return topicRepository.findByIdAndIsActiveTrue(id)
                .orElseThrow(() -> new AppException(400, "Chủ đề không hợp lệ hoặc đã bị ẩn"));
    }

    @Override
    public Set<Topic> requireActive(Collection<Long> ids) {
        Set<Long> wanted = new HashSet<>(ids);
        if (wanted.isEmpty()) return new HashSet<>();
        Set<Topic> found = new HashSet<>(topicRepository.findByIdInAndIsActiveTrue(wanted));
        if (found.size() != wanted.size()) {
            throw new AppException(400, "Có chủ đề không hợp lệ hoặc đã bị ẩn");
        }
        return found;
    }

    @Override
    public TopicResponse toResponse(Topic topic) {
        return TopicResponse.builder()
                .id(topic.getId())
                .name(topic.getName())
                .isActive(topic.getIsActive())
                .sortOrder(topic.getSortOrder())
                .build();
    }
}
