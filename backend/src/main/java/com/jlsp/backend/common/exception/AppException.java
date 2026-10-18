package com.jlsp.backend.common.exception;

import com.jlsp.backend.common.constant.ErrorCode;
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

    public AppException(ErrorCode errorCode) {
        this(errorCode.getCode(), errorCode.getDefaultMessage());
    }

    public AppException(ErrorCode errorCode, String message) {
        this(errorCode.getCode(), message);
    }
}
