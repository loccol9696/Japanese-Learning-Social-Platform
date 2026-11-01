package com.jlsp.backend.dictionary.service;

import com.jlsp.backend.dictionary.dto.TokenResponse;
import com.jlsp.backend.dictionary.dto.WordLookupResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.net.URI;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class DictionaryServiceTest {

    private static final String JISHO = """
            {"data":[{"japanese":[{"word":"猫","reading":"ねこ"}],
            "senses":[{"english_definitions":["cat"],"parts_of_speech":["Noun"]}],"jlpt":["jlpt-n5"]}]}""";
    private static final String MYMEMORY = "{\"responseStatus\":200,\"responseData\":{\"translatedText\":\"mèo\"}}";

    private RestTemplate http;
    private DictionaryService service;

    @BeforeEach
    void setUp() {
        http = mock(RestTemplate.class);
        when(http.getForObject(any(URI.class), eq(String.class))).thenAnswer(inv -> {
            URI uri = inv.getArgument(0);
            return uri.getHost().contains("jisho") ? JISHO : MYMEMORY;
        });
        service = new DictionaryService(http);
    }

    @Test
    void successfulLookupIsCached() {
        WordLookupResponse first = service.lookup("猫");
        int callsAfterFirst = org.mockito.Mockito.mockingDetails(http).getInvocations().size();
        WordLookupResponse second = service.lookup("猫");

        assertThat(first.isFound()).isTrue();
        assertThat(first.getMeaningVi()).isEqualTo("mèo");
        assertThat(first.getJlptLevel()).isEqualTo("N5");
        assertThat(second).isSameAs(first);
        assertThat(org.mockito.Mockito.mockingDetails(http).getInvocations()).hasSize(callsAfterFirst);
    }

    @Test
    void failedLookupIsNotCachedSoItCanBeRetried() {
        when(http.getForObject(any(URI.class), eq(String.class))).thenThrow(new RestClientException("down"));

        assertThat(service.lookup("猫").isFound()).isFalse();
        int callsAfterFirst = org.mockito.Mockito.mockingDetails(http).getInvocations().size();
        assertThat(service.lookup("猫").isFound()).isFalse();

        assertThat(org.mockito.Mockito.mockingDetails(http).getInvocations().size()).isGreaterThan(callsAfterFirst);
    }

    @Test
    void overlongWordNeverReachesExternalServices() {
        WordLookupResponse response = service.lookup("あ".repeat(DictionaryService.MAX_WORD_LENGTH + 1));

        assertThat(response.isFound()).isFalse();
        assertThat(response.getTerm()).hasSize(DictionaryService.MAX_WORD_LENGTH);
        verifyNoInteractions(http);
    }

    @Test
    void blankWordIsNotFound() {
        assertThat(service.lookup("  ").isFound()).isFalse();
        verifyNoInteractions(http);
    }

    @Test
    void cacheEvictsOldestEntriesInsteadOfClearingEverything() {
        int total = 5001;
        for (int i = 0; i < total; i++) {
            service.lookup("語" + i);
        }
        int before = org.mockito.Mockito.mockingDetails(http).getInvocations().size();

        // Hai từ mới nhất vẫn phải còn trong cache (kiểu "đầy thì xoá hết" sẽ làm mất từ thứ 5000).
        service.lookup("語" + (total - 1));
        service.lookup("語" + (total - 2));

        assertThat(org.mockito.Mockito.mockingDetails(http).getInvocations()).hasSize(before);
        // Từ cũ nhất đã bị loại nên phải tra lại.
        service.lookup("語0");
        assertThat(org.mockito.Mockito.mockingDetails(http).getInvocations().size()).isGreaterThan(before);
    }

    @Test
    void tokenizeReturnsCachedImmutableList() {
        List<TokenResponse> first = service.tokenize("猫が好きです");
        List<TokenResponse> second = service.tokenize("猫が好きです");

        assertThat(first).isNotEmpty();
        assertThat(second).isSameAs(first);
        assertThatThrownBy(() -> first.add(first.get(0))).isInstanceOf(UnsupportedOperationException.class);
    }

    @Test
    void tokenizeBlankReturnsEmpty() {
        assertThat(service.tokenize(" ")).isEmpty();
        assertThat(service.tokenize(null)).isEmpty();
    }
}
