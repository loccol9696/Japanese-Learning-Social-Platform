package com.jlsp.backend.auth.service.impl;

import com.jlsp.backend.auth.dto.request.LoginRequest;
import com.jlsp.backend.auth.dto.request.RegisterRequest;
import com.jlsp.backend.auth.dto.response.AuthResponse;
import com.jlsp.backend.auth.service.AuthService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthServiceImpl implements AuthService {

    @Override
    public AuthResponse register(RegisterRequest request) {
        return null;
    }

    @Override
    public AuthResponse login(LoginRequest request) {
        return null;
    }
}
