package com.jlsp.backend.common.security;

import com.jlsp.backend.common.config.SecurityConfig;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.common.security.jwt.JwtUtils;
import com.jlsp.backend.subscription.controller.PaymentController;
import com.jlsp.backend.subscription.dto.request.CreateQrOrderRequest;
import com.jlsp.backend.subscription.service.SubscriptionService;
import com.jlsp.backend.user.controller.UserController;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.service.UserService;
import com.jlsp.backend.video.controller.VideoController;
import com.jlsp.backend.video.service.VideoService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Phân quyền ở chế độ PROD (app.security.enabled=true): danh tính chỉ lấy từ JWT. */
@WebMvcTest(controllers = {VideoController.class, UserController.class, PaymentController.class})
@Import(SecurityConfig.class)
@TestPropertySource(properties = "app.security.enabled=true")
class SecurityRulesTest {

    static final String USER_TOKEN = "user-token";
    static final String ADMIN_TOKEN = "admin-token";

    @Autowired
    MockMvc mvc;

    @MockitoBean
    VideoService videoService;
    @MockitoBean
    UserService userService;
    @MockitoBean
    SubscriptionService subscriptionService;
    @MockitoBean
    JwtUtils jwtUtils;
    @MockitoBean
    CustomUserDetailsService userDetailsService;

    @BeforeEach
    void setUpTokens() {
        stubToken(USER_TOKEN, user(42L, "alice", UserRole.USER));
        stubToken(ADMIN_TOKEN, user(1L, "admin", UserRole.ADMIN));
    }

    @Test
    void writeEndpointWithoutTokenReturns401Json() throws Exception {
        mvc.perform(post("/api/v1/videos/5/likes"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401));
        verify(videoService, never()).likeVideo(any(), any());
    }

    @Test
    void spoofedUserIdHeaderIsIgnored() throws Exception {
        mvc.perform(post("/api/v1/videos/5/likes").header("X-User-Id", "1"))
                .andExpect(status().isUnauthorized());
        verify(videoService, never()).likeVideo(any(), any());
    }

    @Test
    void writeEndpointUsesIdFromToken() throws Exception {
        mvc.perform(post("/api/v1/videos/5/likes")
                        .header("Authorization", "Bearer " + USER_TOKEN)
                        .param("currentUserId", "1"))
                .andExpect(status().isOk());
        verify(videoService).likeVideo(5L, 42L);
    }

    @Test
    void publicFeedAllowsGuestsWithNullViewer() throws Exception {
        when(videoService.getForYouFeed(isNull(), isNull(), any())).thenReturn(new PageResponse<>());
        mvc.perform(get("/api/v1/videos/feed/for-you"))
                .andExpect(status().isOk());
        verify(videoService).getForYouFeed(isNull(), isNull(), any());
    }

    @Test
    void adminEndpointRejectsRegularUser() throws Exception {
        mvc.perform(get("/api/v1/users/admin-list").header("Authorization", "Bearer " + USER_TOKEN))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/users/admin-list"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void adminEndpointAllowsAdmin() throws Exception {
        mvc.perform(get("/api/v1/users/admin-list").header("Authorization", "Bearer " + ADMIN_TOKEN))
                .andExpect(status().isOk());
    }

    @Test
    void userCannotEditAnotherUsersProfile() throws Exception {
        mvc.perform(put("/api/v1/users/7")
                        .header("Authorization", "Bearer " + USER_TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isForbidden());
        verify(userService, never()).updateUser(any(), any());
    }

    @Test
    void userCanEditOwnProfile() throws Exception {
        mvc.perform(put("/api/v1/users/42")
                        .header("Authorization", "Bearer " + USER_TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());
        verify(userService).updateUser(eq(42L), any());
    }

    @Test
    void createOrderIgnoresUserIdFromBody() throws Exception {
        mvc.perform(post("/api/v1/payments/create-order")
                        .header("Authorization", "Bearer " + USER_TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"planId\":2,\"userId\":1}"))
                .andExpect(status().isCreated());

        ArgumentCaptor<CreateQrOrderRequest> captor = ArgumentCaptor.forClass(CreateQrOrderRequest.class);
        verify(subscriptionService).createQrOrder(captor.capture());
        assertThat(captor.getValue().getUserId()).isEqualTo(42L);
    }

    @Test
    void lockedAccountTokenIsNotAuthenticated() throws Exception {
        User locked = user(43L, "locked", UserRole.USER);
        locked.setIsActive(false);
        stubToken("locked-token", locked);

        mvc.perform(post("/api/v1/videos/5/likes").header("Authorization", "Bearer locked-token"))
                .andExpect(status().isUnauthorized());
    }

    private void stubToken(String token, User user) {
        when(jwtUtils.validateToken(token)).thenReturn(true);
        when(jwtUtils.extractUsername(token)).thenReturn(user.getUsername());
        when(userDetailsService.loadUserByUsername(user.getUsername())).thenReturn(new CustomUserDetails(user));
    }

    private static User user(Long id, String username, UserRole role) {
        User u = new User();
        u.setId(id);
        u.setUsername(username);
        u.setRole(role);
        u.setIsActive(true);
        return u;
    }
}
