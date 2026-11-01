package com.jlsp.backend.common.security.jwt;

import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import org.junit.jupiter.api.Test;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtUtilsTest {

    private static final String SECRET = "test-secret-key-that-is-long-enough-for-hs256!!";

    private static User user() {
        return User.builder().id(42L).username("sakura99").email("sakura@example.com")
                .passwordHash("x").role(UserRole.MODERATOR).isActive(true).build();
    }

    @Test
    void rejectsSecretShorterThan256Bits() {
        assertThatThrownBy(() -> new JwtUtils("too-short", "jlsp", Duration.ofMinutes(30)))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void roundTripCarriesUserIdUsernameAndRoles() {
        JwtUtils jwt = new JwtUtils(SECRET, "jlsp", Duration.ofMinutes(30));

        var claims = jwt.parse(jwt.generateAccessToken(user())).orElseThrow();

        assertThat(claims.userId()).isEqualTo(42L);
        assertThat(claims.username()).isEqualTo("sakura99");
        assertThat(claims.roles()).containsExactly("ROLE_MODERATOR");
        assertThat(claims.tokenId()).isNotBlank();
    }

    @Test
    void claimsCarryTheIssueTimeUsedForPerUserRevocation() {
        JwtUtils jwt = new JwtUtils(SECRET, "jlsp", Duration.ofMinutes(30));
        long before = java.time.Instant.now().getEpochSecond();

        var claims = jwt.parse(jwt.generateAccessToken(user())).orElseThrow();

        assertThat(claims.issuedAt().getEpochSecond())
                .isBetween(before, java.time.Instant.now().getEpochSecond());
        assertThat(claims.expiresAt()).isAfter(claims.issuedAt());
    }

    @Test
    void eachTokenHasItsOwnId() {
        JwtUtils jwt = new JwtUtils(SECRET, "jlsp", Duration.ofMinutes(30));
        String first = jwt.parse(jwt.generateAccessToken(user())).orElseThrow().tokenId();
        String second = jwt.parse(jwt.generateAccessToken(user())).orElseThrow().tokenId();
        assertThat(first).isNotEqualTo(second);
    }

    @Test
    void rejectsExpiredToken() {
        JwtUtils jwt = new JwtUtils(SECRET, "jlsp", Duration.ofSeconds(-5));
        assertThat(jwt.parse(jwt.generateAccessToken(user()))).isEmpty();
    }

    @Test
    void rejectsTamperedToken() {
        JwtUtils jwt = new JwtUtils(SECRET, "jlsp", Duration.ofMinutes(30));
        String token = jwt.generateAccessToken(user());
        String tampered = token.substring(0, token.length() - 2) + (token.endsWith("A") ? "BB" : "AA");
        assertThat(jwt.parse(tampered)).isEmpty();
    }

    @Test
    void rejectsTokenSignedWithAnotherSecretOrIssuer() {
        JwtUtils issuer = new JwtUtils(SECRET, "jlsp", Duration.ofMinutes(30));
        JwtUtils otherSecret = new JwtUtils(SECRET + "-other", "jlsp", Duration.ofMinutes(30));
        JwtUtils otherIssuer = new JwtUtils(SECRET, "someone-else", Duration.ofMinutes(30));

        String token = issuer.generateAccessToken(user());

        assertThat(otherSecret.parse(token)).isEmpty();
        assertThat(otherIssuer.parse(token)).isEmpty();
    }

    @Test
    void rejectsGarbage() {
        JwtUtils jwt = new JwtUtils(SECRET, "jlsp", Duration.ofMinutes(30));
        assertThat(jwt.parse(null)).isEmpty();
        assertThat(jwt.parse("")).isEmpty();
        assertThat(jwt.parse("not.a.jwt")).isEmpty();
    }
}
