-- ==============================================================
-- Dữ liệu khởi tạo mẫu: 1 Admin và 3 Users tiếng Nhật
-- ==============================================================

INSERT INTO users (username, email, password_hash, display_name, avatar_url, jlpt_level, bio, role, is_active, created_at, updated_at)
VALUES 
(
    'admin', 
    'admin@jlsp.com', 
    '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKTVKIUi', 
    'Hệ thống Quản trị (Admin)', 
    'https://ik.imagekit.io/jlsp_demo/avatars/admin.png', 
    'N1', 
    'Tài khoản quản trị viên hệ thống JLSP', 
    'ADMIN', 
    true, 
    NOW(), 
    NOW()
),
(
    'tanaka_sensei', 
    'tanaka@jlsp.com', 
    '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKTVKIUi', 
    'Tanaka Sensei', 
    'https://ik.imagekit.io/jlsp_demo/avatars/tanaka.png', 
    'N1', 
    'Giáo viên tiếng Nhật Tokyo, 10 năm kinh nghiệm luyện thi JLPT N2 - N1', 
    'USER', 
    true, 
    NOW(), 
    NOW()
),
(
    'yamada_kaiwa', 
    'yamada@jlsp.com', 
    '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKTVKIUi', 
    'Yamada Kaiwa', 
    'https://ik.imagekit.io/jlsp_demo/avatars/yamada.png', 
    'N2', 
    'Chia sẻ hội thoại tiếng Nhật giao tiếp đời sống thực tế hàng ngày', 
    'USER', 
    true, 
    NOW(), 
    NOW()
),
(
    'sakura_learner', 
    'sakura@jlsp.com', 
    '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKTVKIUi', 
    'Sakura Chan', 
    'https://ik.imagekit.io/jlsp_demo/avatars/sakura.png', 
    'N5', 
    'Người mới bắt đầu học tiếng Nhật! Mục tiêu đỗ JLPT N4 năm nay', 
    'USER', 
    true, 
    NOW(), 
    NOW()
)
ON CONFLICT (username) DO NOTHING;
