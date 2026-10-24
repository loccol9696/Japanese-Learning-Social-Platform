package com.jlsp.backend.googlestt.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.nio.charset.StandardCharsets;

/** Dịch Nhật -> Việt bằng MyMemory; trả chuỗi rỗng nếu lỗi hoặc hết hạn mức. */
@Component
public class JaViTranslator {

    private static final Logger log = LoggerFactory.getLogger(JaViTranslator.class);

    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public String translate(String japaneseText) {
        if (japaneseText == null || japaneseText.isBlank()) {
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
            return "";
        } catch (Exception e) {
            log.error("Lỗi khi dịch tiếng Nhật sang tiếng Việt: [{}] - {}", japaneseText, e.getMessage());
            return "";
        }
    }
}
