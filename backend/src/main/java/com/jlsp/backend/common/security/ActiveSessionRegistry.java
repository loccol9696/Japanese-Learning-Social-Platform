package com.jlsp.backend.common.security;

import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class ActiveSessionRegistry {

    private final Map<String, Session> sessions = new ConcurrentHashMap<>();

    public boolean tryRegister(String username, String token, long expiresAt) {
        final boolean[] registered = { false };
        sessions.compute(username, (key, existing) -> {
            if (existing == null || existing.expiresAt() <= System.currentTimeMillis()) {
                registered[0] = true;
                return new Session(token, expiresAt);
            }
            return existing;
        });
        return registered[0];
    }

    public boolean isActive(String username, String token) {
        Session session = sessions.get(username);
        if (session == null) {
            return false;
        }
        if (session.expiresAt() <= System.currentTimeMillis()) {
            sessions.remove(username, session);
            return false;
        }
        return session.token().equals(token);
    }

    public void logout(String username, String token) {
        sessions.remove(username, new Session(token, 0));
    }

    private record Session(String token, long expiresAt) {
    }
}
