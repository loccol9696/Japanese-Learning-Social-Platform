package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.video.entity.Hashtag;
import com.jlsp.backend.video.repository.HashtagRepository;
import com.jlsp.backend.video.service.HashtagRules;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Collection;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class HashtagServiceImplTest {

    private HashtagRepository repository;
    private HashtagServiceImpl service;

    @BeforeEach
    void setUp() {
        repository = mock(HashtagRepository.class);
        service = new HashtagServiceImpl(repository);
        when(repository.findByNameIn(any())).thenAnswer(inv -> {
            Collection<String> names = inv.getArgument(0);
            return names.stream().map(name -> Hashtag.builder().name(name).build()).toList();
        });
    }

    @Test
    void cacCachVietKhacNhauCuaMotTheDuocGopLam1() {
        var result = service.resolve(List.of("#Anime", "anime", " ＃ＡＮＩＭＥ "));

        assertThat(result).extracting(Hashtag::getName).containsExactly("anime");
        verify(repository).insertIfAbsent("anime");
    }

    @Test
    void giuNguyenDauTiengVietVaChuNhat() {
        assertThat(HashtagRules.normalize("#ĂnUống")).isEqualTo("ănuống");
        assertThat(HashtagRules.isValid("ănuống")).isTrue();
        assertThat(HashtagRules.isValid("日本語_n5")).isTrue();
        assertThat(HashtagRules.isValid("アニメー")).isTrue();
    }

    @Test
    void tuChoiTheChuaKhoangTrangHoacKyTuDacBiet() {
        assertThat(HashtagRules.isValid("ăn uống")).isFalse();
        assertThat(HashtagRules.isValid("c++")).isFalse();
        assertThat(HashtagRules.isValid("")).isFalse();
        assertThat(HashtagRules.isValid("a".repeat(HashtagRules.MAX_LENGTH + 1))).isFalse();

        assertThatThrownBy(() -> service.resolve(List.of("ăn uống"))).isInstanceOf(AppException.class);
    }

    @Test
    void theRongBiBoQuaThayViBaoLoi() {
        assertThat(service.resolve(List.of("", "  ", "#"))).isEmpty();
        verify(repository, never()).insertIfAbsent(any());
    }

    @Test
    void khongDuocVuotQuaNamThe() {
        assertThatThrownBy(() -> service.resolve(List.of("a", "b", "c", "d", "e", "f")))
                .isInstanceOf(AppException.class);
        verify(repository, never()).insertIfAbsent(any());
    }

    @Test
    void trungLapKhongTinhVaoGioiHan() {
        assertThat(service.resolve(List.of("a", "A", "#a", "b", "c", "d", "e"))).hasSize(5);
    }

    @Test
    void goiYThoatKyTuDacBietCuaLike() {
        service.suggest("#N_5%", 5);

        verify(repository).findPopular(eq("n\\_5\\%%"), eq(5));
    }

    @Test
    void goiYGioiHanSoKetQua() {
        service.suggest("", 1000);
        service.suggest("", 0);

        verify(repository).findPopular(eq("%"), eq(20));
        verify(repository).findPopular(eq("%"), eq(1));
        verify(repository, never()).findPopular(any(), eq(1000));
    }
}
