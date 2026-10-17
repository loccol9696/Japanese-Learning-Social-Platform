package com.jlsp.backend.auth.service;

import com.jlsp.backend.auth.dto.request.LoginRequest;
import com.jlsp.backend.auth.dto.request.RegisterRequest;
import com.jlsp.backend.auth.dto.response.AuthResponse;
import com.jlsp.backend.otp.dto.ResendOtpRequest;
import com.jlsp.backend.otp.dto.VerifyOtpRequest;

public interface AuthService {

    AuthResponse register(RegisterRequest request);

    AuthResponse login(LoginRequest request);

    void verifyOtp(VerifyOtpRequest request);

    void resendOtp(ResendOtpRequest request);
}
