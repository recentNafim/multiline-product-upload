import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import 'auth_session.dart';

class DisplayRoomApiService {
  DisplayRoomApiService._();

  static Map<String, dynamic> _withLoggedInUser(Map<String, dynamic> source,
      {required bool creating}) {
    final id = AuthSession.instance.staffId;
    final body = Map<String, dynamic>.from(source);
    // UI identity is stamped into requests; ORDS must also enforce it server-side.
    if (creating) {
      body['created_by'] = id;
    } else if (body['mode']?.toString().toUpperCase() != 'CAPABILITY_CHECK') {
      body['updated_by'] = id;
    }
    return body;
  }

  static Future<http.Response> _request(
      Future<http.Response> Function() execute) async {
    AuthSession.instance.requireLogin();
    return execute();
  }

  static Future<http.Response> uploadItem(Map<String, dynamic> body) => _request(() => http.post(
    Uri.parse(ApiConstants.uploadItem),
    headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode(_withLoggedInUser(body, creating: true)),
  ).timeout(const Duration(seconds: 120)));

  static Future<http.Response> getItemsByCode(String itemCode) => _request(() => http.get(
    Uri.parse(ApiConstants.listItems).replace(queryParameters: {
      'p_item_code': itemCode.trim(), 'p_page': '1', 'p_limit': '100',
    }), headers: const {'Accept': 'application/json'},
  ).timeout(const Duration(seconds: 60)));

  static Future<http.Response> getItemsByMasterSl(int masterSl) => _request(() => http.get(
    Uri.parse(ApiConstants.listItems).replace(queryParameters: {
      'p_master_sl': '$masterSl', 'p_page': '1', 'p_limit': '1',
    }), headers: const {'Accept': 'application/json'},
  ).timeout(const Duration(seconds: 60)));

  static Future<http.Response> getItemsPage({required int page, int limit = 100}) => _request(() => http.get(
    Uri.parse(ApiConstants.listItems).replace(queryParameters: {
      'p_page': '$page', 'p_limit': '$limit',
    }), headers: const {'Accept': 'application/json'},
  ).timeout(const Duration(seconds: 60)));

  static Future<http.Response> getItems() => _request(() => http.get(
    Uri.parse(ApiConstants.listItems),
    headers: const {'Accept': 'application/json'},
  ).timeout(const Duration(seconds: 60)));

  static Future<http.Response> updateItem(Map<String, dynamic> body) => _request(() => http.put(
    Uri.parse(ApiConstants.updateItem),
    headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode(_withLoggedInUser(body, creating: false)),
  ).timeout(const Duration(seconds: 180)));

  static Future<http.Response> getDeleteData() => _request(() => http.get(
    Uri.parse(ApiConstants.deleteItem),
    headers: const {'Accept': 'application/json'},
  ).timeout(const Duration(seconds: 60)));

  static Future<http.Response> deleteProduct(int detailSl) => _request(() => http.delete(
    Uri.parse(ApiConstants.deleteItem).replace(queryParameters: {
      'p_detail_sl': detailSl.toString(),
    }), headers: const {'Accept': 'application/json'},
  ).timeout(const Duration(seconds: 60)));

  static Future<http.Response> deleteMaster(int masterSl) => _request(() => http.delete(
    Uri.parse(ApiConstants.deleteItem).replace(queryParameters: {
      'p_master_sl': masterSl.toString(),
    }), headers: const {'Accept': 'application/json'},
  ).timeout(const Duration(seconds: 60)));
}
