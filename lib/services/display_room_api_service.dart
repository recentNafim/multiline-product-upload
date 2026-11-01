import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

class DisplayRoomApiService {
  DisplayRoomApiService._();

  static Future<http.Response> uploadItem(Map<String, dynamic> body) => http.post(
    Uri.parse(ApiConstants.uploadItem),
    headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode(body),
  ).timeout(const Duration(seconds: 120));

  // Server-side exact item-code lookup. GET limits page size to 100,
  // and total_records is used to reject duplicate matches safely.
  static Future<http.Response> getItemsByCode(String itemCode) => http.get(
    Uri.parse(ApiConstants.listItems).replace(queryParameters: {
      'p_item_code': itemCode.trim(),
      'p_page': '1',
      'p_limit': '100',
    }),
    headers: const {'Accept': 'application/json'},
  ).timeout(const Duration(seconds: 60));

  static Future<http.Response> getItems() => http.get(
    Uri.parse(ApiConstants.listItems),
    headers: const {'Accept': 'application/json'},
  );

  static Future<http.Response> updateItem(Map<String, dynamic> body) => http.put(
    Uri.parse(ApiConstants.updateItem),
    headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode(body),
  ).timeout(const Duration(seconds: 180));

  static Future<http.Response> getDeleteData() => http.get(
    Uri.parse(ApiConstants.deleteItem),
    headers: const {'Accept': 'application/json'},
  ).timeout(const Duration(seconds: 60));

  static Future<http.Response> deleteProduct(int detailSl) => http.delete(
    Uri.parse(ApiConstants.deleteItem).replace(queryParameters: {
      'p_detail_sl': detailSl.toString(),
    }),
    headers: const {'Accept': 'application/json'},
  ).timeout(const Duration(seconds: 60));

  static Future<http.Response> deleteMaster(int masterSl) => http.delete(
    Uri.parse(ApiConstants.deleteItem).replace(queryParameters: {
      'p_master_sl': masterSl.toString(),
    }),
    headers: const {'Accept': 'application/json'},
  ).timeout(const Duration(seconds: 60));
}
