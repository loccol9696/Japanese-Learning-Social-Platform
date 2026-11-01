package com.jlsp.backend.common.config;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
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
    private final com.jlsp.backend.topic.repository.TopicRepository topicRepository;
    private final org.springframework.jdbc.core.JdbcTemplate jdbcTemplate;
    private final AdminAccountSeeder adminAccountSeeder;
    private final org.springframework.core.env.Environment environment;
    private final PasswordEncoder passwordEncoder;

    // BCrypt hash của mật khẩu "password123"
    private static final String DEFAULT_PASSWORD_HASH = "$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKTVKIUi";

    @Override
    public void run(String... args) {
        migrateDatabaseColumns();
        seedSubscriptionPlans();
        seedTopics();
        adminAccountSeeder.seed();

        // Tài khoản mẫu dùng mật khẩu công khai "password123" nên chỉ được tạo ở môi trường dev.
        if (!environment.acceptsProfiles(org.springframework.core.env.Profiles.of("dev"))) {
            return;
        }
        ensureAdminAccount();
        ensureModeratorAccount();

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

    /** Chủ đề mặc định, chỉ tạo khi bảng còn trống (giữ nguyên thứ tự / id 1..9 như danh sách cũ). */
    private void seedTopics() {
        if (topicRepository.count() > 0) {
            return;
        }
        List<String> names = List.of(
                "Anime & Manga", "Giao tiếp hằng ngày", "Luyện thi JLPT", "Văn hóa & Du lịch",
                "Âm nhạc J-Pop", "Ẩm thực Nhật Bản", "Kanji & Hán tự", "Công việc & IT", "Tin tức thời sự");
        for (int i = 0; i < names.size(); i++) {
            topicRepository.save(com.jlsp.backend.topic.entity.Topic.builder()
                    .name(names.get(i))
                    .sortOrder(i + 1)
                    .build());
        }
        log.info("Đã khởi tạo {} chủ đề mặc định.", names.size());
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
                .dailyTokenLimit(2000)
                .description("Linh hoạt trải nghiệm, 2.000 Token AI/ngày với đầy đủ tính năng Premium")
                .features("2.000 token AI/ngày, Trích xuất lời video không giới hạn, Đầy đủ Flashcard N5-N1")
                .isActive(true)
                .build();

        com.jlsp.backend.subscription.entity.SubscriptionPlan proYear = com.jlsp.backend.subscription.entity.SubscriptionPlan.builder()
                .name("JLSP Mastery (12 Tháng)")
                .code("PRO_YEARLY")
                .price(java.math.BigDecimal.valueOf(699000))
                .durationDays(365)
                .dailyTokenLimit(2000)
                .description("Tiết kiệm 41%, 2.000 Token AI/ngày, học tập toàn diện cùng AI")
                .features("Tất cả quyền lợi Premium, 2.000 token AI/ngày, Tiết kiệm 41% (~58k/tháng)")
                .isActive(true)
                .build();

        com.jlsp.backend.subscription.entity.SubscriptionPlan pro2Years = com.jlsp.backend.subscription.entity.SubscriptionPlan.builder()
                .name("JLSP Mastery Plus (2 Năm)")
                .code("PRO_2YEARS")
                .price(java.math.BigDecimal.valueOf(1290000))
                .durationDays(730)
                .dailyTokenLimit(2000)
                .description("Tiết kiệm tối đa 45%, 2.000 Token AI/ngày, cam kết đồng hành dài hạn")
                .features("Tất cả quyền lợi Premium, 2.000 token AI/ngày, Tiết kiệm 45% (~53k/tháng), Huy hiệu Mastery Plus")
                .isActive(true)
                .build();

        subscriptionPlanRepository.saveAll(List.of(freePlan, proMonth, proYear, pro2Years));
        log.info("Đã khởi tạo thành công 3 gói VIP chuẩn (1 Tháng, 1 Năm, 2 Năm) và gói FREE!");
    }

    private void migrateDatabaseColumns() {
        try {
            log.info("Kiểm tra và thực hiện migration các cột database cần thiết...");

            // Cột cho bảng subscription_plans
            jdbcTemplate.execute("ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS code VARCHAR(50)");
            jdbcTemplate.execute("ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS daily_token_limit INTEGER DEFAULT 50");
            // Cập nhật cấu hình 3 gói VIP chuẩn (1 Tháng: 99k, 1 Năm: 699k, 2 Năm: 1.290k) và mức token 2000 token/ngày
            jdbcTemplate.execute("UPDATE subscription_plans SET daily_token_limit = 2000 WHERE code IN ('PRO_MONTHLY', 'PRO_YEARLY', 'PRO_2YEARS')");
            jdbcTemplate.execute("UPDATE subscription_plans SET price = 1290000, duration_days = 730, daily_token_limit = 2000, name = 'JLSP Mastery Plus (2 Năm)', description = 'Tiết kiệm tối đa 45%, 2.000 Token AI/ngày, cam kết đồng hành dài hạn', features = 'Tất cả quyền lợi Premium, 2.000 token AI/ngày, Tiết kiệm 45% (~53k/tháng), Huy hiệu Mastery Plus', is_active = true WHERE code = 'PRO_2YEARS'");
            jdbcTemplate.execute("UPDATE subscription_plans SET price = 699000, duration_days = 365, daily_token_limit = 2000, name = 'JLSP Mastery (12 Tháng)', description = 'Tiết kiệm 41%, 2.000 Token AI/ngày, học tập toàn diện cùng AI', features = 'Tất cả quyền lợi Premium, 2.000 token AI/ngày, Tiết kiệm 41% (~58k/tháng)', is_active = true WHERE code = 'PRO_YEARLY'");
            jdbcTemplate.execute("UPDATE subscription_plans SET price = 99000, duration_days = 30, daily_token_limit = 2000, name = 'JLSP Pro (1 Tháng)', description = 'Linh hoạt trải nghiệm, 2.000 Token AI/ngày với đầy đủ tính năng Premium', features = '2.000 token AI/ngày, Trích xuất lời video không giới hạn, Đầy đủ Flashcard N5-N1', is_active = true WHERE code = 'PRO_MONTHLY'");
            jdbcTemplate.execute("UPDATE subscription_plans SET is_active = false WHERE code IN ('VIP_SPECIAL', 'PRO_QUARTERLY', 'TEST_2K')");
            jdbcTemplate.execute("UPDATE users SET subscription_plan_id = NULL, vip_expires_at = NULL WHERE id = 3");

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
            jdbcTemplate.execute("ALTER TABLE videos DROP CONSTRAINT IF EXISTS videos_status_check");
            jdbcTemplate.execute("ALTER TABLE videos DROP CONSTRAINT IF EXISTS videos_mod_status_check");

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

            // Bảng reports (Báo cáo vi phạm nội dung)
            jdbcTemplate.execute("CREATE TABLE IF NOT EXISTS reports (" +
                    "id BIGSERIAL PRIMARY KEY, " +
                    "reporter_id BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE, " +
                    "target_type VARCHAR(20) NOT NULL, " +
                    "target_id BIGINT NOT NULL, " +
                    "reason VARCHAR(30) NOT NULL, " +
                    "detail VARCHAR(500), " +
                    "status VARCHAR(20) NOT NULL DEFAULT 'PENDING', " +
                    "action VARCHAR(20), " +
                    "resolved_by BIGINT, " +
                    "resolved_at TIMESTAMP, " +
                    "resolution_note VARCHAR(500), " +
                    "created_at TIMESTAMP NOT NULL)");

            jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_reports_status_created ON reports (status, created_at)");
            jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_reports_target ON reports (target_type, target_id)");

            // Bảng promo_codes (Hệ thống quản lý voucher / mã khuyến mãi động)
            jdbcTemplate.execute("CREATE TABLE IF NOT EXISTS promo_codes (" +
                    "id BIGSERIAL PRIMARY KEY, " +
                    "code VARCHAR(50) UNIQUE NOT NULL, " +
                    "description TEXT, " +
                    "discount_percent INT DEFAULT 0, " +
                    "discount_amount NUMERIC(12, 2) DEFAULT 0, " +
                    "min_order_amount NUMERIC(12, 2) DEFAULT 0, " +
                    "max_uses INT DEFAULT 100, " +
                    "used_count INT DEFAULT 0, " +
                    "start_date TIMESTAMP, " +
                    "end_date TIMESTAMP, " +
                    "is_active BOOLEAN DEFAULT TRUE, " +
                    "created_at TIMESTAMP DEFAULT NOW(), " +
                    "updated_at TIMESTAMP DEFAULT NOW())");

            jdbcTemplate.execute("ALTER TABLE subscription_orders ADD COLUMN IF NOT EXISTS promo_code VARCHAR(50)");
            jdbcTemplate.execute("ALTER TABLE subscription_orders ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(12, 2) DEFAULT 0");

            // Khởi tạo các mã voucher mặc định vào database nếu bảng đang trống
            Integer promoCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM promo_codes", Integer.class);
            if (promoCount != null && promoCount == 0) {
                jdbcTemplate.execute("INSERT INTO promo_codes (code, description, discount_percent, discount_amount, max_uses, used_count, start_date, end_date, is_active, created_at, updated_at) VALUES " +
                        "('JLSP10', 'Giảm 10% áp dụng cho toàn bộ các gói thành viên JLSP', 10, 0, 100, 0, NOW(), NOW() + INTERVAL '2 years', true, NOW(), NOW()), " +
                        "('JLSP20', 'Ưu đãi chào mừng thành viên mới - Giảm 20%', 20, 0, 50, 0, NOW(), NOW() + INTERVAL '2 years', true, NOW(), NOW()), " +
                        "('SENSEI', 'Ưu đãi đặc quyền Sensei & Giáo viên - Giảm 15%', 15, 0, 50, 0, NOW(), NOW() + INTERVAL '2 years', true, NOW(), NOW()), " +
                        "('KOTOBA', 'Giảm trực tiếp 50.000 VNĐ vào hóa đơn', 0, 50000, 200, 0, NOW(), NOW() + INTERVAL '2 years', true, NOW(), NOW()), " +
                        "('HARU2026', 'Chiến dịch luyện thi JLPT Mùa Xuân 2026 - Giảm 25%', 25, 0, 30, 0, NOW(), NOW() + INTERVAL '2 years', true, NOW(), NOW())");
                log.info("Đã khởi tạo 5 mã voucher mặc định (JLSP10, JLSP20, SENSEI, KOTOBA, HARU2026) vào bảng promo_codes!");
            }

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

    private void ensureModeratorAccount() {
        try {
            User mod = userRepository.findByUsername("moderator")
                    .orElseGet(() -> userRepository.findByEmail("moderator@jlsp.com").orElse(null));

            String encodedPassword = passwordEncoder.encode("ModeratorPassword123@");

            if (mod != null) {
                mod.setUsername("moderator");
                mod.setEmail("moderator@jlsp.com");
                mod.setPasswordHash(encodedPassword);
                mod.setRole(UserRole.MODERATOR);
                mod.setIsActive(true);
                userRepository.save(mod);
                log.info("==> [SUCCESS] Đã đồng bộ tài khoản moderator: username='moderator', role=MODERATOR, password=ModeratorPassword123@");
            } else {
                mod = User.builder()
                        .username("moderator")
                        .email("moderator@jlsp.com")
                        .passwordHash(encodedPassword)
                        .displayName("Kiểm Duyệt Viên (Moderator)")
                        .avatarUrl("https://picsum.photos/seed/mod99/200/200")
                        .role(UserRole.MODERATOR)
                        .jlptLevel(JLPTLevel.N2)
                        .bio("Tài khoản kiểm duyệt nội dung & xử lý khiếu nại báo cáo JLSP")
                        .isActive(true)
                        .createdAt(LocalDateTime.now())
                        .updatedAt(LocalDateTime.now())
                        .build();
                userRepository.save(mod);
                log.info("==> [SUCCESS] Đã tạo mới tài khoản moderator: username='moderator', role=MODERATOR, password=ModeratorPassword123@");
            }
        } catch (Exception e) {
            log.error("Lỗi khi đồng bộ tài khoản moderator: {}", e.getMessage(), e);
        }
    }
}
