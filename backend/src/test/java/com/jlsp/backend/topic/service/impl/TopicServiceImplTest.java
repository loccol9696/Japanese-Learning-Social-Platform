package com.jlsp.backend.topic.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.topic.dto.TopicRequest;
import com.jlsp.backend.topic.dto.TopicResponse;
import com.jlsp.backend.topic.entity.Topic;
import com.jlsp.backend.topic.repository.TopicRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class TopicServiceImplTest {

    private TopicRepository repository;
    private TopicServiceImpl service;

    @BeforeEach
    void setUp() {
        repository = mock(TopicRepository.class);
        service = new TopicServiceImpl(repository);
        when(repository.save(any(Topic.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    private static Topic topic(long id, String name, int order, boolean active) {
        return Topic.builder().id(id).name(name).sortOrder(order).isActive(active).build();
    }

    @Test
    void createRejectsDuplicateName() {
        when(repository.existsByNameIgnoreCase("Anime")).thenReturn(true);

        assertThatThrownBy(() -> service.create(new TopicRequest(" Anime ", null, null)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        verify(repository, never()).save(any());
    }

    @Test
    void createAppendsAfterTheLastTopicAndIsActiveByDefault() {
        when(repository.findAllByOrderBySortOrderAscIdAsc())
                .thenReturn(List.of(topic(1, "A", 1, true), topic(2, "B", 7, false)));

        TopicResponse created = service.create(new TopicRequest("  Mới  ", null, null));

        assertThat(created.getName()).isEqualTo("Mới");
        assertThat(created.getSortOrder()).isEqualTo(8);
        assertThat(created.getIsActive()).isTrue();
    }

    @Test
    void updateKeepsUnspecifiedFields() {
        Topic existing = topic(3, "Cũ", 4, true);
        when(repository.findById(3L)).thenReturn(Optional.of(existing));

        TopicResponse updated = service.update(3L, new TopicRequest("Mới", null, null));

        assertThat(updated.getName()).isEqualTo("Mới");
        assertThat(updated.getSortOrder()).isEqualTo(4);
        assertThat(updated.getIsActive()).isTrue();
    }

    @Test
    void deactivateHidesInsteadOfDeleting() {
        Topic existing = topic(3, "Cũ", 4, true);
        when(repository.findById(3L)).thenReturn(Optional.of(existing));

        service.deactivate(3L);

        ArgumentCaptor<Topic> saved = ArgumentCaptor.forClass(Topic.class);
        verify(repository).save(saved.capture());
        assertThat(saved.getValue().getIsActive()).isFalse();
        verify(repository, never()).delete(any());
    }

    @Test
    void requireActiveRejectsHiddenOrUnknownTopic() {
        when(repository.findByIdAndIsActiveTrue(9L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.requireActive(9L))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
    }

    @Test
    void requireActiveForIdsFailsWhenAnyIdIsInvalid() {
        when(repository.findByIdInAndIsActiveTrue(any())).thenReturn(List.of(topic(1, "A", 1, true)));

        assertThatThrownBy(() -> service.requireActive(Set.of(1L, 2L)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        assertThat(service.requireActive(Set.<Long>of())).isEmpty();
    }
}
