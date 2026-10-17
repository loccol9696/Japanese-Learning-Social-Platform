package com.jlsp.backend.media.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.media.dto.ImageKitAuthResponse;
import com.jlsp.backend.media.service.MediaService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

/**
 * Cài đặt nghiệp vụ sinh thông số xác thực ImageKit sử dụng thuật toán HMAC-SHA1 thuần Java.
 */
@Service
@Slf4j
public class MediaServiceImpl implements MediaService {

    private static final String HMAC_SHA1 = "HmacSHA1";

    @Value("${imagekit.private-key:}")
    private String privateKey;

    /**
     * Sinh token, expire (30 phút) và signature HMAC-SHA1.
     */
    @Override
    public ImageKitAuthResponse getImageKitAuth() {
        if (privateKey == null || privateKey.isBlank()) {
            log.error("ImageKit private key chưa được cấu hình!");
            throw new AppException(500, "ImageKit private key chưa được cấu hình trên hệ thống");
        }

        String token = UUID.randomUUID().toString();
        // Thời hạn 30 phút tính bằng giây
        long expire = (System.currentTimeMillis() / 1000L) + 1800L;

        String dataToSign = token + expire;
        String signature = calculateHmacSha1(dataToSign, privateKey.trim());

        log.debug("Đã sinh ImageKit auth params thành công: token={}, expire={}", token, expire);

        return ImageKitAuthResponse.builder()
                .token(token)
                .expire(expire)
                .signature(signature)
                .build();
    }

    /**
     * Tính mã băm HMAC-SHA1 theo chuẩn của ImageKit.
     */
    private String calculateHmacSha1(String data, String key) {
        try {
            SecretKeySpec secretKeySpec = new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8), HMAC_SHA1);
            Mac mac = Mac.getInstance(HMAC_SHA1);
            mac.init(secretKeySpec);
            byte[] hashBytes = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));

            StringBuilder hexString = new StringBuilder();
            for (byte b : hashBytes) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) {
                    hexString.append('0');
                }
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (Exception e) {
            log.error("Lỗi khi sinh chữ ký HMAC-SHA1 cho ImageKit", e);
            throw new AppException(500, "Không thể sinh chữ ký xác thực ImageKit: " + e.getMessage());
        }
    }
}
