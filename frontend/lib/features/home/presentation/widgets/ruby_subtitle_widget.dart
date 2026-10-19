import 'package:flutter/material.dart';

import '../../../../core/theme/adaptive_video_theme.dart';
import '../../domain/models/ruby_segment.dart';

class RubySubtitleWidget extends StatefulWidget {
  final List<RubySegment> rubySegments;
  final String translation;
  final AdaptiveVideoTheme? theme;

  const RubySubtitleWidget({
    super.key,
    required this.rubySegments,
    required this.translation,
    this.theme,
  });

  @override
  State<RubySubtitleWidget> createState() => _RubySubtitleWidgetState();
}

class _RubySubtitleWidgetState extends State<RubySubtitleWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? const AdaptiveVideoTheme(isLight: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 6.0,
          runSpacing: 4.0,
          children: widget.rubySegments.map((segment) {
            return _buildRubySegment(segment, theme);
          }).toList(),
        ),
        const SizedBox(height: 6.0),
        Text(
          widget.translation,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.25,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 4.0),
              Shadow(color: Colors.black87, blurRadius: 1.0),
            ],
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
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.2,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 5.0),
              Shadow(color: Colors.black87, blurRadius: 1.0),
            ],
          ),
        ),
      ],
    );
  }
}
