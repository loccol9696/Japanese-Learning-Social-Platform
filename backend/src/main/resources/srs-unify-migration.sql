-- Gộp về một nguồn lịch ôn: chỉ học ngắt quãng (SRS) quyết định next_review_at. Các chế độ luyện tập (trắc nghiệm, gõ, nghe,
-- ghép cặp) giờ chỉ ghi thống kê đúng/sai. Dữ liệu cũ do hộp Leitner đặt lịch (thẻ chưa từng học SRS nhưng có
-- next_review_at) thì trở lại là thẻ mới, nếu không chúng vẫn hiện trong "Cần ôn hôm nay". Chạy một lần, không bắt buộc.
UPDATE flashcard_progress SET next_review_at = NULL WHERE srs_state = 'NEW' AND next_review_at IS NOT NULL;
