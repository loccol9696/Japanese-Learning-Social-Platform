import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_toast.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';

Future<SubscriptionPlan?> showSubscriptionPlanSheet(
  BuildContext context, {
  bool initiallyPremium = true,
}) {
  return showModalBottomSheet<SubscriptionPlan>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SubscriptionPlanSheet(initiallyPremium: initiallyPremium),
  );
}

class _SubscriptionPlanSheet extends StatefulWidget {
  const _SubscriptionPlanSheet({required this.initiallyPremium});

  final bool initiallyPremium;

  @override
  State<_SubscriptionPlanSheet> createState() => _SubscriptionPlanSheetState();
}

class _SubscriptionPlanSheetState extends State<_SubscriptionPlanSheet> {
  late bool _showPremium;
  late final Future<List<SubscriptionPlan>> _plans = _loadPlans();
  List<SubscriptionPlan> _availablePlans = const [];
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _showPremium = widget.initiallyPremium;
  }

  Future<List<SubscriptionPlan>> _loadPlans() async {
    final plans = await SubscriptionService.instance.getPlans();
    plans.sort((a, b) => b.durationDays.compareTo(a.durationDays));
    _availablePlans = plans;
    return plans;
  }

  void _upgrade() {
    if (_availablePlans.isEmpty) {
      AppToast.showError('Hiện chưa có gói Premium khả dụng.', context: context);
      return;
    }
    final index = _selected < _availablePlans.length ? _selected : 0;
    Navigator.of(context).pop(_availablePlans[index]);
  }

  @override
  Widget build(BuildContext context) {
    final availableHeight = MediaQuery.sizeOf(context).height * 0.94;
    final height = availableHeight < 620.0 ? availableHeight : 620.0;
    return Material(
      color: AppPalette.navBar,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppPalette.textSecondary.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Gói của bạn',
                        style: TextStyle(color: AppPalette.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: AppPalette.textSecondary),
                    ),
                  ],
                ),
              ),
              _buildTabs(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: _showPremium ? _buildPremium() : _buildFree(),
                ),
              ),
              if (_showPremium)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _upgrade,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.accent,
                        foregroundColor: AppPalette.onAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Nâng cấp Premium', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    Widget tab(String label, bool selected) => Expanded(
      child: InkWell(
        onTap: () => setState(() => _showPremium = label == 'Premium'),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppPalette.surfaceHighest : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppPalette.textPrimary : AppPalette.textSecondary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppPalette.background, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [tab('Miễn phí', !_showPremium), tab('Premium', _showPremium)]),
    );
  }

  Widget _buildFree() => Column(
    children: const [
      _Feature(text: 'Hạn mức 50 token AI mỗi ngày'),
      _Feature(text: 'Xem video bài học cơ bản'),
      _Feature(text: 'Flashcard từ vựng N5'),
    ],
  );

  Widget _buildPremium() => Column(
    children: [
      const _Feature(text: 'Tạo bộ thẻ không giới hạn'),
      const _Feature(text: 'Học và ôn tập không quảng cáo'),
      const _Feature(text: 'Luyện nghe, tự luận không giới hạn'),
      const _Feature(text: 'Đồng bộ trên mọi thiết bị'),
      const SizedBox(height: 8),
      FutureBuilder<List<SubscriptionPlan>>(
        future: _plans,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Không tải được danh sách gói.', style: TextStyle(color: AppPalette.textSecondary));
          }
          if (!snapshot.hasData) {
            return const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2));
          }
          final plans = snapshot.data!;
          if (plans.isEmpty) {
            return Text('Chưa có gói Premium khả dụng.', style: TextStyle(color: AppPalette.textSecondary));
          }
          if (_selected >= plans.length) _selected = 0;
          return Column(
            children: [for (var i = 0; i < plans.length; i++) _planOption(plans[i], i)],
          );
        },
      ),
    ],
  );

  Widget _planOption(SubscriptionPlan plan, int index) {
    final selected = index == _selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _selected = index),
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppPalette.accent.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: selected ? AppPalette.accent : AppPalette.border, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? AppPalette.accent : AppPalette.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan.durationLabel.toLowerCase(),
                  style: TextStyle(color: AppPalette.textPrimary, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                plan.formattedPrice.replaceAll(' ', ''),
                style: TextStyle(color: AppPalette.textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(Icons.check_rounded, color: AppPalette.info, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: AppPalette.textPrimary, fontSize: 15.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
