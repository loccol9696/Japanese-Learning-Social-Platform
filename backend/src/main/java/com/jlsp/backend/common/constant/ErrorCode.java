package com.jlsp.backend.common.constant;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum ErrorCode {

    SUCCESS(200, "Success"),
    BAD_REQUEST(400, "Bad Request"),
    UNAUTHORIZED(401, "Unauthorized"),
    FORBIDDEN(403, "Access Denied"),
    RESOURCE_NOT_FOUND(404, "Resource Not Found"),
    DUPLICATE_RESOURCE(409, "Resource Already Exists"),
    INTERNAL_SERVER_ERROR(500, "Internal Server Error");

    private final int code;
    private final String defaultMessage;
}
