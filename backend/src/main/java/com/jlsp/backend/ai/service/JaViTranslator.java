package com.jlsp.backend.ai.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.nio.charset.StandardCharsets;

/** Dịch Nhật -> Việt bằng MyMemory; trả chuỗi rỗng nếu lỗi hoặc hết hạn mức. */
@Component
public class JaViTranslator {

    private static final Logger log = LoggerFactory.getLogger(JaViTranslator.class);

    /** Sau khi lỗi, tạm ngừng gọi MyMemory trong khoảng này để không làm treo cả tác vụ phụ đề. */
    private static final long COOLDOWN_MS = 60_000;

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper = new ObjectMapper();
    private volatile long disabledUntil = 0;

    public JaViTranslator() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(5_000);
        factory.setReadTimeout(10_000);
        this.restTemplate = new RestTemplate(factory);
    }

    public String translate(String japaneseText) {
        if (japaneseText == null || japaneseText.isBlank()) {
            return "";
        }
        if (System.currentTimeMillis() < disabledUntil) {
            return "";
        }
        try {
            URI uri = UriComponentsBuilder.fromUriString("https://api.mymemory.translated.net/get")
                    .queryParam("q", japaneseText)
                    .queryParam("langpair", "ja|vi")
                    .queryParam("de", "minedung2005@gmail.com")
                    .encode(StandardCharsets.UTF_8)
                    .build()
                    .toUri();

            String rawResponse = restTemplate.getForObject(uri, String.class);
            if (rawResponse == null || rawResponse.isBlank()) {
                return "";
            }

            JsonNode root = objectMapper.readTree(rawResponse);
            int status = root.path("responseStatus").asInt(0);
            if (status == 200 && root.has("responseData")) {
                return root.get("responseData").path("translatedText").asText("").trim();
            }
            log.warn("MyMemory lỗi phản hồi mã {}: {}", status, rawResponse);
            if (status == 429 || status == 403) {
                disabledUntil = System.currentTimeMillis() + COOLDOWN_MS;
            }
            return "";
        } catch (Exception e) {
            log.error("Lỗi khi dịch tiếng Nhật sang tiếng Việt: [{}] - {}", japaneseText, e.getMessage());
            disabledUntil = System.currentTimeMillis() + COOLDOWN_MS;
            return "";
        }
    }
}
