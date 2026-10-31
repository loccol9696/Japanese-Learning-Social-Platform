package com.jlsp.backend.chat.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Chỉ nhận ảnh nằm trên tài khoản Cloudinary của hệ thống, để tin nhắn không thể trỏ
 * tới URL bất kỳ (theo dõi IP người nhận, nội dung ngoài kiểm soát).
 */
@Component
public class ChatImageValidator {

    private final String allowedPrefix;

    public ChatImageValidator(@Value("${cloudinary.cloud-name}") String cloudName) {
        this.allowedPrefix = "https://res.cloudinary.com/" + cloudName + "/image/upload/";
    }

    public boolean isValid(String imageUrl) {
        return imageUrl != null && imageUrl.startsWith(allowedPrefix);
    }
}
