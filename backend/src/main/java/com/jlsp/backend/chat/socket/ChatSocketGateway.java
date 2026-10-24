package com.jlsp.backend.chat.socket;

import com.corundumstudio.socketio.AckRequest;
import com.corundumstudio.socketio.HandshakeData;
import com.corundumstudio.socketio.SocketIOClient;
import com.corundumstudio.socketio.SocketIOServer;
import com.corundumstudio.socketio.listener.DataListener;
import com.jlsp.backend.chat.dto.request.MarkReadRequest;
import com.jlsp.backend.chat.dto.request.SendMessageRequest;
import com.jlsp.backend.chat.dto.request.TypingRequest;
import com.jlsp.backend.chat.dto.response.TypingResponse;
import com.jlsp.backend.chat.service.ChatService;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.security.jwt.JwtUtils;
import com.jlsp.backend.common.security.token.AccessTokenDenylist;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validator;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.SmartLifecycle;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import java.util.function.BiFunction;

/**
 * Cổng Socket.IO cho chat.
 *
 * <p>Kết nối: client gửi access token qua query {@code ?token=} (hoặc header
 * {@code Authorization: Bearer} nếu nền tảng hỗ trợ). Token hợp lệ thì socket được gắn
 * userId và join room "user:{id}"; sai thì bị ngắt kết nối. Access token sống ngắn nên
 * client phải đặt lại query bằng token mới mỗi lần (re)connect.
 *
 * <p>Event client → server (đều có ack {@code {ok, data} | {ok:false, status, message}}):
 * <ul>
 *   <li>{@code message:send} — {@link SendMessageRequest}</li>
 *   <li>{@code conversation:read} — {@link MarkReadRequest}</li>
 *   <li>{@code typing} — {@link TypingRequest} (không lưu DB)</li>
 * </ul>
 * Event server → client: {@code message:new}, {@code message:read}, {@code typing}
 * (xem {@link ChatSocketPublisher}).
 */
@Component
@ConditionalOnProperty(name = "socketio.enabled", havingValue = "true", matchIfMissing = true)
@RequiredArgsConstructor
@Slf4j
public class ChatSocketGateway implements SmartLifecycle {

    private static final String USER_ID_KEY = "userId";
    private static final String EVENT_AUTH_ERROR = "auth:error";

    private final SocketIOServer server;
    private final JwtUtils jwtUtils;
    private final AccessTokenDenylist denylist;
    private final ChatService chatService;
    private final ChatSocketPublisher publisher;
    private final Validator validator;

    private volatile boolean running;

    @Override
    public void start() {
        server.addConnectListener(this::onConnect);
        server.addDisconnectListener(client ->
                log.debug("Socket {} của user {} đã ngắt kết nối", client.getSessionId(), client.get(USER_ID_KEY)));

        server.addEventListener("message:send", SendMessageRequest.class,
                authenticated((userId, request) -> chatService.sendMessage(userId, validated(request))));

        server.addEventListener("conversation:read", MarkReadRequest.class,
                authenticated((userId, request) -> {
                    validated(request);
                    if (request.getConversationId() == null) {
                        throw new AppException(400, "Thiếu hội thoại");
                    }
                    return chatService.markAsRead(userId, request.getConversationId(), request.getLastMessageId());
                }));

        server.addEventListener("typing", TypingRequest.class,
                authenticated((userId, request) -> {
                    if (request.getConversationId() == null) {
                        throw new AppException(400, "Thiếu hội thoại");
                    }
                    Long otherUserId = chatService.getOtherParticipantId(userId, request.getConversationId());
                    publisher.emit(otherUserId, ChatSocketPublisher.EVENT_TYPING, publisher.toPayload(
                            TypingResponse.builder()
                                    .conversationId(request.getConversationId())
                                    .userId(userId)
                                    .isTyping(Boolean.TRUE.equals(request.getIsTyping()))
                                    .build()));
                    return null;
                }));

        server.start();
        running = true;
        log.info("Socket.IO chat server đang chạy tại {}:{}",
                server.getConfiguration().getHostname(), server.getConfiguration().getPort());
    }

    @Override
    public void stop() {
        if (running) {
            server.stop();
            running = false;
            log.info("Đã dừng Socket.IO chat server");
        }
    }

    @Override
    public boolean isRunning() {
        return running;
    }

    private void onConnect(SocketIOClient client) {
        String token = extractToken(client.getHandshakeData());
        var claims = jwtUtils.parse(token).filter(c -> !denylist.isDenied(c.tokenId()));
        if (claims.isEmpty()) {
            client.sendEvent(EVENT_AUTH_ERROR, "Phiên đăng nhập không hợp lệ hoặc đã hết hạn");
            client.disconnect();
            return;
        }
        Long userId = claims.get().userId();
        client.set(USER_ID_KEY, userId);
        client.joinRoom(ChatSocketPublisher.userRoom(userId));
        log.debug("Socket {} đã xác thực cho user {}", client.getSessionId(), userId);
    }

    private static String extractToken(HandshakeData handshake) {
        // Không dùng payload "auth" của Socket.IO v4: netty-socketio 2.0.13 gán nó SAU khi
        // gọi ConnectListener nên luôn null ở đây. Query hoạt động trên cả web lẫn mobile.
        String query = handshake.getSingleUrlParam("token");
        if (query != null && !query.isBlank()) {
            return query;
        }
        String header = handshake.getHttpHeaders().get("Authorization");
        return header == null ? null : stripBearer(header);
    }

    private static String stripBearer(String value) {
        return value.startsWith("Bearer ") ? value.substring("Bearer ".length()) : value;
    }

    /**
     * Bọc handler: bắt buộc socket đã xác thực, trả kết quả/lỗi qua ack thay vì để
     * exception làm rớt kết nối.
     */
    private <T> DataListener<T> authenticated(BiFunction<Long, T, Object> handler) {
        return (client, data, ack) -> {
            Long userId = client.get(USER_ID_KEY);
            if (userId == null) {
                reply(ack, error(401, "Vui lòng đăng nhập để tiếp tục"));
                client.disconnect();
                return;
            }
            if (data == null) {
                reply(ack, error(400, "Dữ liệu không hợp lệ"));
                return;
            }
            try {
                Object result = handler.apply(userId, data);
                Map<String, Object> body = new LinkedHashMap<>();
                body.put("ok", true);
                body.put("data", publisher.toPayload(result));
                reply(ack, body);
            } catch (AppException e) {
                reply(ack, error(e.getStatus(), e.getMessage()));
            } catch (Exception e) {
                log.error("Lỗi xử lý event socket của user {}", userId, e);
                reply(ack, error(500, "Máy chủ đang gặp sự cố, vui lòng thử lại sau"));
            }
        };
    }

    private <T> T validated(T request) {
        Set<ConstraintViolation<T>> violations = validator.validate(request);
        if (!violations.isEmpty()) {
            throw new AppException(400, violations.iterator().next().getMessage());
        }
        return request;
    }

    private static Map<String, Object> error(int status, String message) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("ok", false);
        body.put("status", status);
        body.put("message", message);
        return body;
    }

    private static void reply(AckRequest ack, Map<String, Object> body) {
        if (ack.isAckRequested()) {
            ack.sendAckData(body);
        }
    }
}
