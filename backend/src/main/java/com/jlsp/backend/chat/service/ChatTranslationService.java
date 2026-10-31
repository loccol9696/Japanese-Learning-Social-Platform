package com.jlsp.backend.chat.service;

import com.jlsp.backend.ai.service.JaViTranslator;
import com.jlsp.backend.common.exception.AppException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * Dịch tin nhắn Nhật → Việt khi người dùng bấm "Dịch". Không chạy trong transaction vì
 * lời gọi dịch vụ ngoài có thể mất vài giây, không nên giữ kết nối DB trong lúc đó.
 */
@Service
@RequiredArgsConstructor
public class ChatTranslationService {

    private final ChatService chatService;
    private final JaViTranslator translator;
    private final ChatRateLimiter rateLimiter;

    public String translate(Long userId, Long messageId) {
        rateLimiter.check(userId);
        String content = chatService.getTranslatableContent(userId, messageId);
        String translation = translator.translate(content);
        if (translation.isBlank()) {
            throw new AppException(503, "Chưa dịch được tin nhắn này, vui lòng thử lại sau");
        }
        return translation;
    }
}
