import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_toast.dart';
import '../models/subscription_model.dart';
import '../models/token_usage_model.dart';
import '../services/subscription_service.dart';
import '../widgets/subscription_plan_sheet.dart';
import '../widgets/subscription_success_dialog.dart';
import '../widgets/vietqr_payment_sheet.dart';

/// Trang "Token AI" trong Cài đặt: còn bao nhiêu token hôm nay, đã dùng thế nào trong tuần / tháng và dùng cho
/// tính năng nào.
///
/// Hạn mức tính theo NGÀY (mỗi gói có số token mỗi ngày) và làm mới mỗi ngày, nên thẻ trên cùng là "Còn lại hôm nay".
class TokenUsageScreen extends StatefulWidget {
  const TokenUsageScreen({super.key});

  @override
  State<TokenUsageScreen> createState() => _TokenUsageScreenState();
}

class _TokenUsageScreenState extends State<TokenUsageScreen> {
  final SubscriptionService _service = SubscriptionService.instance;

  SubscriptionStatus? _status;
  final Map<String, TokenUsage> _usage = {};
  String _range = 'week';
  int? _selected;

  bool _loading = true;
  bool _switching = false;

  TokenUsage? get _current => _usage[_range];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = _status == null;
    });

    final isInitialLoad = _status == null || _current == null;
    var attempt = 0;
    // Lần tải đầu luôn giữ trạng thái loading và tiếp tục thử trong nền. Khi đã
    // có dữ liệu, làm mới chỉ thử hữu hạn rồi giữ nguyên nội dung đang hiển thị.
    while (mounted && (isInitialLoad || attempt < 3)) {
      try {
        final results = await Future.wait<Object>([
          _service.getMyStatus(),
          _service.getTokenUsage(_range),
        ]);
        if (!mounted) return;
        final usage = results[1] as TokenUsage;
        setState(() {
          _status = results[0] as SubscriptionStatus;
          if (refresh) _usage.clear();
          _usage[_range] = usage;
          _selected = _defaultSelected(usage);
          _loading = false;
        });
        return;
      } catch (_) {
        attempt++;
        final delay = attempt == 1
            ? const Duration(milliseconds: 700)
            : attempt == 2
            ? const Duration(milliseconds: 1400)
            : attempt == 3
            ? const Duration(seconds: 3)
            : const Duration(seconds: 5);
        await Future<void>.delayed(delay);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Ngày được chọn sẵn: hôm nay nếu nằm trong khoảng, không thì ngày gần nhất có dùng token.
  int _defaultSelected(TokenUsage usage) {
    final now = DateTime.now();
    final today = usage.days.indexWhere((d) => d.date.year == now.year && d.date.month == now.month && d.date.day == now.day);
    if (today >= 0) return today;
    final lastUsed = usage.days.lastIndexWhere((d) => d.tokens > 0);
    return lastUsed >= 0 ? lastUsed : 0;
  }

  Future<void> _setRange(String range) async {
    if (range == _range || _switching) return;
    final previous = _range;
    final cached = _usage[range];
    if (cached != null) {
      setState(() {
        _range = range;
        _selected = _defaultSelected(cached);
      });
      return;
    }
    setState(() {
      _range = range;
      _switching = true;
    });
    try {
      final usage = await _service.getTokenUsage(range);
      if (!mounted) return;
      setState(() {
        _usage[range] = usage;
        _selected = _defaultSelected(usage);
        _switching = false;
      });
    } on ApiException catch (error) {
      _revert(previous, error.message);
    } catch (_) {
      _revert(previous, 'Không tải được dữ liệu token.');
    }
  }

  void _revert(String previous, String message) {
    if (!mounted) return;
    setState(() {
      _range = previous;
      _switching = false;
    });
    AppToast.showError(message, context: context);
  }

  Future<void> _openUpgradeSheet() async {
    final plan = await showSubscriptionPlanSheet(context, initiallyPremium: true);
    if (!mounted || plan == null) return;

    try {
      final order = await _service.createOrder(planId: plan.id);
      if (!mounted) return;
      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => VietQrPaymentSheet(order: order, plan: plan),
        ),
      );
      if (!mounted) return;
      if (paid == true) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => SubscriptionSuccessDialog(order: order, plan: plan, onDismiss: () {}),
        );
        if (mounted) await _load(refresh: true);
      }
    } on ApiException catch (error) {
      if (mounted) AppToast.showError(error.message, context: context);
    } catch (_) {
      if (mounted) AppToast.showError('Không tạo được đơn thanh toán. Vui lòng thử lại.', context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              key: const ValueKey('token-back'),
              tooltip: 'Quay lại',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.chevron_left_rounded, size: 30, color: AppPalette.textPrimary),
            ),
          ),
          Text(
            'Token AI',
            style: TextStyle(color: AppPalette.textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppPalette.accent));
    }
    final status = _status;
    final usage = _current;
    if (status == null || usage == null) {
      return Center(child: CircularProgressIndicator(color: AppPalette.accent));
    }
    return RefreshIndicator(
      color: AppPalette.accent,
      backgroundColor: AppPalette.surface,
      onRefresh: () => _load(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _buildQuotaCard(status),
          const SizedBox(height: 28),
          _buildUsageSection(usage),
          const SizedBox(height: 28),
          _buildFeatureSection(usage),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------- thẻ hạn mức hôm nay

  Widget _buildQuotaCard(SubscriptionStatus status) {
    final limit = status.dailyTokenLimit;
    final used = status.tokensUsedToday;
    final remaining = status.tokensRemainingToday;
    final ratio = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
    final isRunningLow = limit > 0 && remaining / limit <= 0.1;
    final quotaColor = isRunningLow ? AppPalette.warning : AppPalette.accent;
    final planLabel = status.isVip ? (status.planName ?? 'Gói trả phí') : 'Miễn phí';
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final resetOn = '${tomorrow.day.toString().padLeft(2, '0')}/${tomorrow.month.toString().padLeft(2, '0')}';

    return Container(
      key: const ValueKey('token-quota-card'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppPalette.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppPalette.surfaceHigh, AppPalette.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Còn lại hôm nay', style: TextStyle(color: AppPalette.textSecondary, fontSize: 14.5)),
              ),
              Container(
                key: const ValueKey('token-plan-badge'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: status.isVip ? AppPalette.accent.withValues(alpha: 0.2) : AppPalette.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  planLabel,
                  style: TextStyle(
                    color: status.isVip ? AppPalette.accent : AppPalette.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(
                formatTokenCount(remaining),
                key: const ValueKey('token-remaining'),
                style: TextStyle(
                  color: isRunningLow ? AppPalette.warning : AppPalette.textPrimary,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  '/ ${formatTokenCount(limit)} token',
                  style: TextStyle(color: AppPalette.textSecondary, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 10, color: AppPalette.border.withValues(alpha: 0.7)),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    key: const ValueKey('token-quota-fill'),
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isRunningLow ? [quotaColor, quotaColor] : [quotaColor, AppPalette.info],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Đã dùng ${formatTokenCount(used)}',
                  style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
                ),
              ),
              Text('Làm mới $resetOn', style: TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          if (status.isVip)
            Text(
              status.isLifetime ? 'Gói trọn đời' : 'Hết hạn ${status.formattedExpiryDate} · còn ${status.daysRemaining} ngày',
              key: const ValueKey('token-plan-expiry'),
              style: TextStyle(color: AppPalette.textSecondary, fontSize: 12.5),
            )
          else
            InkWell(
              key: const ValueKey('token-upgrade'),
              onTap: _openUpgradeSheet,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'Nâng cấp gói để có thêm token mỗi ngày',
                  style: TextStyle(color: AppPalette.info, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------- biểu đồ mức dùng

  Widget _buildUsageSection(TokenUsage usage) {
    final selected = (_selected ?? 0).clamp(0, usage.days.isEmpty ? 0 : usage.days.length - 1);
    final day = usage.days.isEmpty ? null : usage.days[selected];
    final monthWeeks = usage.isMonth ? _groupMonthByWeek(usage.days) : <_MonthWeek>[];
    final selectedWeek = monthWeeks.isEmpty
        ? 0
        : monthWeeks.indexWhere((week) => selected >= week.firstDayIndex && selected <= week.lastDayIndex);
    final activeWeek = monthWeeks.isEmpty ? null : monthWeeks[selectedWeek < 0 ? 0 : selectedWeek];
    final displayedTokens = activeWeek?.tokens ?? day?.tokens ?? 0;
    final caption = activeWeek != null
        ? 'Tuần ${activeWeek.number} (${activeWeek.startDay}–${activeWeek.endDay}/${activeWeek.month})'
        : day?.weekdayFull ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mức dùng',
                style: TextStyle(color: AppPalette.textPrimary, fontSize: 19, fontWeight: FontWeight.w800),
              ),
            ),
            _RangeToggle(range: _range, onChanged: _setRange),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          key: const ValueKey('token-chart-card'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppPalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (day != null)
                Text.rich(
                  key: const ValueKey('token-chart-caption'),
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${formatTokenCount(displayedTokens)} token',
                        style: TextStyle(color: AppPalette.textPrimary, fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: ' · $caption', style: TextStyle(color: AppPalette.textSecondary)),
                    ],
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              const SizedBox(height: 14),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _switching ? 0.35 : 1,
                child: _UsageChart(
                  days: usage.days,
                  selected: selected,
                  isMonth: usage.isMonth,
                  onSelect: (i) => setState(() {
                    _selected = usage.isMonth ? monthWeeks[i].firstDayIndex : i;
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------- dùng cho tính năng

  Widget _buildFeatureSection(TokenUsage usage) {
    final total = usage.features.fold<int>(0, (sum, f) => sum + f.tokens);
    final colors = [AppPalette.accent, AppPalette.info];
    final period = usage.isMonth ? 'Tháng này' : 'Tuần này';

    return Column(
      key: const ValueKey('token-features'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Dùng cho tính năng',
                style: TextStyle(color: AppPalette.textPrimary, fontSize: 19, fontWeight: FontWeight.w800),
              ),
            ),
            Text(period, style: TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < usage.features.length; i++)
          _FeatureRow(
            key: ValueKey('token-feature-${usage.features[i].feature}'),
            label: usage.features[i].label,
            tokens: usage.features[i].tokens,
            percent: total <= 0 ? 0 : (usage.features[i].tokens * 100 / total).round(),
            color: colors[i % colors.length],
            showDivider: i < usage.features.length - 1,
          ),
      ],
    );
  }
}

/// Nút chuyển Tuần | Tháng.
class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.range, required this.onChanged});

  final String range;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String value, String label) {
      final active = range == value;
      return GestureDetector(
        key: ValueKey('token-range-$value'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppPalette.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppPalette.onAccent : AppPalette.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppPalette.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [option('week', 'Tuần'), option('month', 'Tháng')]),
    );
  }
}

class _MonthWeek {
  const _MonthWeek({
    required this.number,
    required this.firstDayIndex,
    required this.lastDayIndex,
    required this.startDay,
    required this.endDay,
    required this.month,
    required this.tokens,
  });

  final int number;
  final int firstDayIndex;
  final int lastDayIndex;
  final int startDay;
  final int endDay;
  final int month;
  final int tokens;
}

/// Chia tháng thành bốn lượt dễ đọc: 1–7, 8–14, 15–21 và 22–hết tháng.
List<_MonthWeek> _groupMonthByWeek(List<TokenDayUsage> days) {
  if (days.isEmpty) return const [];
  final result = <_MonthWeek>[];
  for (var week = 0; week < 4; week++) {
    final startDay = week * 7 + 1;
    final endDay = week == 3 ? days.last.date.day : (week + 1) * 7;
    final indexes = <int>[
      for (var i = 0; i < days.length; i++)
        if (days[i].date.day >= startDay && days[i].date.day <= endDay) i,
    ];
    if (indexes.isEmpty) continue;
    result.add(
      _MonthWeek(
        number: week + 1,
        firstDayIndex: indexes.first,
        lastDayIndex: indexes.last,
        startDay: days[indexes.first].date.day,
        endDay: days[indexes.last].date.day,
        month: days[indexes.first].date.month,
        tokens: indexes.fold<int>(0, (sum, index) => sum + days[index].tokens),
      ),
    );
  }
  return result;
}

/// Biểu đồ cột: tuần có 7 cột (T2..CN), tháng được gom thành 4 cột tuần.
class _UsageChart extends StatelessWidget {
  const _UsageChart({required this.days, required this.selected, required this.isMonth, required this.onSelect});

  final List<TokenDayUsage> days;
  final int selected;
  final bool isMonth;
  final ValueChanged<int> onSelect;

  static const double _chartHeight = 150;

  @override
  Widget build(BuildContext context) {
    final monthWeeks = isMonth ? _groupMonthByWeek(days) : <_MonthWeek>[];
    final values = isMonth ? monthWeeks.map((week) => week.tokens).toList() : days.map((day) => day.tokens).toList();
    final selectedBar = isMonth
        ? monthWeeks.indexWhere((week) => selected >= week.firstDayIndex && selected <= week.lastDayIndex)
        : selected;
    final maxTokens = values.fold<int>(0, (m, tokens) => tokens > m ? tokens : m);

    double heightOf(int tokens) {
      if (maxTokens <= 0 || tokens <= 0) return 5;
      return (tokens / maxTokens * (_chartHeight - 6)).clamp(8.0, _chartHeight);
    }

    String labelOf(int index) => isMonth ? 'Tuần ${index + 1}' : weekdayShortOf(days[index].date);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: GestureDetector(
              key: ValueKey('token-bar-$i'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(i),
              child: Column(
                children: [
                  SizedBox(
                    height: _chartHeight,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                          widthFactor: isMonth ? 0.88 : 0.62,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          height: heightOf(values[i]),
                          decoration: BoxDecoration(
                            color: i == selectedBar ? AppPalette.info : AppPalette.accent.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(isMonth ? 9 : 9),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 16,
                    child: OverflowBox(
                      maxWidth: 30,
                      child: Text(
                        labelOf(i),
                        softWrap: false,
                        style: TextStyle(
                          color: i == selectedBar ? AppPalette.textPrimary : AppPalette.textSecondary,
                          fontSize: isMonth ? 12 : 12.5,
                          fontWeight: i == selectedBar ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Một dòng "tính năng": chấm màu, tên, số token, phần trăm và thanh tỉ lệ.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    super.key,
    required this.label,
    required this.tokens,
    required this.percent,
    required this.color,
    required this.showDivider,
  });

  final String label;
  final int tokens;
  final int percent;
  final Color color;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: showDivider ? Border(bottom: BorderSide(color: AppPalette.border)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: AppPalette.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatTokenCount(tokens),
                style: TextStyle(color: AppPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              SizedBox(
                width: 46,
                child: Text(
                  '$percent%',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: AppPalette.textSecondary, fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 5, color: AppPalette.border.withValues(alpha: 0.7)),
                FractionallySizedBox(
                  widthFactor: (percent / 100).clamp(0.0, 1.0),
                  child: Container(height: 5, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
