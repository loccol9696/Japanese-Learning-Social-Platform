import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

class ApiClient {
  static ApiClient? _instance;
  ApiClient._();
  static ApiClient get instance => _instance ??= ApiClient._();

  final http.Client _httpClient = http.Client();

  Future<Map<String, String>> _getHeaders({bool withAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth) {
      final token = await TokenStorage.instance.getAccessToken();
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
  }) async {
    try {
      final uri = Uri.parse(url);
      final headers = await _getHeaders(withAuth: withAuth);
      final response = await _httpClient
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConstants.connectTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException(
        statusCode: 408,
        message: 'Kết nối mạng quá hạn. Vui lòng kiểm tra lại đường truyền.',
      );
    } on SocketException {
      throw ApiException(
        statusCode: 503,
        message: 'Không thể kết nối đến máy chủ backend (Port 8080). Hãy chắc chắn server đang chạy.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 500,
        message: 'Đã xảy ra lỗi: ${e.toString()}',
      );
    }
  }

  Future<dynamic> get(
    String url, {
    bool withAuth = true,
  }) async {
    try {
      final uri = Uri.parse(url);
      final headers = await _getHeaders(withAuth: withAuth);
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(ApiConstants.connectTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException(
        statusCode: 408,
        message: 'Kết nối mạng quá hạn. Vui lòng kiểm tra lại.',
      );
    } on SocketException {
      throw ApiException(
        statusCode: 503,
        message: 'Không thể kết nối đến máy chủ backend.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 500,
        message: 'Đã xảy ra lỗi: ${e.toString()}',
      );
    }
  }

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
      if (jsonBody.containsKey('message') && jsonBody['message'] != null) {
        errorMessage = jsonBody['message'].toString();
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
