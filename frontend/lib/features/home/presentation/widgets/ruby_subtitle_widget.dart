import 'package:flutter/material.dart';
import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/ruby_segment.dart';

class RubySubtitleWidget extends StatefulWidget {
  final List<RubySegment> rubySegments;
  final String translation;
  final AdaptiveVideoTheme? theme;
  final VoidCallback? onAudioTap;

  const RubySubtitleWidget({
    super.key,
    required this.rubySegments,
    required this.translation,
    this.theme,
    this.onAudioTap,
  });

  @override
  State<RubySubtitleWidget> createState() => _RubySubtitleWidgetState();
}

class _RubySubtitleWidgetState extends State<RubySubtitleWidget> {
  bool _isAudioPlaying = false;

  void _handleAudioTap() {
    setState(() {
      _isAudioPlaying = true;
    });

    widget.onAudioTap?.call();

    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _isAudioPlaying = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? const AdaptiveVideoTheme(isLight: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Subtitle Ruby Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: theme.subtitleCardBackground,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: theme.subtitleCardBorder,
              width: 1.0,
            ),
            boxShadow: theme.cardShadows,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ruby Words
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 6.0,
                  runSpacing: 4.0,
                  children: widget.rubySegments.map((segment) {
                    return _buildRubySegment(segment, theme);
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8.0),
              // TTS Audio Button
              GestureDetector(
                onTap: _handleAudioTap,
                child: AnimatedScale(
                  scale: _isAudioPlaying ? 1.25 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: 28.0,
                    height: 28.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isAudioPlaying
                          ? (theme.isLight
                              ? theme.primaryAdaptive
                              : AppColors.periwinkle)
                          : theme.ttsButtonBackground,
                      border: Border.all(
                        color: theme.subtitleCardBorder,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.isLight
                              ? Colors.black.withValues(alpha: 0.1)
                              : AppColors.periwinkle.withValues(alpha: 0.4),
                          blurRadius: 8.0,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.volume_up_rounded,
                      size: 16.0,
                      color: _isAudioPlaying
                          ? Colors.white
                          : theme.ttsButtonIcon,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6.0),
        // Translation Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: theme.translationCardBackground,
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(
              color: theme.subtitleCardBorder,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: theme.isLight ? 0.05 : 0.3),
                blurRadius: 8.0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            widget.translation,
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w500,
              color: theme.translationTextColor,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRubySegment(RubySegment segment, AdaptiveVideoTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Ruby pronunciation (Furigana)
        Text(
          segment.furigana,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: theme.furiganaColor,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 1.0),
        // Kanji / Kana Text
        Text(
          segment.kanji,
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: theme.kanjiTextColor,
            height: 1.2,
            shadows: theme.isLight
                ? null
                : const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 4.0,
                      offset: Offset(0, 1),
                    ),
                  ],
          ),
        ),
      ],
    );
  }
}
