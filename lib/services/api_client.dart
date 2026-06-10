import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

String get kBaseUrl => _baseUrl;

String get _baseUrl {
  if (kIsWeb) return 'http://localhost:8080';
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080'; // Android emulator → host localhost
  }
  return 'http://localhost:8080'; // iOS simulator / macOS / Windows
}

final _storage = const FlutterSecureStorage();

const _kAccess = 'access_token';
const _kRefresh = 'refresh_token';
const _kUserId = 'user_id';

// ── Token helpers ─────────────────────────────────────────────────────────

Future<void> saveTokens({
  required String accessToken,
  required String refreshToken,
  required String userId,
}) async {
  await Future.wait([
    _storage.write(key: _kAccess, value: accessToken),
    _storage.write(key: _kRefresh, value: refreshToken),
    _storage.write(key: _kUserId, value: userId),
  ]);
}

Future<void> clearTokens() async {
  await Future.wait([
    _storage.delete(key: _kAccess),
    _storage.delete(key: _kRefresh),
    _storage.delete(key: _kUserId),
  ]);
}

Future<String?> getAccessToken() => _storage.read(key: _kAccess);
Future<String?> getRefreshToken() => _storage.read(key: _kRefresh);
Future<String?> getCurrentUserId() => _storage.read(key: _kUserId);

Future<bool> isLoggedIn() async => (await _storage.read(key: _kAccess)) != null;

// ── HTTP helpers ──────────────────────────────────────────────────────────

Uri _uri(String path) => Uri.parse('$_baseUrl$path');

Future<Map<String, String>> _authHeaders() async {
  final token = await getAccessToken();
  return {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

/// Refresh the access token using the stored refresh token.
/// Returns true on success.
Future<bool> _refreshAccess() async {
  final refresh = await getRefreshToken();
  if (refresh == null) return false;
  try {
    final r = await http.post(
      _uri('/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refresh}),
    );
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      await _storage.write(key: _kAccess, value: body['accessToken'] as String);
      return true;
    }
  } catch (_) {}
  return false;
}

// ── Public request methods ────────────────────────────────────────────────

Future<http.Response> apiGet(String path) async {
  var headers = await _authHeaders();
  var r = await http.get(_uri(path), headers: headers);
  if (r.statusCode == 401) {
    if (await _refreshAccess()) {
      headers = await _authHeaders();
      r = await http.get(_uri(path), headers: headers);
    }
  }
  return r;
}

Future<http.Response> apiPost(String path, Map<String, dynamic> body) async {
  var headers = await _authHeaders();
  var r = await http.post(_uri(path), headers: headers, body: jsonEncode(body));
  if (r.statusCode == 401) {
    if (await _refreshAccess()) {
      headers = await _authHeaders();
      r = await http.post(_uri(path), headers: headers, body: jsonEncode(body));
    }
  }
  return r;
}

Future<http.Response> apiPut(String path, Map<String, dynamic> body) async {
  var headers = await _authHeaders();
  var r = await http.put(_uri(path), headers: headers, body: jsonEncode(body));
  if (r.statusCode == 401) {
    if (await _refreshAccess()) {
      headers = await _authHeaders();
      r = await http.put(_uri(path), headers: headers, body: jsonEncode(body));
    }
  }
  return r;
}

Future<http.Response> apiDelete(String path) async {
  var headers = await _authHeaders();
  var r = await http.delete(_uri(path), headers: headers);
  if (r.statusCode == 401) {
    if (await _refreshAccess()) {
      headers = await _authHeaders();
      r = await http.delete(_uri(path), headers: headers);
    }
  }
  return r;
}

/// Multipart upload (for posts, stories, profile photos).
Future<http.Response> apiMultipart({
  required String method, // 'POST' or 'PUT'
  required String path,
  Map<String, String> fields = const {},
  List<({String field, File file})> files = const [],
}) async {
  Future<http.Response> send() async {
    final token = await getAccessToken();
    final req = http.MultipartRequest(method, _uri(path));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.fields.addAll(fields);
    for (final f in files) {
      req.files.add(await http.MultipartFile.fromPath(f.field, f.file.path));
    }
    final streamed = await req.send();
    return http.Response.fromStream(streamed);
  }

  var r = await send();
  if (r.statusCode == 401 && await _refreshAccess()) {
    r = await send();
  }
  return r;
}

/// Decode JSON body and throw if status >= 400.
Map<String, dynamic> expectJson(http.Response r) {
  if (r.body.isEmpty) {
    if (r.statusCode >= 400) {
      throw ApiException(
        r.statusCode,
        'Request failed (status ${r.statusCode}, empty response)',
      );
    }
    return {};
  }
  final body = jsonDecode(r.body) as Map<String, dynamic>;
  if (r.statusCode >= 400) {
    throw ApiException(r.statusCode, body['error'] ?? 'Request failed');
  }
  return body;
}

List<dynamic> expectJsonList(http.Response r) {
  if (r.statusCode >= 400) {
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, body['error'] ?? 'Request failed');
  }
  return jsonDecode(r.body) as List<dynamic>;
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}
