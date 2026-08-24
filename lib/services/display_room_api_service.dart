import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';

class DisplayRoomApiService {
  DisplayRoomApiService._();

  static Future<http.Response> uploadItem(Map<String, dynamic> body) {
    return http
        .post(
          Uri.parse(ApiConstants.uploadItem),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 120));
  }

  static Future<http.Response> getItems() {
    return http.get(
      Uri.parse(ApiConstants.listItems),
      headers: const {'Accept': 'application/json'},
    );
  }

  static Future<http.Response> updateItem(Map<String, dynamic> body) {
    return http
        .put(
          Uri.parse(ApiConstants.updateItem),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));
  }

  static Future<http.Response> getDeleteData() {
    return http
        .get(
          Uri.parse(ApiConstants.deleteItem),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 60));
  }

  static Future<http.Response> deleteProduct(int detailSl) {
    final uri = Uri.parse(ApiConstants.deleteItem).replace(
      queryParameters: {'p_detail_sl': detailSl.toString()},
    );

    return http
        .delete(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 60));
  }

  static Future<http.Response> deleteMaster(int masterSl) {
    final uri = Uri.parse(ApiConstants.deleteItem).replace(
      queryParameters: {'p_master_sl': masterSl.toString()},
    );

    return http
        .delete(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 60));
  }
}
