package com.jlsp.backend.common.config;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SecurityConfigCorsTest {

    @Test
    void devWithoutConfigurationAllowsAnyOrigin() {
        assertThat(SecurityConfig.resolveCorsOrigins("", false)).containsExactly("*");
        assertThat(SecurityConfig.resolveCorsOrigins(null, false)).containsExactly("*");
        assertThat(SecurityConfig.resolveCorsOrigins("  , ", false)).containsExactly("*");
    }

    @Test
    void parsesACommaSeparatedListAndTrimsEachOrigin() {
        List<String> origins = SecurityConfig.resolveCorsOrigins(
                " https://admin.example.com , http://localhost:5173,", true);

        assertThat(origins).containsExactly("https://admin.example.com", "http://localhost:5173");
    }

    @Test
    void prodRefusesToStartWithoutExplicitOrigins() {
        assertThatThrownBy(() -> SecurityConfig.resolveCorsOrigins("", true))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("CORS_ALLOWED_ORIGINS");
    }

    @Test
    void prodRefusesAWildcardOrigin() {
        assertThatThrownBy(() -> SecurityConfig.resolveCorsOrigins("https://a.com,*", true))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void devMayStillListSpecificOriginsOrAWildcardExplicitly() {
        assertThat(SecurityConfig.resolveCorsOrigins("http://localhost:5173", false))
                .containsExactly("http://localhost:5173");
        assertThat(SecurityConfig.resolveCorsOrigins("*", false)).containsExactly("*");
    }
}
