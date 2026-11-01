package com.jlsp.backend.chat.socket;

import com.corundumstudio.socketio.AckMode;
import com.corundumstudio.socketio.SocketIOServer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Server Socket.IO (netty-socketio) chạy trên port riêng, song song với Spring MVC.
 * Tắt bằng socketio.enabled=false (vd. khi chạy test). Vòng đời start/stop do
 * {@link ChatSocketGateway} quản lý.
 */
@Configuration
@ConditionalOnProperty(name = "socketio.enabled", havingValue = "true", matchIfMissing = true)
public class SocketIOConfig {

    @Bean
    public SocketIOServer socketIOServer(@Value("${socketio.host:0.0.0.0}") String host,
                                         @Value("${socketio.port:9092}") int port) {
        com.corundumstudio.socketio.Configuration config = new com.corundumstudio.socketio.Configuration();
        config.setHostname(host);
        config.setPort(port);
        config.getSocketConfig().setReuseAddress(true);
        // Event được xử lý ở ChatSocketExecutor rồi mới ack; chế độ tự động sẽ gửi ack rỗng
        // ngay khi listener trả về, trước khi có kết quả.
        config.setAckMode(AckMode.MANUAL);
        return new SocketIOServer(config);
    }
}
