package com.jlsp.backend.common.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.NOT_FOUND)
public class ResourceNotFoundException extends AppException {

    public ResourceNotFoundException(String resourceName, String fieldName, Object fieldValue) {
        super(404, String.format("%s not found with %s : '%s'", resourceName, fieldName, fieldValue));
    }

    public ResourceNotFoundException(String message) {
        super(404, message);
    }
}
