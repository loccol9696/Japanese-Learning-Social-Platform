package com.jlsp.backend.topic.entity;

import jakarta.persistence.*;
import lombok.*;

/**
 * Chủ đề nội dung: gắn cho video (phân loại) và cho hồ sơ người dùng (sở thích).
 * Không xoá cứng để không làm mất liên kết; ẩn bằng {@code isActive = false}.
 */
@Entity
@Table(name = "topics")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Topic {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 80)
    private String name;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private Boolean isActive = true;

    /** Thứ tự hiển thị, nhỏ đứng trước. */
    @Column(name = "sort_order", nullable = false)
    @Builder.Default
    private Integer sortOrder = 0;
}
