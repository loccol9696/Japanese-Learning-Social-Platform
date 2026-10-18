package com.jlsp.backend.video.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.*;

import java.io.Serializable;
import java.util.Objects;

@Embeddable
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VideoLikeId implements Serializable {

    @Column(name = "user_id")
    private Long userId;

    @Column(name = "video_id")
    private Long videoId;

    @Override
    public boolean equals(Object o) {
        if (this == o)
            return true;
        if (o == null || getClass() != o.getClass())
            return false;
        VideoLikeId that = (VideoLikeId) o;
        return Objects.equals(userId, that.userId) && Objects.equals(videoId, that.videoId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(userId, videoId);
    }
}
