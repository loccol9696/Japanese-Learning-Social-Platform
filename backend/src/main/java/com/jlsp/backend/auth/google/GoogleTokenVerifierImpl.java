package com.jlsp.backend.auth.google;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.jlsp.backend.common.exception.AppException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.List;

/**
 * Dùng thư viện của Google để kiểm tra chữ ký, hạn dùng, issuer và audience (phải là một trong các
 * Client ID của app trong GOOGLE_CLIENT_IDS, phân tách bằng dấu phẩy: web, Android, iOS).
 */
@Component
public class GoogleTokenVerifierImpl implements GoogleTokenVerifier {

    private static final Logger log = LoggerFactory.getLogger(GoogleTokenVerifierImpl.class);

    private final List<String> clientIds;
    private volatile GoogleIdTokenVerifier verifier;

    public GoogleTokenVerifierImpl(@Value("${google.client-ids:${GOOGLE_CLIENT_IDS:}}") String clientIdsCsv) {
        this.clientIds = Arrays.stream(clientIdsCsv.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .toList();
        if (clientIds.isEmpty()) {
            log.warn("GOOGLE_CLIENT_IDS chưa được cấu hình: đăng nhập bằng Google sẽ không dùng được.");
        }
    }

    private GoogleIdTokenVerifier verifier() {
        GoogleIdTokenVerifier v = verifier;
        if (v == null) {
            synchronized (this) {
                v = verifier;
                if (v == null) {
                    v = new GoogleIdTokenVerifier.Builder(new NetHttpTransport(), GsonFactory.getDefaultInstance())
                            .setAudience(clientIds)
                            .build();
                    verifier = v;
                }
            }
        }
        return v;
    }

    @Override
    public GoogleIdentity verify(String idToken) {
        if (clientIds.isEmpty()) {
            throw new AppException(503, "Đăng nhập bằng Google chưa được cấu hình trên máy chủ");
        }
        try {
            GoogleIdToken token = verifier().verify(idToken);
            if (token == null) {
                throw new AppException(401, "Phiên đăng nhập Google không hợp lệ hoặc đã hết hạn");
            }
            GoogleIdToken.Payload p = token.getPayload();
            return new GoogleIdentity(
                    p.getSubject(),
                    p.getEmail(),
                    Boolean.TRUE.equals(p.getEmailVerified()),
                    (String) p.get("name"),
                    (String) p.get("picture"));
        } catch (AppException e) {
            throw e;
        } catch (Exception e) {
            log.warn("Không kiểm tra được Google ID token: {}", e.getClass().getSimpleName());
            throw new AppException(401, "Không xác thực được tài khoản Google, vui lòng thử lại");
        }
    }
}
