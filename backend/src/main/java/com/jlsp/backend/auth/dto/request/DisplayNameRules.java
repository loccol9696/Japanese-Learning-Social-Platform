package com.jlsp.backend.auth.dto.request;

/** Họ và tên chỉ gồm chữ cái (có dấu, mọi ngôn ngữ), ngăn cách bằng một khoảng trắng; để trống thì dùng giá trị mặc định. */
public final class DisplayNameRules {

    public static final String REGEX = "^$|^[\\p{L}\\p{M}]+( [\\p{L}\\p{M}]+)*$";
    public static final String MESSAGE = "Họ và tên chỉ gồm chữ cái và khoảng trắng, không có ký tự đặc biệt";

    private DisplayNameRules() {
    }
}
