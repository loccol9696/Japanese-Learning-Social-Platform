package com.jlsp.backend.ai.service.impl.analysis;

import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.event.SubtitlesUpdatedEvent;
import com.jlsp.backend.video.repository.VideoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class GrammarAnalysisJobTest {

    private static final String SUBTITLES = """
            [{"startTime":0.0,"endTime":2.5,"text":"こんにちは","translatedText":"Xin chào"},
             {"startTime":2.8,"endTime":5.2,"text":"毎日日本語を勉強しています。","translatedText":"..."}]
            """;

    private VideoRepository videoRepository;
    private GrammarAnalysisJob job;

    @BeforeEach
    void setUp() {
        videoRepository = mock(VideoRepository.class);
        MockGrammarAnalysisService mockAnalysis = new MockGrammarAnalysisService();
        ReflectionTestUtils.setField(mockAnalysis, "delayMs", 0L);
        job = new GrammarAnalysisJob(videoRepository, mockAnalysis);
    }

    @Test
    void analyzesSubtitlesAndSavesResult() {
        Video video = Video.builder().id(1L).subtitles(SUBTITLES).build();
        when(videoRepository.findById(1L)).thenReturn(Optional.of(video));
        when(videoRepository.updateGrammarAnalysisIfSubtitlesUnchanged(anyLong(), anyString(), anyString()))
                .thenReturn(1);

        job.onSubtitlesUpdated(new SubtitlesUpdatedEvent(1L));

        ArgumentCaptor<String> analysis = ArgumentCaptor.forClass(String.class);
        verify(videoRepository).updateGrammarAnalysisIfSubtitlesUnchanged(eq(1L), eq(SUBTITLES), analysis.capture());
        assertThat(analysis.getValue())
                .contains("\"index\":1")
                .contains("\"startTime\":2.8")
                .contains("〜ている");
    }

    @Test
    void skipsWhenNoSubtitles() {
        when(videoRepository.findById(2L)).thenReturn(Optional.of(Video.builder().id(2L).build()));

        job.analyzeAndSave(2L);

        verify(videoRepository, never()).updateGrammarAnalysisIfSubtitlesUnchanged(any(), any(), any());
    }

    @Test
    void skipsWhenSubtitlesNotSegmentJson() {
        when(videoRepository.findById(3L))
                .thenReturn(Optional.of(Video.builder().id(3L).subtitles("not a json").build()));

        job.analyzeAndSave(3L);

        verify(videoRepository, never()).updateGrammarAnalysisIfSubtitlesUnchanged(any(), any(), any());
    }
}

