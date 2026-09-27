package com.jlsp.backend.common.exception;

import lombok.Getter;

@Getter
public class AppException extends RuntimeException {

    private final int status;

    public AppException(String message) {
        super(message);
        this.status = 400;
    }

    public AppException(int status, String message) {
        super(message);
        this.status = status;
    }
}
