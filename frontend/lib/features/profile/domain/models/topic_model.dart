class TopicModel {
  final int id;
  final String name;

  const TopicModel({
    required this.id,
    required this.name,
  });

  factory TopicModel.fromJson(Map<String, dynamic> json) {
    return TopicModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }

  /// Đọc danh sách chủ đề từ JSON của video.
  static List<TopicModel> listFromJson(dynamic json) {
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(TopicModel.fromJson)
        .where((t) => t.id > 0 && t.name.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
