package com.jlsp.backend.video.shadowing;

import com.jlsp.backend.dictionary.service.DictionaryService;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.entity.ShadowingLineAttempt;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.repository.ShadowingLineAttemptRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import com.jlsp.backend.common.exception.AppException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ShadowingLineServiceTest {

    private static final String SUBTITLES = "["
            + "{\"start\":\"00:00\",\"end\":\"00:03\",\"text\":\"こんにちは。\"},"
            + "{\"start\":\"00:03\",\"end\":\"00:03\",\"text\":\"bị bỏ qua vì end = start\"},"
            + "{\"start\":\"00:04\",\"end\":\"00:08\",\"text\":\"私の名前はロックです。\"}]";

    private ShadowingLineAttemptRepository attempts;
    private ShadowingLineService service;

    @BeforeEach
    void setUp() {
        VideoRepository videos = mock(VideoRepository.class);
        UserRepository users = mock(UserRepository.class);
        attempts = mock(ShadowingLineAttemptRepository.class);

        Video video = new Video();
        video.setId(5L);
        video.setSubtitles(SUBTITLES);
        when(videos.findById(5L)).thenReturn(Optional.of(video));
        when(videos.existsById(5L)).thenReturn(true);
        when(users.findById(9L)).thenReturn(Optional.of(User.builder().id(9L).build()));
        when(attempts.summarize(9L, 5L)).thenReturn(List.<Object[]>of(new Object[] { 1, 92, 3L }));

        service = new ShadowingLineService(videos, users, attempts, new KanaNormalizer(new DictionaryService()));
    }

    @Test
    void lineIndexSkipsCuesTheAppHides() {
        var r = service.scoreLine(5L, 9L, 1, "私の名前はロックです");

        assertThat(r.getExpectedText()).isEqualTo("私の名前はロックです。");
        assertThat(r.getScore()).isEqualTo(100);
        assertThat(r.getBestScore()).isEqualTo(92);
        verify(attempts).save(any(ShadowingLineAttempt.class));
    }

    @Test
    void outOfRangeLineIsRejected() {
        assertThatThrownBy(() -> service.scoreLine(5L, 9L, 2, "x")).isInstanceOf(AppException.class);
        assertThatThrownBy(() -> service.scoreLine(5L, 9L, -1, "x")).isInstanceOf(AppException.class);
    }

    @Test
    void summaryAveragesBestScores() {
        var s = service.summary(5L, 9L);
        assertThat(s.getPracticedLines()).isEqualTo(1);
        assertThat(s.getAverageScore()).isEqualTo(92);
    }
}
