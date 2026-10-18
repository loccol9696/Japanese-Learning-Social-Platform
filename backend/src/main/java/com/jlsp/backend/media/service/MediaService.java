package com.jlsp.backend.media.service;

import com.jlsp.backend.media.dto.CloudinarySignatureResponse;
import com.jlsp.backend.media.dto.CloudinaryUploadResponse;
import org.springframework.web.multipart.MultipartFile;

/**
 * Interface nghiệp vụ xử lý Media và tải lên Cloudinary.
 */
public interface MediaService {

    /**
     * Sinh các thông số xác thực (signature, timestamp, apiKey, cloudName)
     * để Frontend có thể tải file trực tiếp lên Cloudinary.
     *
     * @param folder Thư mục lưu trên Cloudinary (tùy chọn)
     * @return CloudinarySignatureResponse
     */
    CloudinarySignatureResponse getUploadSignature(String folder);

    /**
     * Tải file trực tiếp từ Backend lên Cloudinary (hỗ trợ image, video, audio).
     *
     * @param file File multipart gửi từ client
     * @param folder Thư mục lưu trên Cloudinary (tùy chọn)
     * @return CloudinaryUploadResponse
     */
    CloudinaryUploadResponse uploadMedia(MultipartFile file, String folder);

    /**
     * Tải file đã lưu trên Cloudinary về backend để chạy xử lý AI.
     *
     * @param secureUrl URL HTTPS do Cloudinary trả về
     * @return nội dung file
     */
    byte[] downloadFromCloudinary(String secureUrl);
}
