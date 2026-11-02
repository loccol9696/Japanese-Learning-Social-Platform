package com.jlsp.backend.report.repository;

import com.jlsp.backend.common.repository.IdCount;
import com.jlsp.backend.report.entity.Report;
import com.jlsp.backend.report.entity.ReportStatus;
import com.jlsp.backend.report.entity.ReportTargetType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;

public interface ReportRepository extends JpaRepository<Report, Long> {

    boolean existsByReporterIdAndTargetTypeAndTargetIdAndTargetKeyAndStatus(
            Long reporterId, ReportTargetType targetType, Long targetId, String targetKey, ReportStatus status);

    @EntityGraph(attributePaths = "reporter")
    Page<Report> findByStatus(ReportStatus status, Pageable pageable);

    @EntityGraph(attributePaths = "reporter")
    Page<Report> findByStatusAndTargetType(ReportStatus status, ReportTargetType targetType, Pageable pageable);

    List<Report> findByTargetTypeAndTargetIdAndTargetKeyAndStatus(
            ReportTargetType targetType, Long targetId, String targetKey, ReportStatus status);

    long countByTargetTypeAndTargetIdAndTargetKeyAndStatus(
            ReportTargetType targetType, Long targetId, String targetKey, ReportStatus status);

    long countByStatus(ReportStatus status);

    /**
     * Số báo cáo đang chờ xử lý của nhiều đối tượng cùng loại trong một truy vấn (đối tượng không bị báo
     * cáo sẽ không có dòng). Mỗi người chỉ báo cáo được một lần khi báo cáo còn chờ nên đây cũng là số người báo cáo.
     */
    @Query("SELECT r.targetId AS id, COUNT(r) AS total FROM Report r " +
            "WHERE r.targetType = :type AND r.status = com.jlsp.backend.report.entity.ReportStatus.PENDING " +
            "AND r.targetId IN :ids GROUP BY r.targetId")
    List<IdCount> countPendingByTargetIds(@Param("type") ReportTargetType type, @Param("ids") Collection<Long> ids);
}
