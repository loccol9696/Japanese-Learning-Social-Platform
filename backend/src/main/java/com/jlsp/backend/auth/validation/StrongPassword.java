package com.jlsp.backend.auth.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Mật khẩu mới: từ {@value StrongPasswordValidator#MIN_LENGTH} ký tự, tối đa
 * {@value StrongPasswordValidator#MAX_BYTES} byte (BCrypt chỉ dùng 72 byte đầu), có cả chữ và số.
 *
 * <p>Chỉ gắn cho nơi <b>đặt</b> mật khẩu (đăng ký, đặt lại, đổi). Không gắn cho đăng nhập để người đã có
 * mật khẩu cũ (ngắn hơn) vẫn vào được. {@code null} hợp lệ, hãy kết hợp với {@code @NotBlank}.
 */
@Documented
@Constraint(validatedBy = StrongPasswordValidator.class)
@Target({ElementType.FIELD, ElementType.PARAMETER})
@Retention(RetentionPolicy.RUNTIME)
public @interface StrongPassword {

    String message() default "Mật khẩu phải từ 8 đến 72 ký tự, gồm cả chữ và số";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
