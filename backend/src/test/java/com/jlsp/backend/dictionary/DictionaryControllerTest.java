package com.jlsp.backend.dictionary;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.security.ratelimit.ClientIpResolver;
import com.jlsp.backend.common.security.ratelimit.RateLimiter;
import com.jlsp.backend.dictionary.controller.DictionaryController;
import com.jlsp.backend.dictionary.dto.WordLookupResponse;
import com.jlsp.backend.dictionary.service.DictionaryService;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class DictionaryControllerTest {

    private final DictionaryService service = mock(DictionaryService.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final DictionaryController controller =
            new DictionaryController(service, limiter, new ClientIpResolver(false));

    @Test
    void lookupIsLimitedPerClientIp() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("10.1.2.3");
        when(limiter.tryAcquire("dictionary-lookup:10.1.2.3", 120, Duration.ofMinutes(1)))
                .thenReturn(RateLimiter.Decision.ALLOWED);
        when(service.lookup("猫")).thenReturn(WordLookupResponse.builder().term("猫").found(true).build());

        assertThat(controller.lookup("猫", request).getBody().getData().getTerm()).isEqualTo("猫");
    }

    @Test
    void lookupReturns429AndSkipsExternalCallsWhenLimited() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        when(limiter.tryAcquire(anyString(), org.mockito.ArgumentMatchers.anyInt(), org.mockito.ArgumentMatchers.any()))
                .thenReturn(new RateLimiter.Decision(false, 17));

        assertThatThrownBy(() -> controller.lookup("猫", request))
                .isInstanceOfSatisfying(AppException.class, e -> {
                    assertThat(e.getStatus()).isEqualTo(429);
                    assertThat(e.getMessage()).contains("17");
                });
        verify(service, never()).lookup(anyString());
    }
}
