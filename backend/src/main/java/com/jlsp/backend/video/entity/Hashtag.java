package com.jlsp.backend.video.entity;

import jakarta.persistence.*;
import lombok.*;

/**
 * Hashtag do người đăng tự điền. Khác với chủ đề (metadata của hệ thống), hashtag chỉ phục vụ
 * tìm kiếm / khám phá. {@code name} luôn ở dạng đã chuẩn hoá, xem {@code HashtagRules}.
 */
@Entity
@Table(name = "hashtags")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Hashtag {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 30)
    private String name;
}
