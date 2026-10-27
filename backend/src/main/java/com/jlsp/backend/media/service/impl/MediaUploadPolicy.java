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

    /** Chỉ nhận ảnh, video, âm thanh và giới hạn dung lượng theo loại. */
    static void validateFile(String contentType, long sizeBytes) {
        if (contentType == null || contentType.isBlank()) {
            throw new AppException(400, "Không xác định được loại file tải lên");
        }
        String type = contentType.trim().toLowerCase(Locale.ROOT);
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
