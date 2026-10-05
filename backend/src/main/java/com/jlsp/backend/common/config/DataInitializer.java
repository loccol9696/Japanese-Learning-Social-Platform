package com.jlsp.backend.common.config;

import com.jlsp.backend.topic.entity.Topic;
import com.jlsp.backend.topic.repository.TopicRepository;
import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.user.entity.Role;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.RoleRepository;
import com.jlsp.backend.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Component
@RequiredArgsConstructor
@Slf4j
public class DataInitializer implements CommandLineRunner {

    private final RoleRepository roleRepository;
    private final TopicRepository topicRepository;
    private final UserRepository userRepository;

    @Override
    public void run(String... args) {
        initRoles();
        initTopics();
        initDefaultUser();
    }

    private void initRoles() {
        List<String> roleNames = Arrays.asList("ROLE_USER", "ROLE_ADMIN", "ROLE_TEACHER");
        for (String name : roleNames) {
            if (!roleRepository.existsByRoleName(name)) {
                roleRepository.save(Role.builder().roleName(name).build());
                log.info("Initialized role: {}", name);
            }
        }
    }

    private void initTopics() {
        List<String> defaultTopics = Arrays.asList(
                "Anime & Manga",
                "Giao tiếp hằng ngày",
                "Luyện thi JLPT",
                "Văn hóa & Du lịch",
                "Âm nhạc J-Pop",
                "Ẩm thực Nhật Bản",
                "Kanji & Hán tự",
                "Công việc & IT",
                "Tin tức thời sự"
        );

        for (String topicName : defaultTopics) {
            if (!topicRepository.existsByTopicNameIgnoreCase(topicName)) {
                topicRepository.save(Topic.builder().topicName(topicName).build());
                log.info("Initialized topic: {}", topicName);
            }
        }
    }

    private void initDefaultUser() {
        if (userRepository.count() == 0) {
            Role userRole = roleRepository.findByRoleName("ROLE_USER")
                    .orElseGet(() -> roleRepository.save(Role.builder().roleName("ROLE_USER").build()));

            List<Topic> initialTopics = topicRepository.findAll().stream().limit(3).toList();
            Set<Topic> topicSet = new HashSet<>(initialTopics);

            User demoUser = User.builder()
                    .username("nihongo_pro")
                    .email("learner@jlsp.com")
                    .passwordHash("HASHED_PWD_DEMO")
                    .displayName("Sakura Learner")
                    .avatarUrl("https://api.dicebear.com/7.x/bottts/png?seed=Sakura")
                    .currentLevel(JLPTLevel.N3)
                    .bio("Xin chào! Mình đang học N3 để chuẩn bị đi du học Tokyo.")
                    .role(userRole)
                    .roleEnum(UserRole.USER)
                    .status("ACTIVE")
                    .isActive(true)
                    .topics(topicSet)
                    .build();

            userRepository.save(demoUser);
            log.info("Initialized demo user with id: {}", demoUser.getId());
        }
    }
}
