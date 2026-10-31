import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../profile/domain/models/topic_model.dart';
import '../../data/hashtag_service.dart';
import '../../domain/hashtag_rules.dart';

/// Phân loại video: chọn chủ đề (metadata của hệ thống) và nhập hashtag (người đăng tự gõ).
/// Dùng chung cho màn đăng video, hộp thoại sửa video và màn kiểm duyệt.
class VideoClassificationFields extends StatefulWidget {
  /// Chủ đề được chọn; rỗng thì ẩn phần chủ đề (ví dụ tải danh sách lỗi), vẫn nhập được hashtag.
  final List<TopicModel> topics;
  final Set<int> selectedTopicIds;
  final ValueChanged<Set<int>> onTopicsChanged;
  final List<String> hashtags;
  final ValueChanged<List<String>> onHashtagsChanged;
  final HashtagService? hashtagService;

  const VideoClassificationFields({
    super.key,
    required this.topics,
    required this.selectedTopicIds,
    required this.onTopicsChanged,
    required this.hashtags,
    required this.onHashtagsChanged,
    this.hashtagService,
  });

  @override
  VideoClassificationFieldsState createState() => VideoClassificationFieldsState();
}

class VideoClassificationFieldsState extends State<VideoClassificationFields> {
  final TextEditingController _controller = TextEditingController();
  late final HashtagService _service = widget.hashtagService ?? HashtagService();
  Timer? _debounce;
  List<String> _suggestions = const [];
  String? _error;

  /// Tăng mỗi lần ô nhập đổi để bỏ qua kết quả gợi ý của lần gõ trước.
  int _requestToken = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Thêm phần chữ đang gõ dở thành hashtag, gọi trước khi lưu để không mất thẻ chưa bấm xác nhận.
  /// Trả false nếu phần chữ đó không hợp lệ.
  bool commitPending() {
    final text = _controller.text;
    if (text.trim().isEmpty) return true;
    final added = _addHashtags([text]);
    if (added) _controller.clear();
    return added;
  }

  void _toggleTopic(int id) {
    final next = Set<int>.of(widget.selectedTopicIds);
    if (next.remove(id)) {
      setState(() => _error = null);
    } else if (next.length >= maxTopicsPerVideo) {
      setState(() => _error = 'Chỉ được chọn tối đa $maxTopicsPerVideo chủ đề.');
      return;
    } else {
      next.add(id);
      setState(() => _error = null);
    }
    widget.onTopicsChanged(next);
  }

  /// Thêm các thẻ trong một lần gọi: [widget.hashtags] chỉ cập nhật ở khung hình sau, nên gọi từng thẻ
  /// một (khi dán "#a #b") sẽ làm thẻ sau đè mất thẻ trước. Trả false nếu có thẻ không thêm được.
  bool _addHashtags(Iterable<String> rawNames) {
    final next = [...widget.hashtags];
    String? error;
    for (final raw in rawNames) {
      final name = normalizeHashtag(raw);
      if (name.isEmpty || next.contains(name)) continue;
      if (!isValidHashtag(name)) {
        error = 'Hashtag chỉ gồm chữ, số, dấu gạch dưới, tối đa $maxHashtagLength ký tự.';
        break;
      }
      if (next.length >= maxHashtagsPerVideo) {
        error = 'Chỉ được gắn tối đa $maxHashtagsPerVideo hashtag.';
        break;
      }
      next.add(name);
    }
    final changed = next.length != widget.hashtags.length;
    setState(() {
      _error = error;
      if (changed) _suggestions = const [];
    });
    if (changed) widget.onHashtagsChanged(next);
    return error == null;
  }

  void _removeHashtag(String name) {
    setState(() => _error = null);
    widget.onHashtagsChanged(widget.hashtags.where((tag) => tag != name).toList());
  }

  /// Dấu cách hoặc dấu phẩy kết thúc một thẻ, giống cách gõ hashtag trên mạng xã hội.
  void _onChanged(String value) {
    final parts = value.split(RegExp(r'[\s,]+'));
    if (parts.length > 1 && _addHashtags(parts.take(parts.length - 1))) {
      _controller.value = TextEditingValue(
        text: parts.last,
        selection: TextSelection.collapsed(offset: parts.last.length),
      );
    }
    _loadSuggestions(normalizeHashtag(parts.last));
  }

  void _loadSuggestions(String query) {
    _debounce?.cancel();
    final token = ++_requestToken;
    if (query.isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final found = await _service.suggest(query);
        if (!mounted || token != _requestToken) return;
        setState(() => _suggestions = found);
      } catch (_) {
        // Gợi ý chỉ là phần phụ: lỗi mạng thì vẫn gõ tay được.
      }
    });
  }

  void _pickSuggestion(String name) {
    if (_addHashtags([name])) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions.where((tag) => !widget.hashtags.contains(tag)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.topics.isNotEmpty) ...[
          _title('Chủ đề (tuỳ chọn, tối đa $maxTopicsPerVideo)'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.topics.map(_topicChip).toList(),
          ),
          const SizedBox(height: 22),
        ],
        _title('Hashtag (tuỳ chọn, tối đa $maxHashtagsPerVideo)'),
        const SizedBox(height: 10),
        if (widget.hashtags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.hashtags.map(_hashtagChip).toList(),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          onSubmitted: (_) => commitPending(),
          textInputAction: TextInputAction.done,
          style: TextStyle(color: AppPalette.textPrimary),
          decoration: InputDecoration(
            hintText: 'Nhập rồi cách để thêm, ví dụ #anime',
            hintStyle: TextStyle(color: AppPalette.textSecondary, fontSize: 14),
            filled: true,
            fillColor: AppPalette.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppPalette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppPalette.border),
            ),
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map(
                  (tag) => ActionChip(
                    label: Text('#$tag'),
                    onPressed: () => _pickSuggestion(tag),
                    backgroundColor: AppPalette.background,
                    side: BorderSide(color: AppPalette.border),
                    labelStyle: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
                  ),
                )
                .toList(),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: AppPalette.error, fontSize: 13)),
        ],
      ],
    );
  }

  Widget _title(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16));
  }

  Widget _topicChip(TopicModel topic) {
    final selected = widget.selectedTopicIds.contains(topic.id);
    return FilterChip(
      label: Text(topic.name),
      selected: selected,
      onSelected: (_) => _toggleTopic(topic.id),
      selectedColor: AppPalette.accent,
      backgroundColor: AppPalette.background,
      side: BorderSide(color: AppPalette.border),
      labelStyle: TextStyle(
        color: selected ? AppPalette.onAccent : AppPalette.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      showCheckmark: false,
    );
  }

  Widget _hashtagChip(String tag) {
    return InputChip(
      label: Text('#$tag'),
      onDeleted: () => _removeHashtag(tag),
      backgroundColor: AppPalette.background,
      side: BorderSide(color: AppPalette.border),
      labelStyle: TextStyle(color: AppPalette.textPrimary, fontWeight: FontWeight.w600),
      deleteIconColor: AppPalette.textSecondary,
    );
  }
}
