package com.jlsp.backend.chat.service;

import com.jlsp.backend.ai.service.JaViTranslator;
import com.jlsp.backend.common.exception.AppException;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class ChatTranslationServiceTest {

    private final ChatService chatService = mock(ChatService.class);
    private final JaViTranslator translator = mock(JaViTranslator.class);
    private final ChatTranslationService service =
            new ChatTranslationService(chatService, translator, new ChatRateLimiter());

    @Test
    void translatesTheMessageContent() {
        when(chatService.getTranslatableContent(1L, 5L)).thenReturn("こんにちは");
        when(translator.translate("こんにちは")).thenReturn("Xin chào");

        assertThat(service.translate(1L, 5L)).isEqualTo("Xin chào");
    }

    @Test
    void emptyResultMeansTheTranslatorFailed() {
        when(chatService.getTranslatableContent(1L, 5L)).thenReturn("こんにちは");
        when(translator.translate("こんにちは")).thenReturn("");

        assertThatThrownBy(() -> service.translate(1L, 5L))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(503));
    }
}
