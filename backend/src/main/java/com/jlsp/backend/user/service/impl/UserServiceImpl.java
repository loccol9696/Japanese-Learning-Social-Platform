package com.jlsp.backend.user.service.impl;

import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.topic.entity.Topic;
import com.jlsp.backend.topic.repository.TopicRepository;
import com.jlsp.backend.user.dto.request.CreateUserRequest;
import com.jlsp.backend.user.dto.request.UpdateUserRequest;
import com.jlsp.backend.user.dto.response.UserResponse;
import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.user.entity.Role;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.mapper.UserMapper;
import com.jlsp.backend.user.repository.RoleRepository;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.user.service.UserService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final TopicRepository topicRepository;
    private final UserMapper userMapper;

    @Override
    @Transactional
    public UserResponse createUser(CreateUserRequest request) {
        Role defaultRole = roleRepository.findByRoleName("ROLE_USER")
                .orElseGet(() -> roleRepository.save(Role.builder().roleName("ROLE_USER").build()));

        User user = userMapper.toEntity(request, "DEFAULT_HASH");
        user.setRole(defaultRole);
        user.setRoleEnum(UserRole.USER);
        user.setCurrentLevel(request.getJlptLevel() != null ? request.getJlptLevel() : JLPTLevel.N5);

        User saved = userRepository.save(user);
        return userMapper.toResponse(saved);
    }

    @Override
    @Transactional(readOnly = true)
    public UserResponse getUserById(Long id) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + id));
        return userMapper.toResponse(user);
    }

    @Override
    @Transactional(readOnly = true)
    public UserResponse getUserByUsername(String username) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with username: " + username));
        return userMapper.toResponse(user);
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<UserResponse> getAllUsers(Pageable pageable) {
        Page<User> page = userRepository.findAll(pageable);
        List<UserResponse> content = page.getContent().stream()
                .map(userMapper::toResponse)
                .collect(Collectors.toList());

        return PageResponse.<UserResponse>builder()
                .content(content)
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .build();
    }

    @Override
    @Transactional
    public UserResponse updateUser(Long id, UpdateUserRequest request) {
        return updateProfile(id, request);
    }

    @Override
    @Transactional
    public void deactivateUser(Long id) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + id));
        user.setIsActive(false);
        user.setStatus("INACTIVE");
        userRepository.save(user);
    }

    @Override
    @Transactional
    public UserResponse getProfile(Long userId) {
        User user = resolveOrCreateUser(userId);
        return userMapper.toResponse(user);
    }

    @Override
    @Transactional
    public UserResponse updateProfile(Long userId, UpdateUserRequest request) {
        User user = resolveOrCreateUser(userId);

        if (request.getDisplayName() != null) {
            user.setDisplayName(request.getDisplayName().trim());
        }

        if (request.getAvatarUrl() != null) {
            user.setAvatarUrl(request.getAvatarUrl().trim());
        }

        JLPTLevel newLevel = request.getEffectiveLevel();
        if (newLevel != null) {
            user.setCurrentLevel(newLevel);
        }

        if (request.getBio() != null) {
            user.setBio(request.getBio().trim());
        }

        // Synchronize topics/interests
        boolean hasTopicIds = request.getTopicIds() != null && !request.getTopicIds().isEmpty();
        boolean hasInterests = request.getInterests() != null && !request.getInterests().isEmpty();

        if (hasTopicIds || hasInterests) {
            Set<Topic> updatedTopics = new HashSet<>();

            if (hasTopicIds) {
                List<Topic> byIds = topicRepository.findAllById(request.getTopicIds());
                updatedTopics.addAll(byIds);
            }

            if (hasInterests) {
                for (String interest : request.getInterests()) {
                    if (interest != null && !interest.trim().isEmpty()) {
                        String clean = interest.trim();
                        Topic topic = topicRepository.findByTopicNameIgnoreCase(clean)
                                .orElseGet(() -> topicRepository.save(Topic.builder().topicName(clean).build()));
                        updatedTopics.add(topic);
                    }
                }
            }

            user.setTopics(updatedTopics);
        }

        User updatedUser = userRepository.save(user);
        log.info("Updated profile for user {}: level={}, topicsCount={}",
                updatedUser.getId(), updatedUser.getCurrentLevel(), updatedUser.getTopics().size());

        return userMapper.toResponse(updatedUser);
    }

    private User resolveOrCreateUser(Long userId) {
        if (userId != null) {
            return userRepository.findById(userId)
                    .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + userId));
        }

        // Fallback: pick existing first active user or seed default demo user
        return userRepository.findAll().stream().findFirst().orElseGet(() -> {
            Role role = roleRepository.findByRoleName("ROLE_USER")
                    .orElseGet(() -> roleRepository.save(Role.builder().roleName("ROLE_USER").build()));

            User defaultUser = User.builder()
                    .username("jlsp_learner")
                    .email("learner@jlsp.com")
                    .passwordHash("DEMO_HASH")
                    .displayName("Nihongo Learner")
                    .avatarUrl("https://api.dicebear.com/7.x/bottts/png?seed=Kenji")
                    .currentLevel(JLPTLevel.N3)
                    .bio("Sayonara zetsubou sensei! Đang học tiếng Nhật hướng tới N2.")
                    .role(role)
                    .roleEnum(UserRole.USER)
                    .status("ACTIVE")
                    .isActive(true)
                    .build();

            return userRepository.save(defaultUser);
        });
    }
}
