import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/app_palette.dart';
import '../../data/services/dictionary_service.dart';
import '../../domain/models/ruby_segment.dart';

/// Màu gạch chân chuẩn để phân biệt Từ vựng (xanh dương) và Ngữ pháp (cam).
const Color kVocabUnderlineColor = Color(0xFF38BDF8);
const Color kGrammarUnderlineColor = Color(0xFFF59E0B);

/// Một đoạn văn bản trong câu tiếng Nhật sau khi ghép kết quả tách từ (Kuromoji)
/// và điểm ngữ pháp (AI Grammar Analysis).
class InteractiveSentenceSegment {
  final String text;
  final SubtitleToken? token;
  final GrammarPointInfo? grammar;

  const InteractiveSentenceSegment({
    required this.text,
    this.token,
    this.grammar,
  });

  bool get isGrammar => grammar != null;
  bool get isVocab => grammar == null && token != null && token!.lookupable;
  bool get isInteractive => isGrammar || isVocab;
}

class _GrammarRange {
  final int start;
  final int end;
  final GrammarPointInfo point;

  const _GrammarRange(this.start, this.end, this.point);

  bool overlaps(int s, int e) => math.max(start, s) < math.min(end, e);
}

class _TokenRange {
  final int start;
  final int end;
  final SubtitleToken token;

  const _TokenRange(this.start, this.end, this.token);
}

/// Ghép danh sách token từ vựng và các mẫu ngữ pháp trong [sentence] thành các đoạn liên tiếp:
/// - Đoạn ngữ pháp (`isGrammar == true`): gạch chân màu cam [kGrammarUnderlineColor].
/// - Đoạn từ vựng (`isVocab == true`): gạch chân màu xanh [kVocabUnderlineColor].
/// - Đoạn trợ từ / dấu câu thông thường: không gạch chân.
List<InteractiveSentenceSegment> buildInteractiveSegments({
  required String sentence,
  required List<SubtitleToken> tokens,
  required List<GrammarPointInfo> grammarPoints,
}) {
  if (sentence.isEmpty) return const [];

  final effectiveGrammar = grammarPoints;

  // 1. Xác định vị trí [start, end) của từng mẫu ngữ pháp trong câu.
  final grammarRanges = <_GrammarRange>[];
  for (final gp in effectiveGrammar) {
    var needle = gp.matchedText.trim();
    if (needle.isEmpty) {
      needle = gp.pattern.replaceAll('〜', '').replaceAll('~', '').trim();
    }
    if (needle.isEmpty) continue;

    var searchFrom = 0;
    while (searchFrom < sentence.length) {
      final idx = sentence.indexOf(needle, searchFrom);
      if (idx < 0) break;
      var gStart = idx;
      final gEnd = idx + needle.length;
      // Gộp thân động từ "し" đứng ngay trước "ましょう" -> "しましょう"
      if (needle == 'ましょう' && gStart > 0 && sentence[gStart - 1] == 'し') {
        gStart -= 1;
      }
      final overlapsExisting = grammarRanges.any((r) => r.overlaps(gStart, gEnd));
      if (!overlapsExisting) {
        grammarRanges.add(_GrammarRange(gStart, gEnd, gp));
        break;
      }
      searchFrom = idx + 1;
    }
  }
  grammarRanges.sort((a, b) => a.start.compareTo(b.start));

  // 2. Xác định vị trí [start, end) của từng token Kuromoji và gộp đuôi chia thể lịch sự
  // (vd. 始め + ます -> 始めます) nếu không trùng với vùng ngữ pháp.
  final rawTokenRanges = <_TokenRange>[];
  var cursor = 0;
  for (final t in tokens) {
    if (t.surface.isEmpty) continue;
    final found = sentence.indexOf(t.surface, cursor);
    final start = found >= 0 ? found : cursor;
    final end = math.min(sentence.length, start + t.surface.length);
    if (end > start) {
      rawTokenRanges.add(_TokenRange(start, end, t));
      cursor = end;
    }
  }

  const politeAuxiliaries = {'ます', 'ました', 'ません', 'た', 'て', 'ない'};
  final mergedTokens = <_TokenRange>[];
  for (final current in rawTokenRanges) {
    if (mergedTokens.isNotEmpty) {
      final prev = mergedTokens.last;
      final prevIsLookupable = prev.token.lookupable;
      final currIsPoliteAux = !current.token.lookupable &&
          politeAuxiliaries.contains(current.token.surface);
      final touchesGrammar = grammarRanges.any(
        (g) => g.overlaps(prev.start, current.end),
      );

      if (prevIsLookupable &&
          currIsPoliteAux &&
          prev.end == current.start &&
          !touchesGrammar) {
        mergedTokens[mergedTokens.length - 1] = _TokenRange(
          prev.start,
          current.end,
          SubtitleToken(
            surface: sentence.substring(prev.start, current.end),
            baseForm: prev.token.baseForm,
            reading: prev.token.reading,
            lookupable: true,
          ),
        );
        continue;
      }
    }
    mergedTokens.add(current);
  }

  // 3. Duyệt từ đầu đến cuối câu để tạo danh sách InteractiveSentenceSegment.
  final segments = <InteractiveSentenceSegment>[];
  var pos = 0;
  while (pos < sentence.length) {
    // Ưu tiên vùng ngữ pháp bắt đầu tại pos
    _GrammarRange? activeGrammar;
    for (final g in grammarRanges) {
      if (g.start == pos) {
        activeGrammar = g;
        break;
      }
    }
    if (activeGrammar != null) {
      segments.add(
        InteractiveSentenceSegment(
          text: sentence.substring(activeGrammar.start, activeGrammar.end),
          grammar: activeGrammar.point,
        ),
      );
      pos = activeGrammar.end;
      continue;
    }

    // Tìm mốc bắt đầu vùng ngữ pháp tiếp theo (để cắt token nếu cần)
    var nextGrammarStart = sentence.length;
    for (final g in grammarRanges) {
      if (g.start > pos) {
        nextGrammarStart = g.start;
        break;
      }
    }

    // Tìm token chứa vị trí pos
    _TokenRange? coveringToken;
    for (final tr in mergedTokens) {
      if (tr.start <= pos && tr.end > pos) {
        coveringToken = tr;
        break;
      }
    }

    if (coveringToken != null) {
      final segEnd = math.min(coveringToken.end, nextGrammarStart);
      final subText = sentence.substring(pos, segEnd);
      // Nếu phần còn lại chỉ là thân 1 chữ "し" của "する" ngay sát trước mẫu ngữ pháp thì gộp vào ngữ pháp
      if (coveringToken.token.lookupable && subText.trim().isNotEmpty) {
        segments.add(
          InteractiveSentenceSegment(
            text: subText,
            token: coveringToken.token,
          ),
        );
      } else {
        segments.add(InteractiveSentenceSegment(text: subText));
      }
      pos = segEnd;
    } else {
      // Ký tự nằm ngoài token (khoảng trắng, dấu câu...)
      var nextTokenStart = nextGrammarStart;
      for (final tr in mergedTokens) {
        if (tr.start > pos) {
          nextTokenStart = math.min(nextTokenStart, tr.start);
          break;
        }
      }
      final segEnd = math.max(pos + 1, nextTokenStart);
      segments.add(
        InteractiveSentenceSegment(text: sentence.substring(pos, segEnd)),
      );
      pos = segEnd;
    }
  }

  return segments;
}

/// Bảng giải thích ngữ pháp khi người dùng chạm vào phần gạch chân màu cam.
class GrammarLookupCard extends StatelessWidget {
  final GrammarPointInfo grammar;
  final String sentence;
  final VoidCallback onClose;

  const GrammarLookupCard({
    super.key,
    required this.grammar,
    required this.sentence,
    required this.onClose,
  });

  static const double _cardWidth = 288.0;

  @override
  Widget build(BuildContext context) {
    final patternText = grammar.pattern.isNotEmpty
        ? grammar.pattern
        : grammar.matchedText;
    final speakText = grammar.matchedText.isNotEmpty
        ? grammar.matchedText
        : patternText.replaceAll('〜', '').replaceAll('~', '');
    final showMatched = grammar.matchedText.isNotEmpty &&
        grammar.matchedText != patternText &&
        '〜${grammar.matchedText}' != patternText;

    return Container(
      width: _cardWidth,
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 15),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: kGrammarUnderlineColor.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.shadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Nhãn Ngữ pháp + Pattern + Loa | JLPT badge + Nút đóng
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: kGrammarUnderlineColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Ngữ pháp',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: kGrammarUnderlineColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            patternText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.textPrimary,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (speakText.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          InkResponse(
                            onTap: () => TtsService.speak(text: speakText),
                            radius: 18,
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: Icon(
                                Icons.volume_up_rounded,
                                size: 20,
                                color: AppPalette.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (showMatched)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Trong câu: ${grammar.matchedText}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppPalette.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (grammar.jlptLevel.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: kGrammarUnderlineColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: kGrammarUnderlineColor.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Text(
                        grammar.jlptLevel,
                        style: const TextStyle(
                          color: kGrammarUnderlineColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  InkResponse(
                    onTap: onClose,
                    radius: 18,
                    child: SizedBox(
                      width: 30,
                      height: 28,
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppPalette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (grammar.meaning.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: kGrammarUnderlineColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'Ý nghĩa',
                          style: TextStyle(
                            color: kGrammarUnderlineColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    TextSpan(
                      text: grammar.meaning,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (grammar.explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: AppPalette.border),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                grammar.explanation,
                style: TextStyle(
                  fontSize: 13,
                  color: AppPalette.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

