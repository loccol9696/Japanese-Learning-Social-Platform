package com.jlsp.backend.user.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.topic.dto.response.TopicResponse;
import com.jlsp.backend.user.dto.request.UpdateUserRequest;
import com.jlsp.backend.user.dto.response.UserResponse;
import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.user.service.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ProfileControllerTest {

    @Mock
    private UserService userService;

    @InjectMocks
    private ProfileController profileController;

    private UserResponse mockResponse;

    @BeforeEach
    void setUp() {
        mockResponse = UserResponse.builder()
                .userId(1L)
                .username("sakura_learner")
                .displayName("Sakura Learner")
                .avatarUrl("https://example.com/avatar.png")
                .currentLevel(JLPTLevel.N3)
                .jlptLevel(JLPTLevel.N3)
                .bio("Aiming for N2 this winter!")
                .topics(Arrays.asList(
                        TopicResponse.builder().id(1L).name("Anime & Manga").build(),
                        TopicResponse.builder().id(2L).name("JLPT Prep").build()
                ))
                .interests(new HashSet<>(Arrays.asList("Anime & Manga", "JLPT Prep")))
                .build();
    }

    @Test
    @DisplayName("getProfile should return user profile data")
    void getProfile_ReturnsSuccess() {
        when(userService.getProfile(1L)).thenReturn(mockResponse);

        ResponseEntity<ApiResponse<UserResponse>> response = profileController.getProfile(1L);

        assertNotNull(response);
        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals("Sakura Learner", response.getBody().getData().getDisplayName());
        assertEquals(JLPTLevel.N3, response.getBody().getData().getCurrentLevel());
        assertTrue(response.getBody().getData().getInterests().contains("Anime & Manga"));
        verify(userService, times(1)).getProfile(1L);
    }

    @Test
    @DisplayName("updateProfile should update user JLPT level and interests")
    void updateProfile_ReturnsUpdatedProfile() {
        Set<String> interests = new HashSet<>(Arrays.asList("Anime & Manga", "Giao tiếp hằng ngày"));
        UpdateUserRequest request = UpdateUserRequest.builder()
                .displayName("Sakura Pro")
                .currentLevel(JLPTLevel.N2)
                .interests(interests)
                .build();

        UserResponse updatedResponse = UserResponse.builder()
                .userId(1L)
                .displayName("Sakura Pro")
                .currentLevel(JLPTLevel.N2)
                .jlptLevel(JLPTLevel.N2)
                .interests(interests)
                .build();

        when(userService.updateProfile(eq(1L), any(UpdateUserRequest.class))).thenReturn(updatedResponse);

        ResponseEntity<ApiResponse<UserResponse>> response = profileController.updateProfile(1L, request);

        assertNotNull(response);
        assertEquals(200, response.getStatusCode().value());
        assertEquals("Profile updated successfully", response.getBody().getMessage());
        assertEquals(JLPTLevel.N2, response.getBody().getData().getCurrentLevel());
        assertEquals("Sakura Pro", response.getBody().getData().getDisplayName());
        assertEquals(2, response.getBody().getData().getInterests().size());
        verify(userService, times(1)).updateProfile(eq(1L), any(UpdateUserRequest.class));
    }
}
