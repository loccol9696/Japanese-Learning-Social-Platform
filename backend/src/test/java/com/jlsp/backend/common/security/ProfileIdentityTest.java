package com.jlsp.backend.common.security;

import com.jlsp.backend.common.config.SecurityConfig;
import com.jlsp.backend.common.security.jwt.JwtUtils;
import com.jlsp.backend.user.controller.ProfileController;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.service.UserService;
import com.jlsp.backend.video.service.VideoService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** /api/v1/profile chỉ thao tác trên hồ sơ của người dùng trong JWT (kể cả ở DEV). */
@WebMvcTest(controllers = ProfileController.class)
@Import(SecurityConfig.class)
@TestPropertySource(properties = "app.security.enabled=false")
class ProfileIdentityTest {

    @Autowired
    MockMvc mvc;

    @MockitoBean
    UserService userService;
    @MockitoBean
    VideoService videoService;
    @MockitoBean
    JwtUtils jwtUtils;
    @MockitoBean
    CustomUserDetailsService userDetailsService;

    @Test
    void userIdFromHeaderOrParamIsIgnoredWithoutToken() throws Exception {
        mvc.perform(get("/api/v1/profile").header("X-User-Id", "5"))
                .andExpect(status().isUnauthorized());
        mvc.perform(put("/api/v1/profile").param("userId", "5")
                        .contentType(MediaType.APPLICATION_JSON).content("{\"displayName\":\"hacked\"}"))
                .andExpect(status().isUnauthorized());

        for (String path : new String[]{"/api/v1/profile/stats", "/api/v1/profile/saved-videos", "/api/v1/profile/liked-videos"}) {
            mvc.perform(get(path).header("X-User-Id", "5").param("userId", "5"))
                    .andExpect(status().isUnauthorized());
        }

        verify(userService, never()).getUserById(anyLong());
        verify(userService, never()).getProfileStats(anyLong());
        verify(videoService, never()).getSavedVideos(anyLong(), any());
        verify(videoService, never()).getLikedVideos(anyLong(), any());
        verify(userService, never()).updateUser(anyLong(), any());
    }

    @Test
    void tokenUserIsUsedEvenIfAnotherIdIsSent() throws Exception {
        User user = new User();
        user.setId(42L);
        user.setUsername("alice");
        user.setRole(UserRole.USER);
        user.setIsActive(true);
        when(jwtUtils.validateToken("t")).thenReturn(true);
        when(jwtUtils.extractUsername("t")).thenReturn("alice");
        when(userDetailsService.loadUserByUsername("alice")).thenReturn(new CustomUserDetails(user));

        mvc.perform(put("/api/v1/profile").header("Authorization", "Bearer t").header("X-User-Id", "5")
                        .contentType(MediaType.APPLICATION_JSON).content("{\"displayName\":\"Alice\"}"))
                .andExpect(status().isOk());

        verify(userService).updateUser(eq(42L), any());
        verify(userService, never()).updateUser(eq(5L), any());
    }

    @Test
    void statsAndCollectionsUseTokenUser() throws Exception {
        User user = new User();
        user.setId(42L);
        user.setUsername("alice");
        user.setRole(UserRole.USER);
        user.setIsActive(true);
        when(jwtUtils.validateToken("t")).thenReturn(true);
        when(jwtUtils.extractUsername("t")).thenReturn("alice");
        when(userDetailsService.loadUserByUsername("alice")).thenReturn(new CustomUserDetails(user));

        mvc.perform(get("/api/v1/profile/stats").header("Authorization", "Bearer t")).andExpect(status().isOk());
        mvc.perform(get("/api/v1/profile/saved-videos").header("Authorization", "Bearer t")).andExpect(status().isOk());
        mvc.perform(get("/api/v1/profile/liked-videos").header("Authorization", "Bearer t")).andExpect(status().isOk());

        verify(userService).getProfileStats(42L);
        verify(videoService).getSavedVideos(eq(42L), any());
        verify(videoService).getLikedVideos(eq(42L), any());
    }
}
