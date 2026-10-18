import 'package:flutter/foundation.dart';
import '../models/flashcard_item_model.dart';
import '../models/flashcard_set_model.dart';
import 'flashcard_service.dart';

/// Quản lý dữ liệu tập trung (Global Cache Store) chuẩn Quizlet:
/// 1. Cache-First: Phản hồi 0ms từ RAM/Cache.
/// 2. Stale-While-Revalidate: Kiểm tra dữ liệu ngầm sau 5-10 phút mà không làm rung giật UI.
/// 3. Optimistic Updates: Cập nhật giao diện tức thì, tự động rollback nếu API lỗi.
/// 4. Lazy Load Detail: Nạp tóm tắt ở Thư viện, nạp chi tiết khi vào Chi tiết và lưu đệm theo setId.
class FlashcardStore with ChangeNotifier {
  static FlashcardStore? _instance;
  FlashcardStore._();
  static FlashcardStore get instance => _instance ??= FlashcardStore._();

  final FlashcardService _service = FlashcardService.instance;

  // Thời gian sống của cache trước khi coi là stale (5 phút)
  final Duration _staleDuration = const Duration(minutes: 5);

  // Cache danh sách bộ thẻ tóm tắt (Library)
  List<FlashcardSetModel>? _cachedSets;
  DateTime? _setsLastFetched;
  bool _isSyncingSets = false;

  // Cache danh sách từ vựng chi tiết theo setId (Detail/Overview)
  final Map<int, List<FlashcardItemModel>> _cachedCardsBySetId = {};
  final Map<int, DateTime> _cardsLastFetchedBySetId = {};
  final Set<int> _syncingSetIds = {};

  // Getters
  List<FlashcardSetModel>? get cachedSets => _cachedSets;
  bool hasCachedSets() => _cachedSets != null;
  bool isSetsStale() =>
      _setsLastFetched == null ||
      DateTime.now().difference(_setsLastFetched!) > _staleDuration;

  bool hasCachedCards(int setId) => _cachedCardsBySetId.containsKey(setId);
  List<FlashcardItemModel>? getCachedCards(int setId) =>
      _cachedCardsBySetId[setId];
  /// Nạp sẵn cache thẻ (còn mới) cho widget test, tránh gọi API.
  @visibleForTesting
  void seedCardsForTest(int setId, List<FlashcardItemModel> cards) {
    _cachedCardsBySetId[setId] = cards;
    _cardsLastFetchedBySetId[setId] = DateTime.now();
  }

  bool isCardsStale(int setId) =>
      !_cardsLastFetchedBySetId.containsKey(setId) ||
      DateTime.now().difference(_cardsLastFetchedBySetId[setId]!) >
          _staleDuration;

  // ==========================================
  // 1 & 2: CACHE-FIRST & STALE-WHILE-REVALIDATE CHO THƯ VIỆN BỘ THẺ
  // ==========================================

  /// Lấy danh sách bộ thẻ:
  /// - Nếu đã có cache: trả về ngay lập tức (0ms). Nếu cache cũ (stale), tự đồng bộ ngầm.
  /// - Nếu chưa có cache (lần đầu): nạp từ backend.
  /// - Nếu [forceRefresh] == true (pull-to-refresh): nạp lại từ backend.
  Future<List<FlashcardSetModel>> getSets({
    String? search,
    bool forceRefresh = false,
    Function(List<FlashcardSetModel>)? onBackgroundUpdated,
  }) async {
    final hasSearch = search != null && search.trim().isNotEmpty;

    // Nếu tìm kiếm khi đã có cache: lọc cục bộ lập tức 0ms
    if (hasSearch && _cachedSets != null && !forceRefresh) {
      final query = search.trim().toLowerCase();
      final filtered = _cachedSets!.where((s) {
        final titleMatch = s.title.toLowerCase().contains(query);
        final descMatch =
            s.description?.toLowerCase().contains(query) ?? false;
        return titleMatch || descMatch;
      }).toList();

      // Nếu muốn đồng bộ thêm từ server khi search:
      _silentSyncSets(
        search: search,
        onBackgroundUpdated: onBackgroundUpdated,
      );

      return filtered;
    }

    // Nếu đã có cache và không bị ép làm mới: Trả về 0ms ngay lập tức
    if (_cachedSets != null && !forceRefresh) {
      if (isSetsStale()) {
        _silentSyncSets(onBackgroundUpdated: onBackgroundUpdated);
      }
      return _cachedSets!;
    }

    // Lần đầu mở app hoặc pull-to-refresh: nạp từ API
    final freshSets = await _service.getSets(search: search);
    if (!hasSearch) {
      _cachedSets = freshSets;
      _setsLastFetched = DateTime.now();
      notifyListeners();
    }
    return freshSets;
  }

  /// Đồng bộ ngầm danh sách bộ thẻ mà không làm giật màn hình
  Future<void> _silentSyncSets({
    String? search,
    Function(List<FlashcardSetModel>)? onBackgroundUpdated,
  }) async {
    if (_isSyncingSets) return;
    _isSyncingSets = true;

    try {
      final freshSets = await _service.getSets(search: search);
      if (search == null || search.trim().isEmpty) {
        _cachedSets = freshSets;
        _setsLastFetched = DateTime.now();
      }
      notifyListeners();
      onBackgroundUpdated?.call(freshSets);
    } catch (_) {
      // Bỏ qua lỗi khi sync ngầm để không ảnh hưởng dữ liệu đang xem trên UI
    } finally {
      _isSyncingSets = false;
    }
  }

  // ==========================================
  // 4: LAZY LOAD CHI TIẾT BỘ THẺ THEO setId
  // ==========================================

  /// Lấy danh sách từ vựng chi tiết theo setId:
  /// - Nếu setId đã nạp trước đó: trả về ngay lập tức (0ms).
  /// - Nếu stale (> 5 phút): đồng bộ ngầm và gọi [onBackgroundUpdated].
  /// - Nếu chưa nạp: fetch từ backend và lưu vào cache của setId đó.
  Future<List<FlashcardItemModel>> getCardsInSet(
    int setId, {
    bool forceRefresh = false,
    Function(List<FlashcardItemModel>)? onBackgroundUpdated,
  }) async {
    if (_cachedCardsBySetId.containsKey(setId) && !forceRefresh) {
      if (isCardsStale(setId)) {
        _silentSyncCards(setId, onBackgroundUpdated: onBackgroundUpdated);
      }
      return _cachedCardsBySetId[setId]!;
    }

    // Chưa có trong cache hoặc forceRefresh
    final freshCards = await _service.getCardsInSet(setId);
    _cachedCardsBySetId[setId] = freshCards;
    _cardsLastFetchedBySetId[setId] = DateTime.now();

    // Đồng bộ lại totalCards của set trong thư viện nếu có
    _updateTotalCardsCount(setId, freshCards.length);

    notifyListeners();
    return freshCards;
  }

  /// Đồng bộ ngầm danh sách từ vựng của 1 bộ thẻ
  Future<void> _silentSyncCards(
    int setId, {
    Function(List<FlashcardItemModel>)? onBackgroundUpdated,
  }) async {
    if (_syncingSetIds.contains(setId)) return;
    _syncingSetIds.add(setId);

    try {
      final freshCards = await _service.getCardsInSet(setId);
      _cachedCardsBySetId[setId] = freshCards;
      _cardsLastFetchedBySetId[setId] = DateTime.now();
      _updateTotalCardsCount(setId, freshCards.length);

      notifyListeners();
      onBackgroundUpdated?.call(freshCards);
    } catch (_) {
      // Lỗi ngầm bỏ qua
    } finally {
      _syncingSetIds.remove(setId);
    }
  }

  void _updateTotalCardsCount(int setId, int count) {
    if (_cachedSets == null) return;
    final idx = _cachedSets!.indexWhere((s) => s.setId == setId);
    if (idx != -1 && _cachedSets![idx].totalCards != count) {
      _cachedSets![idx] = _cachedSets![idx].copyWith(totalCards: count);
    }
  }

  // ==========================================
  // 3: OPTIMISTIC UPDATES (CẬP NHẬT TỨC THÌ 0MS VÀ ROLLBACK KHI LỖI)
  // ==========================================

  /// Xóa bộ thẻ tức thì (0ms):
  /// - Xóa ngay khỏi cache cục bộ và thông báo giao diện.
  /// - Gửi request ngầm đến backend.
  /// - Nếu thất bại: Rollback lại danh sách ban đầu và gọi [onError].
  Future<bool> optimisticDeleteSet(
    int setId, {
    required Function(String errorMessage) onError,
  }) async {
    final previousSets = _cachedSets != null
        ? List<FlashcardSetModel>.from(_cachedSets!)
        : <FlashcardSetModel>[];
    final previousCards = _cachedCardsBySetId[setId];

    // Cập nhật ngay 0ms
    _cachedSets?.removeWhere((s) => s.setId == setId);
    _cachedCardsBySetId.remove(setId);
    _cardsLastFetchedBySetId.remove(setId);
    notifyListeners();

    try {
      await _service.deleteSet(setId);
      return true;
    } catch (e) {
      // Rollback nếu có lỗi
      _cachedSets = previousSets;
      if (previousCards != null) {
        _cachedCardsBySetId[setId] = previousCards;
      }
      notifyListeners();
      onError(e.toString());
      return false;
    }
  }

  /// Cập nhật tên/mô tả bộ thẻ tức thì (0ms)
  Future<bool> optimisticUpdateSet({
    required int setId,
    required String title,
    String? description,
    required Function(String errorMessage) onError,
  }) async {
    final previousSets = _cachedSets != null
        ? List<FlashcardSetModel>.from(_cachedSets!)
        : <FlashcardSetModel>[];

    final idx = _cachedSets?.indexWhere((s) => s.setId == setId) ?? -1;
    if (idx != -1) {
      _cachedSets![idx] = _cachedSets![idx].copyWith(
        title: title,
        description: description,
      );
      notifyListeners();
    }

    try {
      final updated = await _service.updateSet(
        setId,
        title: title,
        description: description,
      );
      if (_cachedSets != null) {
        final currentIdx = _cachedSets!.indexWhere((s) => s.setId == setId);
        if (currentIdx != -1) {
          _cachedSets![currentIdx] = updated;
          notifyListeners();
        }
      }
      return true;
    } catch (e) {
      _cachedSets = previousSets;
      notifyListeners();
      onError(e.toString());
      return false;
    }
  }

  /// Gắn sao / Bỏ gắn sao tức thì (0ms)
  Future<bool> optimisticToggleStar({
    required int setId,
    required int cardId,
    required bool newStarred,
    required Function(String errorMessage) onError,
  }) async {
    final cards = _cachedCardsBySetId[setId];
    int cardIdx = -1;
    FlashcardItemModel? originalCard;

    if (cards != null) {
      cardIdx = cards.indexWhere((c) => c.cardId == cardId);
      if (cardIdx != -1) {
        originalCard = cards[cardIdx];
        cards[cardIdx] = originalCard.copyWith(isStarred: newStarred);
        notifyListeners();
      }
    }

    try {
      await _service.updateStar(cardId, newStarred);
      return true;
    } catch (e) {
      if (cards != null && cardIdx != -1 && originalCard != null) {
        cards[cardIdx] = originalCard;
        notifyListeners();
      }
      onError(e.toString());
      return false;
    }
  }

  /// Đặt lại tiến trình học tức thì (0ms)
  Future<bool> optimisticResetProgress({
    required int setId,
    required Function(String errorMessage) onError,
  }) async {
    final cards = _cachedCardsBySetId[setId];
    final originalCards = cards != null
        ? List<FlashcardItemModel>.from(cards)
        : null;

    if (cards != null) {
      for (int i = 0; i < cards.length; i++) {
        cards[i] = cards[i].copyWith(
          boxLevel: 0,
          correctCount: 0,
          incorrectCount: 0,
        );
      }
      notifyListeners();
    }

    try {
      await _service.resetProgress(setId);
      return true;
    } catch (e) {
      if (originalCards != null) {
        _cachedCardsBySetId[setId] = originalCards;
        notifyListeners();
      }
      onError(e.toString());
      return false;
    }
  }

  /// Cập nhật cache khi thêm mới hoặc sửa bộ thẻ từ DeckEditorScreen
  void updateSetInCache(
    FlashcardSetModel set, {
    List<FlashcardItemModel>? cards,
  }) {
    if (_cachedSets != null) {
      final idx = _cachedSets!.indexWhere((s) => s.setId == set.setId);
      final setWithCards = cards != null
          ? set.copyWith(totalCards: cards.length)
          : set;

      if (idx != -1) {
        _cachedSets![idx] = setWithCards;
      } else {
        _cachedSets!.insert(0, setWithCards);
      }
    }

    if (cards != null) {
      _cachedCardsBySetId[set.setId] = cards;
      _cardsLastFetchedBySetId[set.setId] = DateTime.now();
    } else {
      // Invalidate timestamp so overview re-validates next time
      _cardsLastFetchedBySetId.remove(set.setId);
    }

    notifyListeners();
  }

  /// Hủy cache của 1 bộ thẻ cụ thể để lần mở sau nạp lại từ backend
  void invalidateSet(int setId) {
    _cardsLastFetchedBySetId.remove(setId);
    _cachedCardsBySetId.remove(setId);
    _setsLastFetched = null;
    notifyListeners();
  }

  /// Làm mới toàn bộ cache
  void invalidateAll() {
    _cachedSets = null;
    _setsLastFetched = null;
    _cachedCardsBySetId.clear();
    _cardsLastFetchedBySetId.clear();
    notifyListeners();
  }
}
