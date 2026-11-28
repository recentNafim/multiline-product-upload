import 'dart:async';
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
      // Call the HTTPS Oracle ORDS login handler directly.
      // HRIS Authorization/S_KEYL secrets stay on the ORDS server,
      // never in public Flutter Web / GitHub Pages JavaScript.
      final response = await http.post(
        Uri.parse(ApiConstants.loginUrl),
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'UserName': cleanId, 'Password': password}),
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

      if (response.statusCode == 200 && data?['isSuccess'] == false) {
        error = _serverMessage(data) ?? 'Invalid User ID or password.';
      } else if (response.statusCode == 200) {
        error = 'Login API returned HTTP 200 but no valid isSuccess value. '
            'Verify that the ORDS handler returns JSON with isSuccess: true/false.';
      } else if (response.statusCode == 400) {
        error = _serverMessage(data) ?? 'Invalid login request (HTTP 400). '
            'Check the User ID and ORDS login handler.';
      } else if (response.statusCode == 401) {
        error = _serverMessage(data) ?? 'Login rejected (HTTP 401). Verify credentials and ORDS endpoint authorization.';
      } else if (response.statusCode == 403) {
        error = 'Login denied (HTTP 403). Check ORDS endpoint authorization and browser CORS settings.';
      } else if (response.statusCode == 404) {
        error = 'Login endpoint not found (HTTP 404). '
            'Deploy the ORDS handler at the configured login URL.';
      } else if (response.statusCode == 405) {
        error = 'Login endpoint does not accept POST (HTTP 405). '
            'Check the ORDS handler method.';
      } else if (response.statusCode >= 500) {
        error = _serverMessage(data) ??
            'Oracle/HRIS login service error (HTTP ${response.statusCode}). '
            'Check the ORDS logs and APPS.USER_LOGIN_VALIDATION.';
      } else {
        error = 'ORDS login request failed (HTTP ${response.statusCode}). '
            'Check the endpoint and server configuration.';
      }
    } on TimeoutException {
      error = 'Login request timed out. Check ORDS/HRIS connectivity.';
    } on http.ClientException {
      error = 'Cannot reach the ORDS login API from this browser. '
          'Check HTTPS, server availability and CORS for Content-Type.';
    } catch (_) {
      error = 'Unable to complete login. Verify ORDS endpoint, HTTPS and CORS.';
    } finally {
      busy = false;
      notifyListeners();
    }
    return false;
  }

  static String? _serverMessage(Map<String, dynamic>? data) {
    final message = data?['message'];
    if (message is! String) return null;
    final clean = message.trim();
    // Never echo potentially sensitive or arbitrarily large server responses.
    if (clean.isEmpty || clean.length > 180) return null;
    return clean;
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
