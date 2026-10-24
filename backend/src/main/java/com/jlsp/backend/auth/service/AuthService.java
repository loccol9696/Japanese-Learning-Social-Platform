package com.jlsp.backend.auth.service;

import com.jlsp.backend.auth.dto.request.ChangePasswordRequest;
import com.jlsp.backend.auth.dto.request.LoginRequest;
import com.jlsp.backend.auth.dto.request.RegisterRequest;
import com.jlsp.backend.auth.dto.request.ResetPasswordRequest;
import com.jlsp.backend.auth.dto.response.AuthResponse;
import com.jlsp.backend.otp.dto.ResendOtpRequest;
import com.jlsp.backend.otp.dto.VerifyOtpRequest;

public interface AuthService {

    /** Tạo tài khoản chưa kích hoạt và gửi OTP xác thực email. */
    AuthResponse register(RegisterRequest request);

    /** Trả về access token + refresh token. */
    AuthResponse login(LoginRequest request);

    /** Đổi refresh token lấy cặp token mới (refresh token cũ bị vô hiệu). */
    AuthResponse refresh(String refreshToken);

    /** Thu hồi refresh token của thiết bị này và access token đang dùng (nếu có). */
    void logout(String accessToken, String refreshToken);

    void verifyOtp(VerifyOtpRequest request);

    void resendOtp(ResendOtpRequest request);

    /** Gửi OTP đặt lại mật khẩu nếu email thuộc một tài khoản đã kích hoạt. */
    void forgotPassword(String email);

    void resetPassword(ResetPasswordRequest request);

    /** Đổi mật khẩu, thu hồi mọi phiên khác và trả cặp token mới cho thiết bị hiện tại. */
    AuthResponse changePassword(Long userId, ChangePasswordRequest request);
}
