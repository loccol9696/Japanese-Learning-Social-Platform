import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Hàm dựng và gửi một request với bộ header cho trước. Được gọi lại lần
/// nữa (với token mới) nếu lần đầu bị 401.
typedef RequestSender = Future<http.Response> Function(
  Map<String, String> headers,
);

/// Điểm DUY NHẤT gọi backend:
/// - tự gắn `Authorization: Bearer <access token>`;
/// - làm mới access token trước khi hết hạn và khi bị 401 (thử lại 1 lần);
/// - không làm mới được (refresh token hết hạn / bị thu hồi) thì xoá phiên và
///   gọi [onSessionExpired] để app đưa người dùng về màn Đăng nhập.
class ApiClient {
  ApiClient._(this._httpClient, this._storage);

  static ApiClient? _instance;
  static ApiClient get instance =>
      _instance ??= ApiClient._(http.Client(), TokenStorage.instance);

  @visibleForTesting
  static void overrideForTesting(http.Client client) {
    _instance = ApiClient._(client, TokenStorage.instance);
  }

  /// Được [AuthSession] gán khi khởi động app.
  static VoidCallback? onSessionExpired;

  /// Làm mới khi access token còn dưới khoảng này.
  static const Duration _refreshSkew = Duration(seconds: 30);

  final http.Client _httpClient;
  final TokenStorage _storage;
  Future<String?>? _refreshInFlight;

  // ---------------------------------------------------------------------------
  // JSON API
  // ---------------------------------------------------------------------------

  Future<dynamic> get(
    String url, {
    bool withAuth = true,
    Duration? timeout = ApiConstants.connectTimeout,
  }) =>
      _sendJson('GET', url, withAuth: withAuth, timeout: timeout);

  /// [bearerToken]: gửi đúng token này, không tự làm mới / không xử lý 401
  /// (dùng cho đăng xuất).
  Future<dynamic> post(
    String url, {
    Object? body,
    bool withAuth = true,
    String? bearerToken,
    Duration? timeout = ApiConstants.connectTimeout,
  }) =>
      _sendJson(
        'POST',
        url,
        body: body,
        withAuth: withAuth,
        bearerToken: bearerToken,
        timeout: timeout,
      );

  Future<dynamic> put(
    String url, {
    Object? body,
    bool withAuth = true,
    Duration? timeout = ApiConstants.connectTimeout,
  }) =>
      _sendJson('PUT', url, body: body, withAuth: withAuth, timeout: timeout);

  Future<dynamic> patch(
    String url, {
    Object? body,
    bool withAuth = true,
    Duration? timeout = ApiConstants.connectTimeout,
  }) =>
      _sendJson('PATCH', url, body: body, withAuth: withAuth, timeout: timeout);

  Future<dynamic> delete(
    String url, {
    bool withAuth = true,
    Duration? timeout = ApiConstants.connectTimeout,
  }) =>
      _sendJson('DELETE', url, withAuth: withAuth, timeout: timeout);

  Future<dynamic> _sendJson(
    String method,
    String url, {
    Object? body,
    required bool withAuth,
    String? bearerToken,
    Duration? timeout = ApiConstants.connectTimeout,
  }) async {
    final uri = Uri.parse(url);
    final encodedBody = body != null ? jsonEncode(body) : null;
    final response = await send(
      (headers) async {
        final request = http.Request(method, uri)..headers.addAll(headers);
        if (encodedBody != null) request.body = encodedBody;
        return http.Response.fromStream(await _httpClient.send(request));
      },
      withAuth: withAuth,
      bearerToken: bearerToken,
      timeout: timeout,
    );
    return decodeResponse(response);
  }

  // ---------------------------------------------------------------------------
  // Request tuỳ ý (multipart, đọc response thô...)
  // ---------------------------------------------------------------------------

  /// Gửi request với header xác thực. [jsonContent] = false cho multipart
  /// (để thư viện tự đặt Content-Type). [timeout] = null: không giới hạn
  /// (tải video lớn).
  Future<http.Response> send(
    RequestSender sender, {
    bool withAuth = true,
    bool jsonContent = true,
    String? bearerToken,
    Duration? timeout = ApiConstants.connectTimeout,
  }) {
    return _guardNetwork(() async {
      final token = bearerToken ?? (withAuth ? await validAccessToken() : null);
      var response = await _withTimeout(
        sender(_headers(token, jsonContent)),
        timeout,
      );

      final mayRefresh = withAuth && bearerToken == null && token != null;
      if (response.statusCode == 401 && mayRefresh) {
        final refreshed = await refreshAccessToken();
        if (refreshed != null) {
          response = await _withTimeout(
            sender(_headers(refreshed, jsonContent)),
            timeout,
          );
        }
        if (response.statusCode == 401) {
          await _expireSession();
        }
      }
      return response;
    });
  }

  /// Gửi một request multipart (tải tệp) với token; tự dựng lại request nếu
  /// phải thử lại sau khi làm mới token.
  Future<http.Response> sendMultipart(
    http.MultipartRequest Function() build, {
    Duration? timeout,
  }) {
    return send(
      (headers) async {
        final request = build()..headers.addAll(headers);
        return http.Response.fromStream(await _httpClient.send(request));
      },
      jsonContent: false,
      timeout: timeout,
    );
  }

  Map<String, String> _headers(String? token, bool jsonContent) => {
        'Accept': 'application/json',
        if (jsonContent) 'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  // ---------------------------------------------------------------------------
  // Token
  // ---------------------------------------------------------------------------

  /// Access token còn hạn (tự làm mới nếu sắp hết). null nếu chưa đăng nhập.
  Future<String?> validAccessToken() async {
    final token = await _storage.getAccessToken();
    if (token != null &&
        token.isNotEmpty &&
        !TokenStorage.isTokenExpired(token, skew: _refreshSkew)) {
      return token;
    }
    if (!await _storage.hasSession()) return token;
    return await refreshAccessToken() ?? token;
  }

  /// Đổi refresh token lấy cặp token mới. Nhiều request cùng lúc chỉ gọi
  /// server một lần. Trả về null nếu phiên đã hết (khi đó phiên bị xoá).
  /// Lỗi mạng được ném ra dưới dạng [ApiException] và phiên được giữ nguyên.
  Future<String?> refreshAccessToken() {
    return _refreshInFlight ??=
        _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<String?> _doRefresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final response = await _guardNetwork(
      () => _httpClient
          .post(
            Uri.parse(ApiConstants.refreshUrl),
            headers: _headers(null, true),
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(ApiConstants.connectTimeout),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = decodeResponse(response);
      if (data is Map<String, dynamic>) {
        final access = data['accessToken']?.toString();
        final refresh = data['refreshToken']?.toString();
        if (access != null && refresh != null) {
          await _storage.saveTokens(accessToken: access, refreshToken: refresh);
          final user = data['user'];
          if (user is Map<String, dynamic>) await _storage.saveUser(user);
          return access;
        }
      }
      return null;
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      await _expireSession();
    }
    return null;
  }

  Future<void> _expireSession() async {
    final hadSession = await _storage.hasSession();
    await _storage.clear();
    if (hadSession) onSessionExpired?.call();
  }

  // ---------------------------------------------------------------------------
  // Tiện ích
  // ---------------------------------------------------------------------------

  static Future<T> _withTimeout<T>(Future<T> future, Duration? timeout) =>
      timeout == null ? future : future.timeout(timeout);

  static Future<T> _guardNetwork<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        statusCode: 408,
        message: 'Kết nối mạng quá hạn. Vui lòng kiểm tra lại đường truyền.',
      );
    } on SocketException {
      throw ApiException(
        statusCode: 503,
        message: 'Không thể kết nối đến máy chủ. Vui lòng thử lại sau.',
      );
    } on http.ClientException {
      throw ApiException(
        statusCode: 503,
        message: 'Không thể kết nối đến máy chủ. Vui lòng thử lại sau.',
      );
    }
  }

  /// Bóc `data` khỏi ApiResponse; lỗi thì ném [ApiException] kèm thông báo
  /// của server (lỗi validation: lấy lỗi đầu tiên).
  static dynamic decodeResponse(http.Response response) {
    dynamic jsonBody;
    try {
      if (response.bodyBytes.isNotEmpty) {
        jsonBody = jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (_) {
      jsonBody = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (jsonBody is Map<String, dynamic> && jsonBody.containsKey('data')) {
        return jsonBody['data'];
      }
      return jsonBody;
    }

    var errorMessage = _defaultMessage(response.statusCode);
    dynamic errorData;
    if (jsonBody is Map<String, dynamic>) {
      final message = jsonBody['message'];
      if (message is String && message.isNotEmpty) errorMessage = message;
      errorData = jsonBody['data'];
      if (errorData is Map<String, dynamic> && errorData.isNotEmpty) {
        errorMessage = errorData.values.first.toString();
      }
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: errorMessage,
      data: errorData,
    );
  }

  static String _defaultMessage(int statusCode) => switch (statusCode) {
        401 => 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại',
        403 => 'Bạn không có quyền thực hiện hành động này',
        404 => 'Không tìm thấy dữ liệu yêu cầu',
        429 => 'Bạn thao tác quá nhanh, vui lòng thử lại sau',
        >= 500 => 'Máy chủ đang gặp sự cố, vui lòng thử lại sau',
        _ => 'Đã xảy ra lỗi ($statusCode)',
      };
}
