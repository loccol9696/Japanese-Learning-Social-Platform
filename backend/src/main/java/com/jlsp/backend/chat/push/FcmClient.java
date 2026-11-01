package com.jlsp.backend.chat.push;

import com.google.auth.oauth2.GoogleCredentials;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.List;
import java.util.Map;

/**
 * Gửi thông báo đẩy qua FCM HTTP v1. Chưa khai báo FCM_PROJECT_ID và FCM_CREDENTIALS_PATH
 * thì tự tắt, mọi chức năng chat khác vẫn chạy bình thường.
 */
@Component
@Slf4j
public class FcmClient {

    public enum Result { SENT, TOKEN_INVALID, FAILED }

    private static final String SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

    private final String projectId;
    private final GoogleCredentials credentials;
    private final RestClient restClient = RestClient.create();

    public FcmClient(@Value("${fcm.project-id:}") String projectId,
                     @Value("${fcm.credentials-path:}") String credentialsPath) {
        this.projectId = projectId;
        this.credentials = loadCredentials(projectId, credentialsPath);
    }

    private static GoogleCredentials loadCredentials(String projectId, String path) {
        if (projectId.isBlank() || path.isBlank()) {
            log.info("Chưa cấu hình FCM, tắt thông báo đẩy");
            return null;
        }
        try (InputStream stream = new FileInputStream(path)) {
            return GoogleCredentials.fromStream(stream).createScoped(List.of(SCOPE));
        } catch (IOException e) {
            log.error("Không đọc được credentials FCM tại {}: {}", path, e.getMessage());
            return null;
        }
    }

    public boolean isEnabled() {
        return credentials != null;
    }

    public Result send(String token, String title, String body, Map<String, String> data) {
        try {
            credentials.refreshIfExpired();
            restClient.post()
                    .uri("https://fcm.googleapis.com/v1/projects/{project}/messages:send", projectId)
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + credentials.getAccessToken().getTokenValue())
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(buildPayload(token, title, body, data))
                    .retrieve()
                    .toBodilessEntity();
            return Result.SENT;
        } catch (RestClientResponseException e) {
            // 404 UNREGISTERED: ứng dụng đã gỡ hoặc token đã bị huỷ.
            if (e.getStatusCode().isSameCodeAs(HttpStatus.NOT_FOUND)) {
                return Result.TOKEN_INVALID;
            }
            log.warn("FCM từ chối thông báo ({}): {}", e.getStatusCode(), e.getResponseBodyAsString());
            return Result.FAILED;
        } catch (IOException | RestClientException e) {
            log.warn("Không gửi được thông báo FCM: {}", e.getMessage());
            return Result.FAILED;
        }
    }

    static Map<String, Object> buildPayload(String token, String title, String body, Map<String, String> data) {
        return Map.of("message", Map.of(
                "token", token,
                "notification", Map.of("title", title, "body", body),
                "data", data,
                "android", Map.of("priority", "HIGH")));
    }
}
