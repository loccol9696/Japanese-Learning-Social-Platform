package com.jlsp.backend.media.service.impl;

import com.cloudinary.Cloudinary;
import com.jlsp.backend.ai.service.SpeechToTextServiceIntf;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.media.dto.CloudinarySignatureResponse;
import com.jlsp.backend.media.dto.CloudinaryUploadResponse;
import com.jlsp.backend.media.service.MediaService;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.URI;
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

    private final SpeechToTextServiceIntf speechToTextService;
    private final RestTemplate restTemplate = new RestTemplate();

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

        // Chữ ký cho phép client tự upload vào đúng thư mục này, nên thư mục phải được kiểm tra.
        String safeFolder = MediaUploadPolicy.sanitizeFolder(folder);
        paramsToSign.put("folder", safeFolder);

        String signature = cloudinary.apiSignRequest(paramsToSign, apiSecret.trim());

        log.debug("Sinh chữ ký Cloudinary thành công: timestamp={}, folder={}", timestamp, folder);

        return CloudinarySignatureResponse.builder()
                .signature(signature)
                .timestamp(timestamp)
                .apiKey(apiKey.trim())
                .cloudName(cloudName.trim())
                .folder(safeFolder)
                .build();
    }

    @Override
    public CloudinaryUploadResponse uploadMedia(MultipartFile file, String folder) {
        validateCloudinaryConfig();

        if (file == null || file.isEmpty()) {
            throw new AppException(400, "File tải lên không được để trống");
        }
        MediaUploadPolicy.validateFile(file.getContentType(), file.getSize());
        String safeFolder = MediaUploadPolicy.sanitizeFolder(folder);

        try {
            Map<String, Object> uploadParams = new HashMap<>();
            uploadParams.put("resource_type", "auto");
            uploadParams.put("folder", safeFolder);

            // Đọc file một lần, dùng lại cho cả Cloudinary và nhận dạng giọng nói bên dưới.
            byte[] fileBytes = file.getBytes();
            @SuppressWarnings("unchecked")
            Map<String, Object> uploadResult = cloudinary.uploader().upload(fileBytes, uploadParams);
            String secureUrl = (String) uploadResult.get("secure_url");
            String aiTaskId = null;
            String aiStatus = "NOT_STARTED";

            if ("video".equals(uploadResult.get("resource_type"))
                    && secureUrl != null && !secureUrl.isBlank()) {
                try {
                    // Trước đây tải lại toàn bộ video vừa upload từ Cloudinary (tới 500MB) chỉ để lấy
                    // đúng nội dung mình đã có trong tay.
                    aiTaskId = java.util.UUID.randomUUID().toString();
                    speechToTextService.processAudioAsync(
                            aiTaskId,
                            fileBytes,
                            file.getOriginalFilename());
                    aiStatus = "PROCESSING";
                } catch (Exception aiException) {
                    log.error("Không thể khởi động AI cho file Cloudinary {}", secureUrl, aiException);
                    aiStatus = "FAILED_TO_START";
                }
            }

            log.info("Upload file lên Cloudinary thành công: public_id={}, url={}",
                    uploadResult.get("public_id"), secureUrl);

            return CloudinaryUploadResponse.builder()
                    .url((String) uploadResult.get("url"))
                    .secureUrl(secureUrl)
                    .publicId((String) uploadResult.get("public_id"))
                    .resourceType((String) uploadResult.get("resource_type"))
                    .format((String) uploadResult.get("format"))
                    .bytes(uploadResult.get("bytes") instanceof Number
                            ? ((Number) uploadResult.get("bytes")).longValue()
                            : null)
                    .width(uploadResult.get("width") instanceof Number ? ((Number) uploadResult.get("width")).intValue()
                            : null)
                    .height(uploadResult.get("height") instanceof Number
                            ? ((Number) uploadResult.get("height")).intValue()
                            : null)
                    .duration(uploadResult.get("duration") instanceof Number
                            ? ((Number) uploadResult.get("duration")).doubleValue()
                            : null)
                    .aiTaskId(aiTaskId)
                    .aiStatus(aiStatus)
                    .build();
        } catch (IOException e) {
            log.error("Lỗi khi đọc file để tải lên Cloudinary", e);
            throw new AppException(500, "Lỗi đọc dữ liệu file: " + e.getMessage());
        } catch (Exception e) {
            log.error("Lỗi khi tải file lên Cloudinary", e);
            throw new AppException(500, "Không thể tải file lên Cloudinary: " + e.getMessage());
        }
    }

    @Override
    public byte[] downloadFromCloudinary(String secureUrl) {
        if (secureUrl == null || secureUrl.isBlank()) {
            throw new AppException(400, "Cloudinary URL không được để trống");
        }

        URI uri;
        try {
            uri = URI.create(secureUrl.trim());
        } catch (IllegalArgumentException e) {
            throw new AppException(400, "Cloudinary URL không hợp lệ");
        }

        if (!"https".equalsIgnoreCase(uri.getScheme())
                || uri.getHost() == null
                || !(uri.getHost().equals("cloudinary.com")
                        || uri.getHost().endsWith(".cloudinary.com"))) {
            throw new AppException(400, "Chỉ cho phép tải file từ Cloudinary HTTPS");
        }

        ResponseEntity<byte[]> response = restTemplate.exchange(
                uri,
                HttpMethod.GET,
                HttpEntity.EMPTY,
                byte[].class);

        if (!response.getStatusCode().is2xxSuccessful()
                || response.getBody() == null
                || response.getBody().length == 0) {
            throw new AppException(502, "Không thể tải video từ Cloudinary");
        }

        return response.getBody();
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
