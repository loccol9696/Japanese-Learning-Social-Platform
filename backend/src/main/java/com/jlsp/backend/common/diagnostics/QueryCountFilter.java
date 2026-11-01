package com.jlsp.backend.common.diagnostics;

import jakarta.persistence.EntityManagerFactory;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.hibernate.SessionFactory;
import org.hibernate.stat.Statistics;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingResponseWrapper;

import java.io.IOException;

/**
 * Công cụ đo hiệu năng cho giai đoạn rà soát: với mỗi request {@code /api/**}, đếm số câu SQL Hibernate đã
 * chuẩn bị và thời gian xử lý, ghi ra log và trả về qua header {@code X-Query-Count} / {@code X-Response-Time-Ms}.
 * Dùng để phát hiện N+1 (số truy vấn tăng theo số dòng) và lập baseline trước / sau khi tối ưu.
 *
 * <ul>
 *   <li><b>Tắt mặc định.</b> Bật bằng biến môi trường {@code APP_DIAGNOSTICS_QUERY_COUNT=true}. Không bật ở prod.</li>
 *   <li>Bộ đếm của Hibernate là toàn cục nên số liệu chỉ chính xác khi đo từng request một (không có request
 *       khác chạy song song).</li>
 *   <li>Phải đệm toàn bộ phản hồi để đặt header sau khi xử lý xong, nên chỉ phù hợp để đo, không để chạy thật.</li>
 * </ul>
 */
@Component
@ConditionalOnProperty(name = "app.diagnostics.query-count", havingValue = "true")
@Order(Ordered.HIGHEST_PRECEDENCE + 20)
public class QueryCountFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(QueryCountFilter.class);

    private final Statistics statistics;

    public QueryCountFilter(EntityManagerFactory entityManagerFactory) {
        this.statistics = entityManagerFactory.unwrap(SessionFactory.class).getStatistics();
        this.statistics.setStatisticsEnabled(true);
        log.warn("Chế độ đo số truy vấn (app.diagnostics.query-count) đang BẬT: chỉ dùng khi đo hiệu năng, "
                + "không bật ở môi trường thật.");
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !request.getRequestURI().startsWith("/api/");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        ContentCachingResponseWrapper wrapped = new ContentCachingResponseWrapper(response);
        long queriesBefore = statistics.getPrepareStatementCount();
        long startedAt = System.nanoTime();
        try {
            chain.doFilter(request, wrapped);
        } finally {
            long queries = statistics.getPrepareStatementCount() - queriesBefore;
            long millis = (System.nanoTime() - startedAt) / 1_000_000;
            wrapped.setHeader("X-Query-Count", String.valueOf(queries));
            wrapped.setHeader("X-Response-Time-Ms", String.valueOf(millis));
            log.info("[query-count] {} {} -> {} truy vấn, {} ms, HTTP {}",
                    request.getMethod(), describe(request), queries, millis, wrapped.getStatus());
            wrapped.copyBodyToResponse();
        }
    }

    private static String describe(HttpServletRequest request) {
        String query = request.getQueryString();
        return query == null ? request.getRequestURI() : request.getRequestURI() + "?" + query;
    }
}
