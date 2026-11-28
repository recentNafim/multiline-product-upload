import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';
import 'auth_storage_stub.dart'
    if (dart.library.html) 'auth_storage_web.dart' as auth_storage;

/// Docker-free HRIS login through the existing HTTPS Oracle ORDS server.
/// The Flutter Web bundle contains no HRIS Authorization/S_KEYL secrets.
///
/// IMPORTANT: a browser-stored user ID gates the Flutter UI only. The existing
/// ORDS item CRUD handlers must independently enforce authorization and audit
/// integrity before this is suitable for security-sensitive production use.
class AuthSession extends ChangeNotifier {
  AuthSession._();
  static final AuthSession instance = AuthSession._();

  static const int _sessionDurationMs = 8 * 60 * 60 * 1000;

  bool initialized = false;
  bool busy = false;
  String? userId;
  String? error;
  int _expiresAt = 0;

  bool get authenticated => userId != null &&
      DateTime.now().millisecondsSinceEpoch < _expiresAt;

  int get staffId {
    requireLogin();
    final id = int.tryParse(userId ?? '');
    if (id == null || id <= 0) {
      throw StateError('Please sign in with a valid numeric Staff ID.');
    }
    return id;
  }

  Future<void> initialize() async {
    if (initialized) return;
    try {
      final stored = auth_storage.readAuthSession();
      if (stored != null) {
        final data = jsonDecode(stored);
        if (data is Map) {
          final id = '${data['userId'] ?? ''}'.trim();
          final expiry = data['expiresAt'];
          if (RegExp(r'^\d{1,15}$').hasMatch(id) &&
              (int.tryParse(id) ?? 0) > 0 &&
              expiry is int &&
              expiry > DateTime.now().millisecondsSinceEpoch) {
            userId = id;
            _expiresAt = expiry;
          } else {
            auth_storage.clearAuthSession();
          }
        }
      }
    } catch (_) {
      auth_storage.clearAuthSession();
    } finally {
      initialized = true;
      notifyListeners();
    }
  }

  Future<bool> login({required String id, required String password}) async {
    if (busy) return false;
    final cleanId = id.trim();
    if (!RegExp(r'^\d{1,15}$').hasMatch(cleanId) ||
        (int.tryParse(cleanId) ?? 0) <= 0) {
      error = 'Enter a valid numeric User ID.';
      notifyListeners();
      return false;
    }
    if (password.isEmpty) {
      error = 'Enter your password.';
      notifyListeners();
      return false;
    }

    busy = true;
    error = null;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.loginUrl),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'userId': cleanId, 'password': password}),
      ).timeout(const Duration(seconds: 25));

      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {}

      if (response.statusCode == 200 && data?['isSuccess'] == true) {
        userId = cleanId;
        _expiresAt = DateTime.now().millisecondsSinceEpoch + _sessionDurationMs;
        auth_storage.saveAuthSession(jsonEncode({
          'userId': cleanId,
          'expiresAt': _expiresAt,
        }));
        return true;
      }

      if (response.statusCode == 401 ||
          (response.statusCode == 200 && data?['isSuccess'] == false)) {
        error = (data?['message'] as String?) ?? 'Invalid User ID or password.';
      } else if (response.statusCode == 404) {
        error = 'ORDS login API not deployed (HTTP 404). Install the supplied SQL handler.';
      } else {
        error = 'ORDS login request failed (HTTP ${response.statusCode}). '
            'Check the API handler and server configuration.';
      }
    } catch (_) {
      error = 'Cannot reach the HTTPS Oracle ORDS login API. '
          'Check network access, endpoint deployment and browser CORS settings.';
    } finally {
      busy = false;
      notifyListeners();
    }
    return false;
  }

  Future<void> logout() async {
    userId = null;
    _expiresAt = 0;
    error = null;
    auth_storage.clearAuthSession();
    notifyListeners();
  }

  void requireLogin() {
    if (!authenticated) {
      markExpired();
      throw StateError('Session expired. Please sign in again.');
    }
  }

  void markExpired() {
    userId = null;
    _expiresAt = 0;
    auth_storage.clearAuthSession();
    error = 'Your session expired. Please sign in again.';
    notifyListeners();
  }
}
