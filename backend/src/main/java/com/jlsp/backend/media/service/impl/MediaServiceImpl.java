package com.jlsp.backend.media.service.impl;

import com.cloudinary.Cloudinary;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.media.dto.CloudinarySignatureResponse;
import com.jlsp.backend.media.dto.CloudinaryUploadResponse;
import com.jlsp.backend.media.service.MediaService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

/**
 * Cài đặt nghiệp vụ xử lý tải lên và sinh chữ ký Cloudinary.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class MediaServiceImpl implements MediaService {

    private final Cloudinary cloudinary;

    @Value("${cloudinary.cloud-name:}")
    private String cloudName;

    @Value("${cloudinary.api-key:}")
    private String apiKey;

    @Value("${cloudinary.api-secret:}")
    private String apiSecret;

    @Override
    public CloudinarySignatureResponse getUploadSignature(String folder) {
        validateCloudinaryConfig();

        long timestamp = System.currentTimeMillis() / 1000L;
        Map<String, Object> paramsToSign = new HashMap<>();
        paramsToSign.put("timestamp", timestamp);

        if (folder != null && !folder.isBlank()) {
            paramsToSign.put("folder", folder.trim());
        }

        String signature = cloudinary.apiSignRequest(paramsToSign, apiSecret.trim());

        log.debug("Sinh chữ ký Cloudinary thành công: timestamp={}, folder={}", timestamp, folder);

        return CloudinarySignatureResponse.builder()
                .signature(signature)
                .timestamp(timestamp)
                .apiKey(apiKey.trim())
                .cloudName(cloudName.trim())
                .folder(folder != null ? folder.trim() : null)
                .build();
    }

    @Override
    public CloudinaryUploadResponse uploadMedia(MultipartFile file, String folder) {
        validateCloudinaryConfig();

        if (file == null || file.isEmpty()) {
            throw new AppException(400, "File tải lên không được để trống");
        }

        try {
            Map<String, Object> uploadParams = new HashMap<>();
            uploadParams.put("resource_type", "auto");
            if (folder != null && !folder.isBlank()) {
                uploadParams.put("folder", folder.trim());
            }

            @SuppressWarnings("unchecked")
            Map<String, Object> uploadResult = cloudinary.uploader().upload(file.getBytes(), uploadParams);

            log.info("Upload file lên Cloudinary thành công: public_id={}, url={}",
                    uploadResult.get("public_id"), uploadResult.get("secure_url"));

            return CloudinaryUploadResponse.builder()
                    .url((String) uploadResult.get("url"))
                    .secureUrl((String) uploadResult.get("secure_url"))
                    .publicId((String) uploadResult.get("public_id"))
                    .resourceType((String) uploadResult.get("resource_type"))
                    .format((String) uploadResult.get("format"))
                    .bytes(uploadResult.get("bytes") instanceof Number ? ((Number) uploadResult.get("bytes")).longValue() : null)
                    .width(uploadResult.get("width") instanceof Number ? ((Number) uploadResult.get("width")).intValue() : null)
                    .height(uploadResult.get("height") instanceof Number ? ((Number) uploadResult.get("height")).intValue() : null)
                    .duration(uploadResult.get("duration") instanceof Number ? ((Number) uploadResult.get("duration")).doubleValue() : null)
                    .build();
        } catch (IOException e) {
            log.error("Lỗi khi đọc file để tải lên Cloudinary", e);
            throw new AppException(500, "Lỗi đọc dữ liệu file: " + e.getMessage());
        } catch (Exception e) {
            log.error("Lỗi khi tải file lên Cloudinary", e);
            throw new AppException(500, "Không thể tải file lên Cloudinary: " + e.getMessage());
        }
    }

    private void validateCloudinaryConfig() {
        if (cloudName == null || cloudName.isBlank()
                || apiKey == null || apiKey.isBlank()
                || apiSecret == null || apiSecret.isBlank()) {
            log.error("Cloudinary chưa được cấu hình đầy đủ (cloudName, apiKey, apiSecret)!");
            throw new AppException(500, "Cloudinary chưa được cấu hình đầy đủ trên hệ thống");
        }
    }
}
