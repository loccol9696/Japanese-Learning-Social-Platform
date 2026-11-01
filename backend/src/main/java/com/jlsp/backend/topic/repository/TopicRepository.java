package com.jlsp.backend.topic.repository;

import com.jlsp.backend.topic.entity.Topic;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface TopicRepository extends JpaRepository<Topic, Long> {

    List<Topic> findByIsActiveTrueOrderBySortOrderAscIdAsc();

    List<Topic> findAllByOrderBySortOrderAscIdAsc();

    Optional<Topic> findByIdAndIsActiveTrue(Long id);

    List<Topic> findByIdInAndIsActiveTrue(Collection<Long> ids);

    boolean existsByNameIgnoreCase(String name);

    boolean existsByNameIgnoreCaseAndIdNot(String name, Long id);
}
