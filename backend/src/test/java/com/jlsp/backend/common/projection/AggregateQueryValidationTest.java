package com.jlsp.backend.common.projection;

import com.jlsp.backend.user.repository.FollowRepository;
import com.jlsp.backend.video.repository.VideoLikeRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import com.jlsp.backend.video.repository.VideoSaveRepository;
import com.jlsp.backend.subscription.repository.SubscriptionOrderRepository;
import com.jlsp.backend.subscription.repository.UserDailyTokenUsageRepository;
import com.jlsp.backend.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.test.context.TestPropertySource;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Kiểm tra cú pháp HQL của các @Query mà KHÔNG cần database: Spring Data parse/validate
 * mọi @Query khi tạo repository, còn Hibernate khởi động không đọc JDBC metadata.
 * Datasource trỏ tới cổng không tồn tại để chắc chắn không chạm DB thật (application.yml).
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Transactional(propagation = Propagation.NOT_SUPPORTED)
@TestPropertySource(properties = {
        "spring.datasource.url=jdbc:postgresql://127.0.0.1:1/no_database",
        "spring.datasource.username=none",
        "spring.datasource.password=none",
        "spring.jpa.hibernate.ddl-auto=none",
        "spring.sql.init.mode=never",
        "spring.jpa.properties.hibernate.boot.allow_jdbc_metadata_access=false",
        "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect"
})
class AggregateQueryValidationTest {

    @Autowired
    UserRepository userRepository;
    @Autowired
    UserDailyTokenUsageRepository tokenUsageRepository;
    @Autowired
    SubscriptionOrderRepository orderRepository;
    @Autowired
    VideoRepository videoRepository;
    @Autowired
    VideoLikeRepository videoLikeRepository;
    @Autowired
    VideoSaveRepository videoSaveRepository;
    @Autowired
    FollowRepository followRepository;

    @Test
    void aggregateQueriesParseAgainstEntityModel() {
        assertThat(userRepository).isNotNull();
        assertThat(tokenUsageRepository).isNotNull();
        assertThat(orderRepository).isNotNull();
        assertThat(videoRepository).isNotNull();
        assertThat(videoLikeRepository).isNotNull();
        assertThat(videoSaveRepository).isNotNull();
        assertThat(followRepository).isNotNull();
    }
}
