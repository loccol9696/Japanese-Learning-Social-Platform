import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// HTTP client dùng chung: gắn JWT, timeout, bóc `data` từ `ApiResponse`
/// và chuyển mọi lỗi (HTTP / mạng) thành [ApiException].
class ApiClient {
  static ApiClient? _instance;
  ApiClient._(this._httpClient) : _tokenProvider = null;
  static ApiClient get instance => _instance ??= ApiClient._(http.Client());

  @visibleForTesting
  ApiClient.withClient(this._httpClient, {this._tokenProvider});

  final http.Client _httpClient;
  final Future<String?> Function()? _tokenProvider;

  Future<String?> _readToken() =>
      (_tokenProvider ?? TokenStorage.instance.getAccessToken)();

  Future<Map<String, String>> _getHeaders({bool withAuth = true, bool json = true}) async {
    final headers = <String, String>{
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth) {
      final token = await _readToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> post(
    String url, {
    Map<String, dynamic>? body,
    bool withAuth = false,
    Duration? timeout,
  }) async {
    final headers = await _getHeaders(withAuth: withAuth);
    return _send(
      () => _httpClient.post(Uri.parse(url),
          headers: headers, body: body != null ? jsonEncode(body) : null),
      timeout,
    );
  }

  Future<dynamic> get(
    String url, {
    bool withAuth = true,
    Duration? timeout,
  }) async {
    final headers = await _getHeaders(withAuth: withAuth);
    return _send(() => _httpClient.get(Uri.parse(url), headers: headers), timeout);
  }

  Future<dynamic> put(
    String url, {
    Map<String, dynamic>? body,
    bool withAuth = true,
    Duration? timeout,
  }) async {
    final headers = await _getHeaders(withAuth: withAuth);
    return _send(
      () => _httpClient.put(Uri.parse(url),
          headers: headers, body: body != null ? jsonEncode(body) : null),
      timeout,
    );
  }

  Future<dynamic> delete(
    String url, {
    bool withAuth = true,
    Duration? timeout,
  }) async {
    final headers = await _getHeaders(withAuth: withAuth);
    return _send(() => _httpClient.delete(Uri.parse(url), headers: headers), timeout);
  }

  /// Upload một file dạng multipart/form-data (ví dụ: video lên `/media/upload`).
  Future<dynamic> postMultipart(
    String url, {
    required String fieldName,
    required Uint8List bytes,
    required String filename,
    bool withAuth = true,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final headers = await _getHeaders(withAuth: withAuth, json: false);
    return _send(() async {
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers.addAll(headers)
        ..files.add(http.MultipartFile.fromBytes(fieldName, bytes, filename: filename));
      return http.Response.fromStream(await _httpClient.send(request));
    }, timeout);
  }

  Future<dynamic> _send(Future<http.Response> Function() request, Duration? timeout) async {
    try {
      final response = await request().timeout(timeout ?? ApiConstants.connectTimeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException(
        statusCode: 408,
        message: 'Kết nối mạng quá hạn. Vui lòng kiểm tra lại đường truyền.',
      );
    } on SocketException {
      throw _offline();
    } on http.ClientException {
      // Trên web lỗi mạng là ClientException thay vì SocketException
      throw _offline();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 500,
        message: 'Đã xảy ra lỗi: ${e.toString()}',
      );
    }
  }

  ApiException _offline() => ApiException(
        statusCode: 503,
        message: 'Không thể kết nối đến máy chủ backend (Port 8080). Hãy chắc chắn server đang chạy.',
      );

  dynamic _handleResponse(http.Response response) {
    dynamic jsonBody;
    try {
      if (response.body.isNotEmpty) {
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

    // Error handling
    String errorMessage = 'Lỗi không xác định (${response.statusCode})';
    dynamic errorData;

    if (jsonBody is Map<String, dynamic>) {
      // `errorMessage`: các API không bọc ApiResponse (vd: /api/speech/status)
      final message = jsonBody['message'] ?? jsonBody['errorMessage'];
      if (message != null) {
        errorMessage = message.toString();
      }
      if (jsonBody.containsKey('data')) {
        errorData = jsonBody['data'];
        if (errorData is Map<String, dynamic> && errorData.isNotEmpty) {
          final firstError = errorData.values.first;
          errorMessage = firstError.toString();
        }
      }
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: errorMessage,
      data: errorData,
    );
  }
}
