class MatchingTileModel {
  final String tileId;
  final int cardId;
  final String text;
  final String type; // "TERM" or "MEANING"

  MatchingTileModel({
    required this.tileId,
    required this.cardId,
    required this.text,
    required this.type,
  });

  factory MatchingTileModel.fromJson(Map<String, dynamic> json) {
    return MatchingTileModel(
      tileId: json['tileId'] as String? ?? '',
      cardId: json['cardId'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      type: json['type'] as String? ?? 'TERM',
    );
  }
}

class MatchingGameModel {
  final int setId;
  final int totalPairs;
  final List<MatchingTileModel> tiles;

  MatchingGameModel({
    required this.setId,
    required this.totalPairs,
    required this.tiles,
  });

  factory MatchingGameModel.fromJson(Map<String, dynamic> json) {
    var rawList = json['tiles'] as List? ?? [];
    return MatchingGameModel(
      setId: json['setId'] as int? ?? 0,
      totalPairs: json['totalPairs'] as int? ?? 0,
      tiles: rawList
          .map((e) => MatchingTileModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
