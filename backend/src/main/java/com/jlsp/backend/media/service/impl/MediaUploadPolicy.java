package com.jlsp.backend.media.service.impl;

import com.jlsp.backend.common.exception.AppException;

import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Quy tắc cho file tải lên và thư mục Cloudinary, tách riêng để kiểm tra được mà không cần Cloudinary.
 */
final class MediaUploadPolicy {

    static final long MAX_IMAGE_BYTES = 10L * 1024 * 1024;
    /** Khớp giới hạn multipart của server (500MB). */
    static final long MAX_MEDIA_BYTES = 500L * 1024 * 1024;
    static final String DEFAULT_FOLDER = "jlsp";

    /** Thư mục phải nằm dưới "jlsp", tối đa 3 cấp con, chỉ gồm chữ, số, gạch dưới, gạch ngang. */
    private static final Pattern FOLDER = Pattern.compile("^jlsp(/[A-Za-z0-9_-]{1,50}){0,3}$");

    private MediaUploadPolicy() {
    }

    /** Tương thích với các gọi cũ / unit test. */
    static void validateFile(String contentType, long sizeBytes) {
        validateFile(contentType, null, sizeBytes, null);
    }

    /**
     * Kiểm tra file tải lên:
     * - Tự suy luận Content-Type từ tên file nếu client gửi "application/octet-stream" hoặc để trống.
     * - Nếu thư mục là video ("jlsp/videos"), chỉ cho phép tải lên video.
     */
    static void validateFile(String contentType, String filename, long sizeBytes, String folder) {
        String type = resolveContentType(contentType, filename);
        if (type == null || type.isBlank()) {
            throw new AppException(400, "Không xác định được loại file tải lên");
        }

        boolean isVideoFolder = folder != null && folder.trim().toLowerCase(Locale.ROOT).contains("video");
        if (isVideoFolder) {
            if (!type.startsWith("video/")) {
                throw new AppException(400, "Chỉ hỗ trợ tải lên tệp video");
            }
            if (sizeBytes > MAX_MEDIA_BYTES) {
                throw new AppException(413, "Video tối đa 500MB");
            }
            return;
        }

        if (type.startsWith("image/")) {
            if (sizeBytes > MAX_IMAGE_BYTES) {
                throw new AppException(413, "Ảnh tối đa 10MB");
            }
        } else if (type.startsWith("video/") || type.startsWith("audio/")) {
            if (sizeBytes > MAX_MEDIA_BYTES) {
                throw new AppException(413, "Video hoặc âm thanh tối đa 500MB");
            }
        } else {
            throw new AppException(415, "Chỉ hỗ trợ tải lên ảnh, video hoặc âm thanh");
        }
    }

    /**
     * Suy luận mime-type chuẩn. Khi client upload dạng multipart từ bytes,
     * header thường bị gửi là "application/octet-stream". Lúc này dựa vào đuôi file để nhận diện.
     */
    static String resolveContentType(String contentType, String filename) {
        String type = contentType != null ? contentType.trim().toLowerCase(Locale.ROOT) : "";
        if (!type.isBlank() && !"application/octet-stream".equals(type)) {
            return type;
        }
        if (filename != null && !filename.isBlank()) {
            String lower = filename.trim().toLowerCase(Locale.ROOT);
            int dot = lower.lastIndexOf('.');
            if (dot >= 0) {
                String ext = lower.substring(dot + 1);
                return switch (ext) {
                    case "mp4" -> "video/mp4";
                    case "mov" -> "video/quicktime";
                    case "webm" -> "video/webm";
                    case "avi" -> "video/x-msvideo";
                    case "mkv" -> "video/x-matroska";
                    case "flv" -> "video/x-flv";
                    case "jpg", "jpeg" -> "image/jpeg";
                    case "png" -> "image/png";
                    case "gif" -> "image/gif";
                    case "webp" -> "image/webp";
                    case "mp3" -> "audio/mpeg";
                    case "wav" -> "audio/wav";
                    case "m4a" -> "audio/mp4";
                    case "aac" -> "audio/aac";
                    case "ogg" -> "audio/ogg";
                    default -> type;
                };
            }
        }
        return type;
    }

    /** Thư mục trống thì dùng mặc định; ngoài ra phải hợp lệ, nếu không từ chối (không tự sửa lặng lẽ). */
    static String sanitizeFolder(String folder) {
        if (folder == null || folder.isBlank()) {
            return DEFAULT_FOLDER;
        }
        String trimmed = folder.trim();
        if (!FOLDER.matcher(trimmed).matches()) {
            throw new AppException(400, "Thư mục tải lên không hợp lệ");
        }
        return trimmed;
    }
}
