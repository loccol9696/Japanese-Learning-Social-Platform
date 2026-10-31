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
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Cài đặt nghiệp vụ xử lý tải lên và sinh chữ ký Cloudinary.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class MediaServiceImpl implements MediaService {

    /** /{cloud}/{image|video}/upload/[biến đổi/]v{version}/{public_id}.{đuôi} */
    private static final Pattern CLOUDINARY_PATH =
            Pattern.compile("^/[^/]+/(image|video)/upload/(?:.+?/)?v\\d+/(.+?)(?:\\.[^./]+)?$");

    private final Cloudinary cloudinary;

    /** Video YouTube tối đa 10 phút. */
    private static final int MAX_YOUTUBE_SECONDS = 10 * 60;
    private static final String YOUTUBE_FOLDER = "jlsp/videos";

    private final SpeechToTextServiceIntf speechToTextService;
    private final YoutubeDownloadClient youtubeDownloadClient;
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
        String safeFolder = MediaUploadPolicy.sanitizeFolder(folder);
        MediaUploadPolicy.validateFile(file.getContentType(), file.getOriginalFilename(), file.getSize(), safeFolder);

        byte[] fileBytes;
        try {
            // Đọc file một lần, dùng lại cho cả Cloudinary và nhận dạng giọng nói bên dưới.
            fileBytes = file.getBytes();
        } catch (IOException e) {
            log.error("Lỗi khi đọc file để tải lên Cloudinary", e);
            throw new AppException(500, "Lỗi đọc dữ liệu file: " + e.getMessage());
        }
        return uploadBytes(fileBytes, file.getOriginalFilename(), safeFolder);
    }

    @Override
    public CloudinaryUploadResponse importFromYoutube(String youtubeUrl) {
        validateCloudinaryConfig();

        YoutubeDownloadClient.DownloadedVideo video =
                youtubeDownloadClient.download(youtubeUrl, MAX_YOUTUBE_SECONDS);
        log.info("Đã tải video YouTube {} ({} KB, {}s)",
                video.videoId(), video.bytes().length / 1024, video.durationSeconds());

        String filename = (video.videoId() != null && !video.videoId().isBlank()
                ? "youtube-" + video.videoId() : "youtube") + ".mp4";
        CloudinaryUploadResponse response = uploadBytes(video.bytes(), filename, YOUTUBE_FOLDER);
        response.setTitle(video.title());
        if (response.getDuration() == null && video.durationSeconds() != null) {
            response.setDuration(video.durationSeconds().doubleValue());
        }
        return response;
    }

    /** Upload bytes lên Cloudinary; nếu là video thì chạy AI tạo phụ đề ở nền. */
    private CloudinaryUploadResponse uploadBytes(byte[] fileBytes, String filename, String safeFolder) {
        try {
            Map<String, Object> uploadParams = new HashMap<>();
            uploadParams.put("resource_type", "auto");
            uploadParams.put("folder", safeFolder);

            @SuppressWarnings("unchecked")
            Map<String, Object> uploadResult = cloudinary.uploader().upload(fileBytes, uploadParams);
            String secureUrl = (String) uploadResult.get("secure_url");
            String aiTaskId = null;
            String aiStatus = "NOT_STARTED";

            if ("video".equals(uploadResult.get("resource_type"))
                    && secureUrl != null && !secureUrl.isBlank()) {
                try {
                    aiTaskId = java.util.UUID.randomUUID().toString();
                    speechToTextService.processAudioAsync(
                            aiTaskId,
                            fileBytes,
                            filename);
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

    @Override
    public void deleteByUrl(String url) {
        CloudinaryAsset asset = parseCloudinaryUrl(url);
        if (asset == null) {
            return;
        }
        try {
            Map<String, Object> options = new HashMap<>();
            options.put("resource_type", asset.resourceType());
            options.put("invalidate", true);
            Object result = cloudinary.uploader().destroy(asset.publicId(), options).get("result");
            log.info("Gỡ file Cloudinary public_id={}: {}", asset.publicId(), result);
        } catch (Exception e) {
            log.warn("Không thể gỡ file Cloudinary public_id={}", asset.publicId(), e);
        }
    }

    /** Tách resource_type và public_id từ URL Cloudinary; null nếu không phải URL Cloudinary. */
    static CloudinaryAsset parseCloudinaryUrl(String url) {
        if (url == null || url.isBlank()) {
            return null;
        }
        try {
            URI uri = URI.create(url.trim());
            String host = uri.getHost();
            if (host == null || !(host.equals("cloudinary.com") || host.endsWith(".cloudinary.com"))) {
                return null;
            }
            Matcher matcher = CLOUDINARY_PATH.matcher(uri.getPath());
            return matcher.matches() ? new CloudinaryAsset(matcher.group(1), matcher.group(2)) : null;
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    record CloudinaryAsset(String resourceType, String publicId) {
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
