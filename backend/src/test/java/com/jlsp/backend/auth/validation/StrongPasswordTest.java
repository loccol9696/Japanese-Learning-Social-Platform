package com.jlsp.backend.auth.validation;

import com.jlsp.backend.auth.dto.request.ChangePasswordRequest;
import com.jlsp.backend.auth.dto.request.LoginRequest;
import com.jlsp.backend.auth.dto.request.RegisterRequest;
import com.jlsp.backend.auth.dto.request.ResetPasswordRequest;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class StrongPasswordTest {

    private final Validator validator = Validation.buildDefaultValidatorFactory().getValidator();
    private final StrongPasswordValidator rule = new StrongPasswordValidator();

    private boolean valid(String password) {
        return rule.isValid(password, null);
    }

    @Test
    void acceptsLettersAndDigitsFromEightCharacters() {
        assertThat(valid("abcd1234")).isTrue();
        assertThat(valid("Matkhau2026")).isTrue();
        assertThat(valid("p@ssw0rd!")).isTrue();
    }

    @Test
    void acceptsVietnameseAndJapaneseLetters() {
        assertThat(valid("Mậtkhẩu123")).isTrue();
        assertThat(valid("にほんご12345")).isTrue();
    }

    @Test
    void rejectsShortPasswords() {
        assertThat(valid("abc123")).isFalse();
        assertThat(valid("abcd123")).isFalse();
    }

    @Test
    void rejectsPasswordsMissingLettersOrDigits() {
        assertThat(valid("12345678")).isFalse();
        assertThat(valid("abcdefgh")).isFalse();
        assertThat(valid("!!!!!!!!!")).isFalse();
    }

    @Test
    void rejectsMoreThan72BytesNotJust72Characters() {
        assertThat(valid("a1".repeat(36))).isTrue();            // đúng 72 byte
        assertThat(valid("a1".repeat(36) + "b")).isFalse();     // 73 byte
        // 30 ký tự tiếng Nhật (3 byte mỗi ký tự) + 2 ký tự = 92 byte dù chỉ 32 ký tự
        assertThat(valid("あ".repeat(30) + "a1")).isFalse();
    }

    @Test
    void nullIsLeftToNotBlank() {
        assertThat(valid(null)).isTrue();
    }

    @Test
    void policyIsAppliedWhenRegisteringResettingAndChangingPassword() {
        RegisterRequest register = new RegisterRequest();
        register.setUsername("sakura");
        register.setEmail("sakura@example.com");
        register.setPassword("123456");
        assertThat(validator.validate(register))
                .anyMatch(v -> v.getPropertyPath().toString().equals("password"));

        ResetPasswordRequest reset = new ResetPasswordRequest();
        reset.setEmail("sakura@example.com");
        reset.setOtp("123456");
        reset.setNewPassword("abcdefgh");
        assertThat(validator.validate(reset))
                .anyMatch(v -> v.getPropertyPath().toString().equals("newPassword"));

        ChangePasswordRequest change = new ChangePasswordRequest();
        change.setOldPassword("old");
        change.setNewPassword("short1");
        assertThat(validator.validate(change))
                .anyMatch(v -> v.getPropertyPath().toString().equals("newPassword"));
    }

    @Test
    void loginStillAcceptsOldShortPasswordsSoExistingUsersCanSignIn() {
        LoginRequest login = new LoginRequest();
        login.setUsernameOrEmail("sakura");
        login.setPassword("abc123");

        assertThat(validator.validate(login)).isEmpty();
    }
}
