package com.jlsp.backend.topic.repository;

import com.jlsp.backend.topic.entity.Topic;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.Set;

@Repository
public interface TopicRepository extends JpaRepository<Topic, Long> {
    Optional<Topic> findByTopicNameIgnoreCase(String topicName);
    List<Topic> findByTopicNameInIgnoreCase(Set<String> topicNames);
    boolean existsByTopicNameIgnoreCase(String topicName);
}
