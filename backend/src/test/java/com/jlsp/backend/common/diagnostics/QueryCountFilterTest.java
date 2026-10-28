package com.jlsp.backend.common.diagnostics;

import jakarta.persistence.EntityManagerFactory;
import jakarta.servlet.FilterChain;
import org.hibernate.SessionFactory;
import org.hibernate.stat.Statistics;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class QueryCountFilterTest {

    private Statistics statistics;
    private QueryCountFilter filter;

    @BeforeEach
    void setUp() {
        statistics = mock(Statistics.class);
        SessionFactory sessionFactory = mock(SessionFactory.class);
        when(sessionFactory.getStatistics()).thenReturn(statistics);
        EntityManagerFactory emf = mock(EntityManagerFactory.class);
        when(emf.unwrap(SessionFactory.class)).thenReturn(sessionFactory);
        filter = new QueryCountFilter(emf);
    }

    @Test
    void enablesHibernateStatisticsWhenCreated() {
        verify(statistics).setStatisticsEnabled(true);
    }

    @Test
    void reportsTheNumberOfStatementsExecutedDuringTheRequest() throws Exception {
        when(statistics.getPrepareStatementCount()).thenReturn(10L, 17L);
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/videos");
        request.setQueryString("page=0");
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = (req, res) -> {
            ((jakarta.servlet.http.HttpServletResponse) res).setStatus(200);
            res.setCharacterEncoding("UTF-8"); // app thật ép UTF-8 (server.servlet.encoding)
            res.getWriter().write("danh sách video");
        };

        filter.doFilter(request, response, chain);

        assertThat(response.getHeader("X-Query-Count")).isEqualTo("7");
        assertThat(Long.parseLong(response.getHeader("X-Response-Time-Ms"))).isGreaterThanOrEqualTo(0);
        // Nội dung phản hồi vẫn được trả về đầy đủ dù bị đệm để đặt header.
        assertThat(response.getContentAsString(StandardCharsets.UTF_8)).isEqualTo("danh sách video");
        assertThat(response.getStatus()).isEqualTo(200);
    }

    @Test
    void stillReportsAndRethrowsWhenTheRequestFails() {
        when(statistics.getPrepareStatementCount()).thenReturn(0L, 3L);
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain failing = (req, res) -> {
            throw new IllegalStateException("lỗi giả lập");
        };

        assertThatThrownBy(() -> filter.doFilter(
                new MockHttpServletRequest("GET", "/api/v1/videos"), response, failing))
                .isInstanceOf(IllegalStateException.class);

        assertThat(response.getHeader("X-Query-Count")).isEqualTo("3");
    }

    @Test
    void onlyApiRequestsAreMeasured() throws Exception {
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = (req, res) -> { };

        filter.doFilter(new MockHttpServletRequest("GET", "/actuator/health"), response, chain);
        filter.doFilter(new MockHttpServletRequest("GET", "/"), response, chain);

        assertThat(response.getHeader("X-Query-Count")).isNull();
    }
}
