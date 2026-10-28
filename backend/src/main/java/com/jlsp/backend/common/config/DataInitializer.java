package com.jlsp.backend.common.config;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Khởi tạo dữ liệu mẫu người dùng (Admin, Creators, Learner) khi ứng dụng chạy lần đầu.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class DataInitializer implements CommandLineRunner {

    private final UserRepository userRepository;
    private final com.jlsp.backend.subscription.repository.SubscriptionPlanRepository subscriptionPlanRepository;
    private final org.springframework.jdbc.core.JdbcTemplate jdbcTemplate;
    private final org.springframework.security.crypto.password.PasswordEncoder passwordEncoder;

    // BCrypt hash của mật khẩu "password123"
    private static final String DEFAULT_PASSWORD_HASH = "$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKTVKIUi";

    @Override
    public void run(String... args) {
        migrateDatabaseColumns();
        seedSubscriptionPlans();
        ensureAdminAccount();

        if (userRepository.count() > 0) {
            log.info("Dữ liệu người dùng đã tồn tại trong database (tổng cộng {} users), bỏ qua bước khởi tạo.",
                    userRepository.count());
            return;
        }

        log.info("Bắt đầu khởi tạo dữ liệu mẫu cho Admin và các User...");

        User admin = User.builder()
                .username("admin")
                .email("admin@jlsp.com")
                .passwordHash(DEFAULT_PASSWORD_HASH) // password123
                .displayName("Hệ thống Quản trị (Admin)")
                .avatarUrl("https://picsum.photos/seed/admin88/200/200")
                .role(UserRole.ADMIN)
                .jlptLevel(JLPTLevel.N1)
                .bio("Tài khoản quản trị viên hệ thống JLSP")
                .isActive(true)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        User creatorTanaka = User.builder()
                .username("tanaka_sensei")
                .email("tanaka@jlsp.com")
                .passwordHash(DEFAULT_PASSWORD_HASH) // password123
                .displayName("Tanaka Sensei")
                .avatarUrl("https://picsum.photos/seed/tanaka/200/200")
                .role(UserRole.USER)
                .jlptLevel(JLPTLevel.N1)
                .bio("Giáo viên tiếng Nhật Tokyo, 10 năm kinh nghiệm luyện thi JLPT N2 - N1")
                .isActive(true)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        User creatorYamada = User.builder()
                .username("yamada_kaiwa")
                .email("yamada@jlsp.com")
                .passwordHash(DEFAULT_PASSWORD_HASH) // password123
                .displayName("Yamada Kaiwa")
                .avatarUrl("https://picsum.photos/seed/yamada/200/200")
                .role(UserRole.USER)
                .jlptLevel(JLPTLevel.N2)
                .bio("Chia sẻ hội thoại tiếng Nhật giao tiếp đời sống thực tế hàng ngày")
                .isActive(true)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        User learnerSakura = User.builder()
                .username("sakura_learner")
                .email("sakura@jlsp.com")
                .passwordHash(DEFAULT_PASSWORD_HASH) // password123
                .displayName("Sakura Chan")
                .avatarUrl("https://picsum.photos/seed/sakura/200/200")
                .role(UserRole.USER)
                .jlptLevel(JLPTLevel.N5)
                .bio("Người mới bắt đầu học tiếng Nhật! Mục tiêu đỗ JLPT N4 năm nay")
                .isActive(true)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        User modernLearner = User.builder()
                .username("modern_learner")
                .email("minedungytb@gmail.com")
                .passwordHash(DEFAULT_PASSWORD_HASH) // password123
                .displayName("Modern Learner")
                .avatarUrl("https://picsum.photos/seed/modern/200/200")
                .role(UserRole.USER)
                .jlptLevel(JLPTLevel.N4)
                .bio("Học viên hiện đại, yêu thích học tiếng Nhật theo phong cách hiện đại")
                .isActive(true)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        userRepository.saveAll(List.of(admin, creatorTanaka, creatorYamada, learnerSakura, modernLearner));
        log.info("==================================================================");
        log.info("Đã khởi tạo thành công 5 tài khoản mẫu vào database (Mật khẩu: password123):");
        log.info("  1. Admin:   admin          / password123 (Role: ADMIN)");
        log.info("  2. Creator: tanaka_sensei  / password123 (Role: USER)");
        log.info("  3. Creator: yamada_kaiwa   / password123 (Role: USER)");
        log.info("  4. Learner: sakura_learner / password123 (Role: USER)");
        log.info("  5. Learner: modern_learner / password123 (Role: USER)");
        log.info("==================================================================");
    }

    private void seedSubscriptionPlans() {
        if (subscriptionPlanRepository.count() > 0) {
            return;
        }

        log.info("Khởi tạo danh sách các gói VIP & Token Limit mặc định...");

        com.jlsp.backend.subscription.entity.SubscriptionPlan freePlan = com.jlsp.backend.subscription.entity.SubscriptionPlan.builder()
                .name("Gói Cơ Bản (Free)")
                .code("FREE")
                .price(java.math.BigDecimal.ZERO)
                .durationDays(9999)
                .dailyTokenLimit(50)
                .description("Dành cho người mới làm quen JLSP, giới hạn tính năng nâng cao")
                .features("Xem video giới hạn, 50 token AI/ngày, Flashcard cơ bản N5")
                .isActive(true)
                .build();

        com.jlsp.backend.subscription.entity.SubscriptionPlan proMonth = com.jlsp.backend.subscription.entity.SubscriptionPlan.builder()
                .name("JLSP Pro (1 Tháng)")
                .code("PRO_MONTHLY")
                .price(java.math.BigDecimal.valueOf(99000))
                .durationDays(30)
                .dailyTokenLimit(500)
                .description("Gói luyện tập chuyên sâu hàng tháng với AI Shadowing")
                .features("Trích xuất lời video không giới hạn, 500 token AI/ngày, Đầy đủ Flashcard N5-N1")
                .isActive(true)
                .build();

        com.jlsp.backend.subscription.entity.SubscriptionPlan proYear = com.jlsp.backend.subscription.entity.SubscriptionPlan.builder()
                .name("JLSP Mastery (1 Năm)")
                .code("PRO_YEARLY")
                .price(java.math.BigDecimal.valueOf(890000))
                .durationDays(365)
                .dailyTokenLimit(2000)
                .description("Tiết kiệm 25%, học tập toàn diện cùng cố vấn AI")
                .features("Tất cả quyền lợi Pro, 2,000 token AI/ngày, Ưu tiên hỗ trợ giáo viên 1-1")
                .isActive(true)
                .build();

        com.jlsp.backend.subscription.entity.SubscriptionPlan specialVip = com.jlsp.backend.subscription.entity.SubscriptionPlan.builder()
                .name("JLSP VIP Đặc Biệt (Lifetime Sensei)")
                .code("VIP_SPECIAL")
                .price(java.math.BigDecimal.valueOf(1990000))
                .durationDays(3650)
                .dailyTokenLimit(5000)
                .description("Gói đặc quyền cao cấp nhất dành cho Sensei và học viên chuyên sâu")
                .features("Không giới hạn trích xuất, 5,000 token AI/ngày, Huy hiệu VIP Hoàng Gia")
                .isActive(true)
                .build();

        subscriptionPlanRepository.saveAll(List.of(freePlan, proMonth, proYear, specialVip));
        log.info("Đã khởi tạo thành công 4 gói dịch vụ thành viên với cấu hình Token Limit!");
    }

    private void migrateDatabaseColumns() {
        try {
            log.info("Kiểm tra và thực hiện migration các cột database cần thiết...");

            // Cột cho bảng subscription_plans
            jdbcTemplate.execute("ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS code VARCHAR(50)");
            jdbcTemplate.execute("ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS daily_token_limit INTEGER DEFAULT 50");
            jdbcTemplate.execute("UPDATE subscription_plans SET code = 'FREE' WHERE id = 1 AND code IS NULL");
            jdbcTemplate.execute("UPDATE subscription_plans SET code = 'PRO_MONTHLY' WHERE id = 2 AND code IS NULL");
            jdbcTemplate.execute("UPDATE subscription_plans SET code = 'PRO_YEARLY' WHERE id = 3 AND code IS NULL");
            jdbcTemplate.execute("UPDATE subscription_plans SET code = 'VIP_SPECIAL' WHERE id = 4 AND code IS NULL");
            jdbcTemplate.execute("UPDATE subscription_plans SET duration_days = 30 WHERE code = 'PRO_MONTHLY'");
            jdbcTemplate.execute("UPDATE subscription_plans SET duration_days = 365 WHERE code = 'PRO_YEARLY'");

            // Đảm bảo luôn tồn tại gói FREE trong database để Admin cấu hình Token limit cho học viên miễn phí
            Integer freeCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM subscription_plans WHERE code = 'FREE'", Integer.class);
            if (freeCount == null || freeCount == 0) {
                jdbcTemplate.execute("INSERT INTO subscription_plans (name, code, price, duration_days, daily_token_limit, description, features, is_active, created_at, updated_at) " +
                        "VALUES ('Gói Miễn Phí (Mặc định)', 'FREE', 0, 99999, 50, 'Gói mặc định cho học viên mới, trích xuất lời và học tập cơ bản', 'Hạn mức 50 Token AI/ngày\nXem video bài học cơ bản\nFlashcard từ vựng N5', true, NOW(), NOW())");
                log.info("Đã khởi tạo gói 'FREE' mặc định trong database thành công!");
            }

            // Cột cho bảng videos (Video moderation)
            jdbcTemplate.execute("ALTER TABLE videos ADD COLUMN IF NOT EXISTS mod_status VARCHAR(20) DEFAULT 'APPROVED'");
            jdbcTemplate.execute("ALTER TABLE videos ADD COLUMN IF NOT EXISTS rejection_reason TEXT");
            jdbcTemplate.execute("ALTER TABLE videos ADD COLUMN IF NOT EXISTS moderated_by VARCHAR(50)");
            jdbcTemplate.execute("ALTER TABLE videos ADD COLUMN IF NOT EXISTS moderated_at TIMESTAMP");
            jdbcTemplate.execute("UPDATE videos SET mod_status = 'APPROVED' WHERE mod_status IS NULL");

            // Cột cho bảng users (VIP & Subscriptions)
            jdbcTemplate.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS vip_expires_at TIMESTAMP");
            jdbcTemplate.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS subscription_plan_id BIGINT");

            // Dọn dẹp triệt để bất kỳ dữ liệu mẫu giả nào (100% dữ liệu thực từ database)
            jdbcTemplate.execute("DELETE FROM subscription_orders WHERE order_code LIKE 'ORD-SEED%'");
            jdbcTemplate.execute("DELETE FROM user_daily_token_usage WHERE tokens_used IN (60, 120, 90, 210, 270, 330, 450)");

            // Bảng system_settings (Cấu hình hệ thống, mặc định 60 giây = 1 Token)
            jdbcTemplate.execute("CREATE TABLE IF NOT EXISTS system_settings (" +
                    "setting_key VARCHAR(100) PRIMARY KEY, " +
                    "setting_value VARCHAR(255) NOT NULL, " +
                    "description VARCHAR(255), " +
                    "updated_at TIMESTAMP)");
            jdbcTemplate.execute("INSERT INTO system_settings (setting_key, setting_value, description, updated_at) " +
                    "VALUES ('SECONDS_PER_TOKEN', '60', 'Thời lượng video cho 1 Token AI tính bằng giây', NOW()) " +
                    "ON CONFLICT (setting_key) DO NOTHING");

            log.info("Migration cột database thành công hoàn tất!");
        } catch (Exception e) {
            log.warn("Lưu ý trong quá trình migration cột database: {}", e.getMessage());
        }
    }

    private void ensureAdminAccount() {
        try {
            User admin = userRepository.findByUsername("admin")
                    .orElseGet(() -> userRepository.findByEmail("admin@jlsp.com").orElse(null));

            String encodedPassword = passwordEncoder.encode("AdminPassword123@");

            if (admin != null) {
                admin.setUsername("admin");
                admin.setEmail("admin@jlsp.com");
                admin.setPasswordHash(encodedPassword);
                admin.setRole(UserRole.ADMIN);
                admin.setIsActive(true);
                userRepository.save(admin);
                log.info("==> [SUCCESS] Đã đồng bộ tài khoản admin: username='admin', role=ADMIN, password=AdminPassword123@");
            } else {
                admin = User.builder()
                        .username("admin")
                        .email("admin@jlsp.com")
                        .passwordHash(encodedPassword)
                        .displayName("Hệ thống Quản trị (Admin)")
                        .avatarUrl("https://picsum.photos/seed/admin88/200/200")
                        .role(UserRole.ADMIN)
                        .jlptLevel(JLPTLevel.N1)
                        .bio("Tài khoản quản trị viên hệ thống JLSP")
                        .isActive(true)
                        .createdAt(LocalDateTime.now())
                        .updatedAt(LocalDateTime.now())
                        .build();
                userRepository.save(admin);
                log.info("==> [SUCCESS] Đã tạo mới tài khoản admin: username='admin', role=ADMIN, password=AdminPassword123@");
            }
        } catch (Exception e) {
            log.error("Lỗi khi đồng bộ tài khoản admin: {}", e.getMessage(), e);
        }
    }
}
