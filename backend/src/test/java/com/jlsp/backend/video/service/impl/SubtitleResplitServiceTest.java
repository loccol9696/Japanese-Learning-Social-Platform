package com.jlsp.backend.video.service.impl;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.jlsp.backend.googlestt.service.JaViTranslator;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.repository.VideoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class SubtitleResplitServiceTest {

    private static final String LONG_CUE = "[{\"start\":\"00:10\",\"end\":\"00:18\","
            + "\"text\":\"私はまたラボに戻らなくてはならないんだ。ほら、さっさと出したまえ。\",\"translation\":\"dài\"}]";

    private VideoRepository repository;
    private JaViTranslator translator;
    private SubtitleResplitService service;
    private Video video;

    @BeforeEach
    void setUp() {
        repository = mock(VideoRepository.class);
        translator = mock(JaViTranslator.class);
        when(translator.translate(any())).thenReturn("vi");
        video = new Video();
        video.setId(7L);
        video.setSubtitles(LONG_CUE);
        when(repository.findById(7L)).thenReturn(Optional.of(video));
        service = new SubtitleResplitService(repository, translator);
    }

    @Test
    void dryRunReportsButDoesNotWrite() {
        var results = service.resplit(7L, true);

        assertThat(results).hasSize(1);
        assertThat(results.get(0).changed()).isTrue();
        assertThat(results.get(0).cuesBefore()).isEqualTo(1);
        assertThat(results.get(0).cuesAfter()).isEqualTo(2);
        assertThat(video.getSubtitles()).isEqualTo(LONG_CUE);
        verify(repository, never()).save(any());
        verify(translator, never()).translate(any());
    }

    @Test
    void realRunSplitsKeepsTimeStyleAndTranslatesEachSentence() throws Exception {
        service.resplit(7L, false);

        JsonNode cues = new ObjectMapper().readTree(video.getSubtitles());
        assertThat(cues).hasSize(2);
        assertThat(cues.get(0).get("text").asText()).isEqualTo("私はまたラボに戻らなくてはならないんだ。");
        assertThat(cues.get(0).get("start").asText()).isEqualTo("00:10.0");
        assertThat(cues.get(1).get("end").asText()).isEqualTo("00:18.0");
        assertThat(cues.get(0).get("translation").asText()).isEqualTo("vi");
        // Mốc nối tiếp nhau, không chồng lấn.
        double firstEnd = SubtitleResplitService.parseSeconds(cues.get(0).get("end"));
        double secondStart = SubtitleResplitService.parseSeconds(cues.get(1).get("start"));
        assertThat(firstEnd).isLessThanOrEqualTo(secondStart + 0.05);
        verify(repository).save(video);
    }

    @Test
    void shortCuesAndNumericTimesAreLeftAlone() {
        String shortCue = "[{\"start\":1.0,\"end\":3.0,\"text\":\"こんにちは。\",\"translation\":\"Xin chào\"}]";
        video.setSubtitles(shortCue);

        var results = service.resplit(7L, false);

        assertThat(results.get(0).changed()).isFalse();
        assertThat(video.getSubtitles()).isEqualTo(shortCue);
        verify(repository, never()).save(any());
    }

    @Test
    void invalidJsonIsSkipped() {
        video.setSubtitles("không phải json");
        assertThat(service.resplit(7L, false)).isEmpty();
    }
}
