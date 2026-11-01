package com.jlsp.backend.auth.google;

/** Kiểm tra Google ID token do app gửi lên. */
public interface GoogleTokenVerifier {

    /**
     * @throws com.jlsp.backend.common.exception.AppException 401 nếu token sai, hết hạn hoặc không dành cho app này;
     *                                                        503 nếu server chưa cấu hình Google Client ID
     */
    GoogleIdentity verify(String idToken);
}
