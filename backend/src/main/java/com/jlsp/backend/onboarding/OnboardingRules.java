package com.jlsp.backend.onboarding;

import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;

/**
 * Quy tắc hỏi câu hỏi chào mừng. Đặt ở một chỗ để đăng nhập, làm mới token, hồ sơ và màn hình cùng cho kết quả giống nhau.
 */
public final class OnboardingRules {

    /** Bỏ qua tối đa bao nhiêu lần; vượt mức này thì thôi hỏi (vẫn sửa được trong hồ sơ). */
    public static final int MAX_SKIPS = 2;

    private OnboardingRules() {
    }

    /**
     * Cần hỏi khi: tài khoản thường, chưa hoàn thành, và chưa bỏ qua quá số lần cho phép.
     * Quản trị viên và kiểm duyệt viên không bao giờ bị hỏi.
     */
    public static boolean needsOnboarding(User user) {
        if (user == null || user.getRole() != UserRole.USER) {
            return false;
        }
        if (user.getOnboardingCompletedAt() != null) {
            return false;
        }
        int skips = user.getOnboardingSkipCount() == null ? 0 : user.getOnboardingSkipCount();
        return skips < MAX_SKIPS;
    }
}
