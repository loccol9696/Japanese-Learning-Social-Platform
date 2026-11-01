package com.jlsp.backend.admin.controller;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.jlsp.backend.admin.dto.AdminAnalyticsResponse;
import com.jlsp.backend.admin.dto.AdminAnalyticsResponse.DailyMetricDto;
import com.jlsp.backend.admin.service.AdminAnalyticsService;
import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.subscription.entity.SubscriptionOrder;
import com.jlsp.backend.subscription.entity.UserDailyTokenUsage;
import com.jlsp.backend.subscription.repository.SubscriptionOrderRepository;
import com.jlsp.backend.subscription.repository.UserDailyTokenUsageRepository;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1/admin/analytics")
@RequiredArgsConstructor
public class AdminAnalyticsController {

    private final AdminAnalyticsService analyticsService;
    private final UserRepository userRepository;
    private final UserDailyTokenUsageRepository tokenUsageRepository;
    private final SubscriptionOrderRepository orderRepository;


    @GetMapping
    public ResponseEntity<ApiResponse<AdminAnalyticsResponse>> getAnalytics(
            @RequestParam(value = "period", defaultValue = "7days") String period) {
        return ResponseEntity.ok(ApiResponse.success(analyticsService.overview(period, LocalDate.now())));
    }

    @GetMapping("/trend")
    public ResponseEntity<ApiResponse<List<DailyMetricDto>>> getTrend(
            @RequestParam(defaultValue = "user") String metric,
            @RequestParam(defaultValue = "7days") String period,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer month,
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate) {

        LocalDate today = LocalDate.now();
        int targetYear = (year != null && year >= 2000 && year <= 2100) ? year : today.getYear();
        int targetMonth = (month != null && month >= 1 && month <= 12) ? month : today.getMonthValue();

        List<DailyMetricDto> trend = new ArrayList<>();

        if ("range".equalsIgnoreCase(period)) {
            LocalDate start = (startDate != null && !startDate.isBlank()) ? LocalDate.parse(startDate) : today.minusDays(30);
            LocalDate end = (endDate != null && !endDate.isBlank()) ? LocalDate.parse(endDate) : today;
            if (end.isBefore(start)) {
                LocalDate temp = start;
                start = end;
                end = temp;
            }
            final LocalDate finalStart = start;
            final LocalDate finalEnd = end;
            DateTimeFormatter fmt = DateTimeFormatter.ofPattern("dd/MM");

            if ("user".equalsIgnoreCase(metric)) {
                List<User> allUsers = userRepository.findAll();
                Map<LocalDate, Long> map = allUsers.stream()
                        .filter(u -> u.getRole() == UserRole.USER && u.getCreatedAt() != null
                                && !u.getCreatedAt().toLocalDate().isBefore(finalStart)
                                && !u.getCreatedAt().toLocalDate().isAfter(finalEnd))
                        .collect(Collectors.groupingBy(u -> u.getCreatedAt().toLocalDate(), Collectors.counting()));

                LocalDate curr = finalStart;
                while (!curr.isAfter(finalEnd)) {
                    trend.add(new DailyMetricDto(curr.format(fmt), map.getOrDefault(curr, 0L)));
                    curr = curr.plusDays(1);
                }
            } else if ("token".equalsIgnoreCase(metric)) {
                List<UserDailyTokenUsage> usages = tokenUsageRepository.findAll();
                Map<LocalDate, Long> map = usages.stream()
                        .filter(u -> u.getUsageDate() != null
                                && !u.getUsageDate().isBefore(finalStart)
                                && !u.getUsageDate().isAfter(finalEnd))
                        .collect(Collectors.groupingBy(
                                UserDailyTokenUsage::getUsageDate,
                                Collectors.summingLong(u -> u.getTokensUsed() != null ? u.getTokensUsed() : 0L)
                        ));

                LocalDate curr = finalStart;
                while (!curr.isAfter(finalEnd)) {
                    trend.add(new DailyMetricDto(curr.format(fmt), map.getOrDefault(curr, 0L)));
                    curr = curr.plusDays(1);
                }
            } else if ("revenue".equalsIgnoreCase(metric)) {
                List<SubscriptionOrder> orders = orderRepository.findByStatus(SubscriptionOrder.OrderStatus.SUCCESS);
                Map<LocalDate, Long> map = orders.stream()
                        .filter(o -> o.getCreatedAt() != null
                                && !o.getCreatedAt().toLocalDate().isBefore(finalStart)
                                && !o.getCreatedAt().toLocalDate().isAfter(finalEnd))
                        .collect(Collectors.groupingBy(
                                o -> o.getCreatedAt().toLocalDate(),
                                Collectors.summingLong(o -> o.getAmount() != null ? o.getAmount().longValue() : 0L)
                        ));

                LocalDate curr = finalStart;
                while (!curr.isAfter(finalEnd)) {
                    trend.add(new DailyMetricDto(curr.format(fmt), map.getOrDefault(curr, 0L)));
                    curr = curr.plusDays(1);
                }
            }
        } else if ("days_in_month".equalsIgnoreCase(period)) {
            // Từng ngày trong tháng và năm được chọn (e.g. Tháng 10/2026: 01/10 -> 31/10)
            int daysInMonth = java.time.YearMonth.of(targetYear, targetMonth).lengthOfMonth();
            DateTimeFormatter fmt = DateTimeFormatter.ofPattern("dd/MM");

            if ("user".equalsIgnoreCase(metric)) {
                List<User> allUsers = userRepository.findAll();
                Map<LocalDate, Long> map = allUsers.stream()
                        .filter(u -> u.getRole() == UserRole.USER && u.getCreatedAt() != null
                                && u.getCreatedAt().getYear() == targetYear
                                && u.getCreatedAt().getMonthValue() == targetMonth)
                        .collect(Collectors.groupingBy(u -> u.getCreatedAt().toLocalDate(), Collectors.counting()));

                for (int day = 1; day <= daysInMonth; day++) {
                    LocalDate d = LocalDate.of(targetYear, targetMonth, day);
                    trend.add(new DailyMetricDto(d.format(fmt), map.getOrDefault(d, 0L)));
                }
            } else if ("token".equalsIgnoreCase(metric)) {
                List<UserDailyTokenUsage> usages = tokenUsageRepository.findAll();
                Map<LocalDate, Long> map = usages.stream()
                        .filter(u -> u.getUsageDate() != null
                                && u.getUsageDate().getYear() == targetYear
                                && u.getUsageDate().getMonthValue() == targetMonth)
                        .collect(Collectors.groupingBy(
                                u -> u.getUsageDate(),
                                Collectors.summingLong(u -> u.getTokensUsed() != null ? u.getTokensUsed() : 0L)
                        ));

                for (int day = 1; day <= daysInMonth; day++) {
                    LocalDate d = LocalDate.of(targetYear, targetMonth, day);
                    trend.add(new DailyMetricDto(d.format(fmt), map.getOrDefault(d, 0L)));
                }
            } else if ("revenue".equalsIgnoreCase(metric)) {
                List<SubscriptionOrder> orders = orderRepository.findByStatus(SubscriptionOrder.OrderStatus.SUCCESS);
                Map<LocalDate, Long> map = orders.stream()
                        .filter(o -> o.getCreatedAt() != null
                                && o.getCreatedAt().getYear() == targetYear
                                && o.getCreatedAt().getMonthValue() == targetMonth)
                        .collect(Collectors.groupingBy(
                                o -> o.getCreatedAt().toLocalDate(),
                                Collectors.summingLong(o -> o.getAmount() != null ? o.getAmount().longValue() : 0L)
                        ));

                for (int day = 1; day <= daysInMonth; day++) {
                    LocalDate d = LocalDate.of(targetYear, targetMonth, day);
                    trend.add(new DailyMetricDto(d.format(fmt), map.getOrDefault(d, 0L)));
                }
            }
        } else if ("month".equalsIgnoreCase(period)) {
            // 12 tháng trong năm được chọn
            if ("user".equalsIgnoreCase(metric)) {
                List<User> allUsers = userRepository.findAll();
                Map<Integer, Long> map = allUsers.stream()
                        .filter(u -> u.getRole() == UserRole.USER && u.getCreatedAt() != null
                                && u.getCreatedAt().getYear() == targetYear)
                        .collect(Collectors.groupingBy(u -> u.getCreatedAt().getMonthValue(), Collectors.counting()));

                for (int m = 1; m <= 12; m++) {
                    trend.add(new DailyMetricDto(String.format("Th%02d", m), map.getOrDefault(m, 0L)));
                }
            } else if ("token".equalsIgnoreCase(metric)) {
                List<UserDailyTokenUsage> usages = tokenUsageRepository.findAll();
                Map<Integer, Long> map = usages.stream()
                        .filter(u -> u.getUsageDate() != null && u.getUsageDate().getYear() == targetYear)
                        .collect(Collectors.groupingBy(
                                u -> u.getUsageDate().getMonthValue(),
                                Collectors.summingLong(u -> u.getTokensUsed() != null ? u.getTokensUsed() : 0L)
                        ));

                for (int m = 1; m <= 12; m++) {
                    trend.add(new DailyMetricDto(String.format("Th%02d", m), map.getOrDefault(m, 0L)));
                }
            } else if ("revenue".equalsIgnoreCase(metric)) {
                List<SubscriptionOrder> orders = orderRepository.findByStatus(SubscriptionOrder.OrderStatus.SUCCESS);
                Map<Integer, Long> map = orders.stream()
                        .filter(o -> o.getCreatedAt() != null && o.getCreatedAt().getYear() == targetYear)
                        .collect(Collectors.groupingBy(
                                o -> o.getCreatedAt().getMonthValue(),
                                Collectors.summingLong(o -> o.getAmount() != null ? o.getAmount().longValue() : 0L)
                        ));

                for (int m = 1; m <= 12; m++) {
                    trend.add(new DailyMetricDto(String.format("Th%02d", m), map.getOrDefault(m, 0L)));
                }
            }
        } else if ("year".equalsIgnoreCase(period)) {
            // 5 năm gần nhất đến targetYear
            int startYear = targetYear - 4;
            if ("user".equalsIgnoreCase(metric)) {
                List<User> allUsers = userRepository.findAll();
                Map<Integer, Long> map = allUsers.stream()
                        .filter(u -> u.getRole() == UserRole.USER && u.getCreatedAt() != null)
                        .collect(Collectors.groupingBy(u -> u.getCreatedAt().getYear(), Collectors.counting()));

                for (int y = startYear; y <= targetYear; y++) {
                    trend.add(new DailyMetricDto(String.valueOf(y), map.getOrDefault(y, 0L)));
                }
            } else if ("token".equalsIgnoreCase(metric)) {
                List<UserDailyTokenUsage> usages = tokenUsageRepository.findAll();
                Map<Integer, Long> map = usages.stream()
                        .filter(u -> u.getUsageDate() != null)
                        .collect(Collectors.groupingBy(
                                u -> u.getUsageDate().getYear(),
                                Collectors.summingLong(u -> u.getTokensUsed() != null ? u.getTokensUsed() : 0L)
                        ));

                for (int y = startYear; y <= targetYear; y++) {
                    trend.add(new DailyMetricDto(String.valueOf(y), map.getOrDefault(y, 0L)));
                }
            } else if ("revenue".equalsIgnoreCase(metric)) {
                List<SubscriptionOrder> orders = orderRepository.findByStatus(SubscriptionOrder.OrderStatus.SUCCESS);
                Map<Integer, Long> map = orders.stream()
                        .filter(o -> o.getCreatedAt() != null)
                        .collect(Collectors.groupingBy(
                                o -> o.getCreatedAt().getYear(),
                                Collectors.summingLong(o -> o.getAmount() != null ? o.getAmount().longValue() : 0L)
                        ));

                for (int y = startYear; y <= targetYear; y++) {
                    trend.add(new DailyMetricDto(String.valueOf(y), map.getOrDefault(y, 0L)));
                }
            }
        } else {
            // 7 ngày gần nhất
            DateTimeFormatter fmt = DateTimeFormatter.ofPattern("dd/MM");
            List<LocalDate> last7Days = new ArrayList<>();
            for (int i = 6; i >= 0; i--) {
                last7Days.add(today.minusDays(i));
            }

            if ("user".equalsIgnoreCase(metric)) {
                List<User> allUsers = userRepository.findAll();
                Map<LocalDate, Long> map = allUsers.stream()
                        .filter(u -> u.getRole() == UserRole.USER && u.getCreatedAt() != null)
                        .collect(Collectors.groupingBy(u -> u.getCreatedAt().toLocalDate(), Collectors.counting()));

                for (LocalDate d : last7Days) {
                    trend.add(new DailyMetricDto(d.format(fmt), map.getOrDefault(d, 0L)));
                }
            } else if ("token".equalsIgnoreCase(metric)) {
                List<UserDailyTokenUsage> usages = tokenUsageRepository.findAll();
                Map<LocalDate, Long> map = usages.stream()
                        .filter(u -> u.getUsageDate() != null)
                        .collect(Collectors.groupingBy(
                                u -> u.getUsageDate(),
                                Collectors.summingLong(u -> u.getTokensUsed() != null ? u.getTokensUsed() : 0L)
                        ));

                for (LocalDate d : last7Days) {
                    trend.add(new DailyMetricDto(d.format(fmt), map.getOrDefault(d, 0L)));
                }
            } else if ("revenue".equalsIgnoreCase(metric)) {
                List<SubscriptionOrder> orders = orderRepository.findByStatus(SubscriptionOrder.OrderStatus.SUCCESS);
                Map<LocalDate, Long> map = orders.stream()
                        .filter(o -> o.getCreatedAt() != null)
                        .collect(Collectors.groupingBy(
                                o -> o.getCreatedAt().toLocalDate(),
                                Collectors.summingLong(o -> o.getAmount() != null ? o.getAmount().longValue() : 0L)
                        ));

                for (LocalDate d : last7Days) {
                    trend.add(new DailyMetricDto(d.format(fmt), map.getOrDefault(d, 0L)));
                }
            }
        }

        return ResponseEntity.ok(ApiResponse.success(trend));
    }
}
