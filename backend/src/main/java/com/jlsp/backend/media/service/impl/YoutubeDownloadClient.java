package com.jlsp.backend.media.service.impl;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.jlsp.backend.common.exception.AppException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestTemplate;

import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * Gọi vocal-service (Python, yt-dlp) để tải video YouTube về dạng MP4.
 */
@Slf4j
@Component
public class YoutubeDownloadClient {

    /** Video đã tải về từ YouTube. */
    public record DownloadedVideo(byte[] bytes, String title, Integer durationSeconds, String videoId) {
    }

    private static final Set<String> YOUTUBE_HOSTS = Set.of(
            "youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be");

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final String serviceUrl;

    public YoutubeDownloadClient(
            @Value("${YOUTUBE_SERVICE_URL:http://localhost:8000/api/v1/youtube/download}") String serviceUrl) {
        this.serviceUrl = serviceUrl;
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(10_000);
        factory.setReadTimeout(15 * 60 * 1000); // tải + ghép video có thể mất vài phút
        this.restTemplate = new RestTemplate(factory);
    }

    /** Kiểm tra link thuộc YouTube; trả về link đã trim. */
    static String validateUrl(String url) {
        if (url == null || url.isBlank()) {
            throw new AppException(400, "Vui lòng nhập link YouTube");
        }
        String trimmed = url.trim();
        URI uri;
        try {
            uri = URI.create(trimmed);
        } catch (IllegalArgumentException e) {
            throw new AppException(400, "Link YouTube không hợp lệ");
        }
        String scheme = uri.getScheme() == null ? "" : uri.getScheme().toLowerCase(Locale.ROOT);
        String host = uri.getHost() == null ? "" : uri.getHost().toLowerCase(Locale.ROOT);
        if (!(scheme.equals("http") || scheme.equals("https")) || !YOUTUBE_HOSTS.contains(host)) {
            throw new AppException(400, "Link YouTube không hợp lệ");
        }
        return trimmed;
    }

    public DownloadedVideo download(String url, int maxDurationSeconds) {
        String safeUrl = validateUrl(url);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<Map<String, Object>> request = new HttpEntity<>(
                Map.of("url", safeUrl, "max_duration", maxDurationSeconds), headers);

        ResponseEntity<byte[]> response;
        try {
            response = restTemplate.exchange(serviceUrl, HttpMethod.POST, request, byte[].class);
        } catch (HttpStatusCodeException e) {
            String detail = extractDetail(e.getResponseBodyAsString());
            int status = e.getStatusCode().value();
            log.warn("Tải YouTube thất bại ({}): {}", status, detail);
            throw new AppException(status == 413 ? 413 : (status >= 500 ? 502 : 400), detail);
        } catch (ResourceAccessException e) {
            log.error("Không kết nối được dịch vụ tải YouTube tại {}", serviceUrl, e);
            throw new AppException(503, "Dịch vụ tải YouTube chưa sẵn sàng, vui lòng thử lại sau");
        }

        byte[] body = response.getBody();
        if (body == null || body.length == 0) {
            throw new AppException(502, "Không tải được video YouTube");
        }

        HttpHeaders h = response.getHeaders();
        String title = decode(h.getFirst("X-Video-Title"));
        Integer duration = null;
        try {
            String d = h.getFirst("X-Video-Duration");
            if (d != null) duration = Integer.parseInt(d);
        } catch (NumberFormatException ignored) {
        }
        return new DownloadedVideo(body, title, duration, h.getFirst("X-Video-Id"));
    }

    private String extractDetail(String body) {
        try {
            JsonNode node = objectMapper.readTree(body);
            if (node.hasNonNull("detail") && node.get("detail").isTextual()) {
                return node.get("detail").asText();
            }
        } catch (Exception ignored) {
        }
        return "Không tải được video YouTube";
    }

    private static String decode(String value) {
        if (value == null || value.isBlank()) return null;
        try {
            return URLDecoder.decode(value, StandardCharsets.UTF_8);
        } catch (Exception e) {
            return value;
        }
    }
}

