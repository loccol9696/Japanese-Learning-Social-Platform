import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/features/home/data/datasources/home_remote_datasource.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  http.Response ok() => http.Response.bytes(
        utf8.encode(jsonEncode({'status': 200, 'data': true})),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  HomeRemoteDataSourceImpl dataSource(MockClient client) => HomeRemoteDataSourceImpl(
        apiClient: ApiClient.withClient(client, tokenProvider: () async => 'jwt'),
      );

  test('thích -> POST, bỏ thích -> DELETE /videos/{id}/likes kèm JWT', () async {
    final sent = <http.Request>[];
    final ds = dataSource(MockClient((request) async {
      sent.add(request);
      return ok();
    }));

    await ds.setLiked('15', true);
    await ds.setLiked('15', false);

    expect(sent.map((r) => r.method), ['POST', 'DELETE']);
    expect(sent.map((r) => r.url.path).toSet(), {'/api/v1/videos/15/likes'});
    expect(sent.every((r) => r.headers['Authorization'] == 'Bearer jwt'), isTrue);
  });

  test('lỗi backend (vd. chưa đăng nhập) được ném ra để UI báo', () async {
    final ds = dataSource(MockClient((_) async => http.Response.bytes(
          utf8.encode(jsonEncode({'status': 401, 'message': 'Vui lòng đăng nhập'})),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )));

    expect(ds.setLiked('15', true), throwsA(isA<ApiException>()));
  });
}
