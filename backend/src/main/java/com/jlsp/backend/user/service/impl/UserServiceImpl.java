package com.jlsp.backend.user.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.user.dto.request.CreateUserRequest;
import com.jlsp.backend.user.dto.request.UpdateUserRequest;
import com.jlsp.backend.user.dto.response.UserResponse;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.mapper.UserMapper;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.user.service.UserService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import org.springframework.security.crypto.password.PasswordEncoder;
import com.jlsp.backend.user.dto.request.AdminCreateUserRequest;

@Service
@RequiredArgsConstructor
@Slf4j
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;
    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;
    private final com.jlsp.backend.user.repository.FollowRepository followRepository;
    private final com.jlsp.backend.video.repository.VideoRepository videoRepository;
    private final com.jlsp.backend.common.security.token.RefreshTokenService refreshTokenService;
    private final com.jlsp.backend.topic.service.TopicService topicService;

    @Override
    public UserResponse createUser(CreateUserRequest request) {
        return null;
    }

    @Override
    public UserResponse createPrivilegedUser(AdminCreateUserRequest request) {
        log.info("Admin creating user '{}' with role '{}'", request.getUsername(), request.getRole());

        if (userRepository.existsByUsername(request.getUsername())) {
            throw new AppException(400, "Username already exists: " + request.getUsername());
        }

        String email = (request.getEmail() != null && !request.getEmail().trim().isEmpty())
                ? request.getEmail().trim()
                : request.getUsername().trim() + "@jlsp.internal";

        if (userRepository.existsByEmail(email)) {
            throw new AppException(400, "Email already exists: " + email);
        }

        User user = User.builder()
                .username(request.getUsername())
                .email(email)
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .displayName(request.getDisplayName() != null && !request.getDisplayName().isBlank()
                        ? request.getDisplayName()
                        : request.getUsername())
                .role(request.getRole())
                .isActive(true) // Admin-created accounts are active immediately
                .avatarUrl("https://picsum.photos/seed/" + request.getUsername() + "/120/120")
                .build();

        User savedUser = userRepository.save(user);
        return userMapper.toResponse(savedUser);
    }

    @Override
    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public UserResponse getUserById(Long id) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new AppException(404, "User not found with id: " + id));
        UserResponse response = userMapper.toResponse(user);
        response.setTopics(topicsOf(user));
        enrichUserStats(response, id);
        return response;
    }

    @Override
    public UserResponse getUserByUsername(String username) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new AppException(404, "User not found with username: " + username));
        UserResponse response = userMapper.toResponse(user);
        enrichUserStats(response, user.getId());
        return response;
    }

    @Override
    public com.jlsp.backend.user.dto.response.PublicProfileResponse getPublicProfile(Long viewerId, Long id) {
        User user = userRepository.findById(id)
                .filter(u -> Boolean.TRUE.equals(u.getIsActive()))
                .orElseThrow(() -> new AppException(404, "Không tìm thấy người dùng"));
        UserResponse stats = userMapper.toResponse(user);
        enrichUserStats(stats, id);
        boolean isSelf = id.equals(viewerId);
        return com.jlsp.backend.user.dto.response.PublicProfileResponse.builder()
                .id(user.getId())
                .username(user.getUsername())
                .displayName(user.getDisplayName())
                .avatarUrl(user.getAvatarUrl())
                .jlptLevel(user.getJlptLevel())
                .bio(user.getBio())
                .followersCount(stats.getFollowersCount())
                .followingCount(stats.getFollowingCount())
                .likesCount(stats.getLikesCount())
                .videosCount(stats.getVideosCount())
                .isFollowing(!isSelf && viewerId != null
                        && followRepository.existsByIdFollowerIdAndIdFollowingId(viewerId, id))
                .isFollowedBy(!isSelf && viewerId != null
                        && followRepository.existsByIdFollowerIdAndIdFollowingId(id, viewerId))
                .isSelf(isSelf)
                .build();
    }

    private void enrichUserStats(UserResponse response, Long userId) {
        if (response == null || userId == null) return;
        try {
            response.setFollowingCount(followRepository.countByIdFollowerId(userId));
            response.setFollowersCount(followRepository.countByIdFollowingId(userId));
            response.setLikesCount(videoRepository.sumLikesByUserId(userId));
            response.setVideosCount(videoRepository.countByUserId(userId));
        } catch (Exception e) {
            log.warn("Failed to compute stats for user {}: {}", userId, e.getMessage());
        }
    }

    @Override
    public PageResponse<UserResponse> getAllUsers(Pageable pageable) {
        org.springframework.data.domain.Page<User> page = userRepository.findAll(pageable);
        return PageResponse.<UserResponse>builder()
                .content(page.getContent().stream().map(userMapper::toResponse).toList())
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .build();
    }

    @Override
    public PageResponse<com.jlsp.backend.user.dto.response.FollowUserResponse> searchPublicUsers(
            Long viewerId, String query, Pageable pageable) {
        String q = query == null ? "" : query.trim();
        if (q.length() < 2) {
            throw new AppException(400, "Từ khóa tìm kiếm phải có ít nhất 2 ký tự");
        }
        org.springframework.data.domain.Page<User> page = userRepository.searchActivePublic(q, pageable);

        java.util.Set<Long> followingIds = new java.util.HashSet<>(
                followRepository.findFollowingIdsByFollowerId(viewerId));
        java.util.Set<Long> followerIds = new java.util.HashSet<>(
                followRepository.findFollowerIdsByFollowingId(viewerId));
        return PageResponse.<com.jlsp.backend.user.dto.response.FollowUserResponse>builder()
                .content(page.getContent().stream()
                        .map(u -> com.jlsp.backend.user.dto.response.FollowUserResponse.builder()
                                .id(u.getId())
                                .username(u.getUsername())
                                .displayName(u.getDisplayName())
                                .avatarUrl(u.getAvatarUrl())
                                .jlptLevel(u.getJlptLevel())
                                .isFollowing(followingIds.contains(u.getId()))
                                .isFollowedBy(followerIds.contains(u.getId()))
                                .build())
                        .toList())
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .build();
    }

    @Override
    public PageResponse<UserResponse> searchUsers(String search, com.jlsp.backend.user.entity.UserRole role, Pageable pageable) {
        org.springframework.data.domain.Page<User> page = userRepository.searchUsers(search, role, pageable);
        return PageResponse.<UserResponse>builder()
                .content(page.getContent().stream().map(userMapper::toResponse).toList())
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .build();
    }

    @Override
    @org.springframework.transaction.annotation.Transactional
    public UserResponse toggleUserStatus(Long id) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new AppException(404, "User not found with id: " + id));
        user.setIsActive(!Boolean.TRUE.equals(user.getIsActive()));
        User saved = userRepository.save(user);
        if (!Boolean.TRUE.equals(saved.getIsActive())) {
            // Khoá tài khoản: đăng xuất ngay mọi thiết bị (access token còn lại tự hết hạn sau tối đa 30 phút).
            refreshTokenService.revokeAll(saved.getId());
        }
        log.info("Toggled user id {} status to isActive={}", id, saved.getIsActive());
        return userMapper.toResponse(saved);
    }

    @Override
    @org.springframework.transaction.annotation.Transactional
    public java.util.List<com.jlsp.backend.user.dto.response.GeneratedAccountDto> batchCreateAccounts(
            com.jlsp.backend.user.dto.request.AdminBatchCreateRequest request) {
        log.info("Admin batch creating {} accounts with role {}", request.getCount(), request.getRole());

        String prefix = request.getRole() == com.jlsp.backend.user.entity.UserRole.ADMIN ? "admin_" : "mod_";
        String dateStr = java.time.LocalDate.now().format(java.time.format.DateTimeFormatter.ofPattern("yyyyMMdd"));
        String basePrefix = prefix + dateStr + "_";

        long existingCount = userRepository.countByUsernameStartingWith(basePrefix);
        java.util.List<com.jlsp.backend.user.dto.response.GeneratedAccountDto> results = new java.util.ArrayList<>();
        java.security.SecureRandom random = new java.security.SecureRandom();
        String chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";

        for (int i = 1; i <= request.getCount(); i++) {
            long seq = existingCount + i;
            String username = String.format("%s%03d", basePrefix, seq);

            while (userRepository.existsByUsername(username)) {
                seq++;
                username = String.format("%s%03d", basePrefix, seq);
            }

            StringBuilder pwdBuilder = new StringBuilder("Pass@");
            for (int c = 0; c < 6; c++) {
                pwdBuilder.append(chars.charAt(random.nextInt(chars.length())));
            }
            String rawPassword = pwdBuilder.toString();
            String email = username + "@jlsp.internal";
            String roleName = request.getRole() == com.jlsp.backend.user.entity.UserRole.ADMIN ? "Admin " : "Moderator ";
            String displayName = roleName + String.format("%03d", seq);

            User user = User.builder()
                    .username(username)
                    .email(email)
                    .passwordHash(passwordEncoder.encode(rawPassword))
                    .displayName(displayName)
                    .role(request.getRole())
                    .isActive(true)
                    .avatarUrl("https://picsum.photos/seed/" + username + "/120/120")
                    .build();

            User saved = userRepository.save(user);

            results.add(com.jlsp.backend.user.dto.response.GeneratedAccountDto.builder()
                    .id(saved.getId())
                    .username(saved.getUsername())
                    .password(rawPassword)
                    .email(saved.getEmail())
                    .role(saved.getRole())
                    .displayName(saved.getDisplayName())
                    .build());
        }

        return results;
    }

    @Override
    @org.springframework.transaction.annotation.Transactional
    public UserResponse updateUser(Long id, UpdateUserRequest request) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new AppException(404, "User not found with id: " + id));
        applyUserUpdates(user, request);
        User saved = userRepository.save(user);
        UserResponse response = userMapper.toResponse(saved);
        response.setTopics(topicsOf(saved));
        enrichUserStats(response, id);
        return response;
    }

    @Override
    @org.springframework.transaction.annotation.Transactional
    public UserResponse updateProfileByUsername(String currentUsername, UpdateUserRequest request) {
        User user = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new AppException(404, "User not found with username: " + currentUsername));
        applyUserUpdates(user, request);
        User saved = userRepository.save(user);
        log.info("Updated profile for user {}", currentUsername);
        UserResponse response = userMapper.toResponse(saved);
        response.setTopics(topicsOf(saved));
        enrichUserStats(response, saved.getId());
        return response;
    }

    private void applyUserUpdates(User user, UpdateUserRequest request) {
        if (request.getUsername() != null && !request.getUsername().isBlank()) {
            String newUsername = request.getUsername().trim();
            if (!newUsername.equalsIgnoreCase(user.getUsername())) {
                if (userRepository.existsByUsername(newUsername)) {
                    throw new AppException(400, "Tên đăng nhập '" + newUsername + "' đã tồn tại!");
                }
                user.setUsername(newUsername);
            }
        }
        if (request.getEmail() != null && !request.getEmail().isBlank()) {
            String newEmail = request.getEmail().trim();
            if (!newEmail.equalsIgnoreCase(user.getEmail())) {
                if (userRepository.existsByEmail(newEmail)) {
                    throw new AppException(400, "Email '" + newEmail + "' đã tồn tại!");
                }
                user.setEmail(newEmail);
            }
        }
        if (request.getDisplayName() != null) user.setDisplayName(request.getDisplayName().trim());
        if (request.getBio() != null) user.setBio(request.getBio());
        if (request.getAvatarUrl() != null) {
            // Chuỗi rỗng nghĩa là người dùng xoá ảnh đại diện.
            String avatar = request.getAvatarUrl().trim();
            user.setAvatarUrl(avatar.isEmpty() ? null : avatar);
        }
        if (request.getEffectiveLevel() != null) user.setJlptLevel(request.getEffectiveLevel());
        if (request.getTopicIds() != null) {
            user.setTopics(topicService.requireActive(request.getTopicIds()));
        }
    }

    /** Sở thích đang hiển thị của người dùng, theo thứ tự hiển thị của chủ đề. */
    private java.util.List<com.jlsp.backend.topic.dto.TopicResponse> topicsOf(User user) {
        return user.getTopics().stream()
                .filter(t -> Boolean.TRUE.equals(t.getIsActive()))
                .sorted(java.util.Comparator
                        .comparing(com.jlsp.backend.topic.entity.Topic::getSortOrder)
                        .thenComparing(com.jlsp.backend.topic.entity.Topic::getId))
                .map(topicService::toResponse)
                .toList();
    }

    @Override
    public void deactivateUser(Long id) {
        toggleUserStatus(id);
    }
}