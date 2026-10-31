package com.jlsp.backend.auth.dto;

import com.jlsp.backend.auth.dto.request.RegisterRequest;
import com.jlsp.backend.user.dto.request.UpdateUserRequest;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class RegisterRequestValidationTest {

    private final Validator validator = Validation.buildDefaultValidatorFactory().getValidator();

    private RegisterRequest request(String username, String displayName) {
        return RegisterRequest.builder()
                .username(username)
                .email("a@example.com")
                .password("matkhau123")
                .displayName(displayName)
                .build();
    }

    private boolean fails(RegisterRequest r, String field) {
        return validator.validate(r).stream().anyMatch(v -> v.getPropertyPath().toString().equals(field));
    }

    @Test
    void tenDangNhapDuocDungKyTuDacBietNhungKhongDuocCoKhoangTrang() {
        assertThat(fails(request("sakura.#_99!", null), "username")).isFalse();
        assertThat(fails(request("tên-đăng-nhập", null), "username")).isFalse();
        assertThat(fails(request("sa kura", null), "username")).isTrue();
    }

    @Test
    void hoVaTenChiGomChuCaiVaKhoangTrang() {
        assertThat(fails(request("sakura", "Nguyễn Văn An"), "displayName")).isFalse();
        assertThat(fails(request("sakura", "山田 太郎"), "displayName")).isFalse();
        assertThat(fails(request("sakura", ""), "displayName")).isFalse();
        assertThat(fails(request("sakura", null), "displayName")).isFalse();

        assertThat(fails(request("sakura", "An_99"), "displayName")).isTrue();
        assertThat(fails(request("sakura", "An@"), "displayName")).isTrue();
        assertThat(fails(request("sakura", "An  Binh"), "displayName")).isTrue();
        assertThat(fails(request("sakura", " An"), "displayName")).isTrue();
    }

    @Test
    void capNhatHoSoCungApDungQuyTacHoVaTen() {
        UpdateUserRequest ok = UpdateUserRequest.builder().displayName("Kenji Yamada").build();
        UpdateUserRequest bad = UpdateUserRequest.builder().displayName("Kenji!").build();

        assertThat(validator.validate(ok)).isEmpty();
        assertThat(validator.validate(bad)).hasSize(1);
    }
}
