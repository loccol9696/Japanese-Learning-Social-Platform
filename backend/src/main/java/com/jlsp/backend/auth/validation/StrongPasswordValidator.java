package com.jlsp.backend.auth.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

import java.nio.charset.StandardCharsets;

public class StrongPasswordValidator implements ConstraintValidator<StrongPassword, String> {

    static final int MIN_LENGTH = 8;
    static final int MAX_BYTES = 72;

    @Override
    public boolean isValid(String value, ConstraintValidatorContext context) {
        if (value == null) {
            return true;
        }
        if (value.length() < MIN_LENGTH || value.getBytes(StandardCharsets.UTF_8).length > MAX_BYTES) {
            return false;
        }
        boolean hasLetter = false;
        boolean hasDigit = false;
        for (int i = 0; i < value.length(); ) {
            int codePoint = value.codePointAt(i);
            hasLetter |= Character.isLetter(codePoint);
            hasDigit |= Character.isDigit(codePoint);
            i += Character.charCount(codePoint);
        }
        return hasLetter && hasDigit;
    }
}
