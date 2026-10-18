package com.jlsp.backend.common.exception;

import com.jlsp.backend.common.config.SecurityConfig;
import com.jlsp.backend.common.security.CustomUserDetails;
import com.jlsp.backend.common.security.CustomUserDetailsService;
import com.jlsp.backend.common.security.jwt.JwtUtils;
import com.jlsp.backend.subscription.controller.SubscriptionPlanController;
import com.jlsp.backend.subscription.service.SubscriptionService;
import com.jlsp.backend.subscription.service.SystemSettingService;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.video.controller.VideoController;
import com.jlsp.backend.video.service.VideoService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Lỗi phía client phải là 4xx có message rõ ràng; lỗi nội bộ là 500 không lộ chi tiết. */
@WebMvcTest(controllers = {VideoController.class, SubscriptionPlanController.class})
@Import(SecurityConfig.class)
@TestPropertySource(properties = "app.security.enabled=false")
class GlobalExceptionHandlerTest {

    static final String AUTH = "Bearer t";

    @Autowired
    MockMvc mvc;

    @MockitoBean
    VideoService videoService;
    @MockitoBean
    SubscriptionService subscriptionService;
    @MockitoBean
    SystemSettingService systemSettingService;
    @MockitoBean
    JwtUtils jwtUtils;
    @MockitoBean
    CustomUserDetailsService userDetailsService;

    @BeforeEach
    void login() {
        User user = new User();
        user.setId(42L);
        user.setUsername("alice");
        user.setRole(UserRole.USER);
        user.setIsActive(true);
        when(jwtUtils.validateToken("t")).thenReturn(true);
        when(jwtUtils.extractUsername("t")).thenReturn("alice");
        when(userDetailsService.loadUserByUsername("alice")).thenReturn(new CustomUserDetails(user));
    }

    @Test
    void malformedJsonReturns400() throws Exception {
        mvc.perform(put("/api/v1/videos/1").header("Authorization", AUTH)
                        .contentType(MediaType.APPLICATION_JSON).content("{not json"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));
    }

    @Test
    void invalidEnumQueryParamReturns400() throws Exception {
        mvc.perform(get("/api/v1/videos").param("jlptLevel", "N9"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("jlptLevel")));
    }

    @Test
    void wrongHttpMethodReturns405() throws Exception {
        mvc.perform(delete("/api/v1/videos/feed/for-you"))
                .andExpect(status().isMethodNotAllowed());
    }

    @Test
    void unexpectedErrorReturns500WithoutLeakingDetails() throws Exception {
        when(videoService.getVideoById(any(), any()))
                .thenThrow(new IllegalStateException("SQL: select * from users where password_hash = ..."));

        mvc.perform(get("/api/v1/videos/1"))
                .andExpect(status().isInternalServerError())
                .andExpect(content().string(not(containsString("password_hash"))));
    }

    @Test
    void patchVideoRejectsBlankTitle() throws Exception {
        mvc.perform(patch("/api/v1/videos/1").header("Authorization", AUTH)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"title\":\"\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.data.title").exists());
        verify(videoService, never()).updateVideo(any(), any(), any());
    }

    @Test
    void patchVideoAllowsPartialUpdate() throws Exception {
        mvc.perform(patch("/api/v1/videos/1").header("Authorization", AUTH)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"description\":\"mới\"}"))
                .andExpect(status().isOk());
    }

    @Test
    void tokenRateRejectsInvalidValueInsteadOfSilentDefault() throws Exception {
        mvc.perform(put("/api/v1/subscription-plans/token-rate").header("Authorization", AUTH)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"secondsPerToken\":0}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.data.secondsPerToken").exists());
        verify(systemSettingService, never()).setSecondsPerToken(anyInt());
    }
}
