package com.jlsp.backend.common.security;

import com.jlsp.backend.common.config.SecurityConfig;
import com.jlsp.backend.common.security.jwt.JwtUtils;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.video.controller.VideoController;
import com.jlsp.backend.video.service.VideoService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** DEV (app.security.enabled=false): không chặn theo URL nhưng vẫn không có fallback user mặc định. */
@WebMvcTest(controllers = VideoController.class)
@Import(SecurityConfig.class)
@TestPropertySource(properties = "app.security.enabled=false")
class DevModeIdentityTest {

    @Autowired
    MockMvc mvc;

    @MockitoBean
    VideoService videoService;
    @MockitoBean
    JwtUtils jwtUtils;
    @MockitoBean
    CustomUserDetailsService userDetailsService;

    @Test
    void writeWithoutTokenReturns401InsteadOfActingAsUser1() throws Exception {
        mvc.perform(post("/api/v1/videos/5/saves").header("X-User-Id", "1"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401));
        verify(videoService, never()).saveVideo(any(), any());
    }

    @Test
    void tokenStillResolvesUserInDevMode() throws Exception {
        User user = new User();
        user.setId(42L);
        user.setUsername("alice");
        user.setRole(UserRole.USER);
        user.setIsActive(true);
        when(jwtUtils.validateToken("t")).thenReturn(true);
        when(jwtUtils.extractUsername("t")).thenReturn("alice");
        when(userDetailsService.loadUserByUsername("alice")).thenReturn(new CustomUserDetails(user));

        mvc.perform(post("/api/v1/videos/5/saves").header("Authorization", "Bearer t"))
                .andExpect(status().isOk());
        verify(videoService).saveVideo(5L, 42L);
    }
}
