import 'dart:convert';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';

String normalizeHeader(String value) => value.trim().toUpperCase()
    .replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ');

dynamic getExcelValue(xls.Data? cell) {
  final value = cell?.value;
  if (value == null) return null;
  if (value is xls.TextCellValue) return value.value;
  if (value is xls.IntCellValue) return value.value;
  if (value is xls.DoubleCellValue) return value.value;
  if (value is xls.BoolCellValue) return value.value;
  if (value is xls.FormulaCellValue) return value.formula;
  if (value is xls.DateCellValue) return value.asDateTimeLocal();
  if (value is xls.DateTimeCellValue) return value.asDateTimeLocal();
  if (value is xls.TimeCellValue) return value.asDuration();
  return value.toString();
}

String asText(dynamic value) {
  if (value == null) return '';
  if (value is double && value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString().trim();
}

int? asInt(dynamic value) {
  final text = asText(value).replaceAll(',', '').trim();
  if (text.isEmpty) return null;
  return int.tryParse(text) ?? double.tryParse(text)?.toInt();
}

double? asDouble(dynamic value) {
  final text = asText(value).replaceAll(',', '').trim();
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

String mimeTypeFromFileName(String fileName) {
  final name = fileName.toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.gif')) return 'image/gif';
  return 'application/octet-stream';
}

List<String> imageNamesFromExcelValue(dynamic value) {
  final text = asText(value);
  if (text.isEmpty) return <String>[];
  return text.split(RegExp(r'[,;|\n]')).map((e) => e.trim())
      .where((e) => e.isNotEmpty).toList();
}

Map<String, dynamic> platformFileToImageJson(PlatformFile file) {
  if (file.bytes == null) {
    throw Exception('${file.name} file-এর bytes পাওয়া যায়নি');
  }
  return <String, dynamic>{
    'picture_base64': base64Encode(file.bytes!),
    'file_name': file.name,
    'mime_type': mimeTypeFromFileName(file.name),
  };
}

/// Footwear sizes stay as 36-42. Other products (tents, umbrellas, etc.)
/// may describe their dimensions in the same text column.
String normalizeSizeRange(dynamic value) {
  return asText(value).trim().replaceAll(RegExp(r'\s*[-–—]\s*'), '-');
}

/// Oracle accepts any non-empty textual SIZE_RANGE / dimensions string.
/// Do not reject real inventory files based on footwear-specific grammar.
String? validateSizeRange(dynamic value) {
  final range = normalizeSizeRange(value);
  if (range.isEmpty) return 'Size Range / Dimensions is mandatory';
  if (range.length > 100) return 'Size Range / Dimensions must be within 100 characters';
  return null;
}

/// Convert explicitly labelled Excel weights to grams, as required by the
/// API. Bare numeric cells have always meant grams and continue to do so.
/// Returns null for an invalid weight, which the caller should reject.
double? parseExcelWeightGrams(dynamic value) {
  final raw = asText(value).replaceAll(',', '').trim();
  if (raw.isEmpty) return null;
  final match = RegExp(
    r'^([0-9]+(?:\.[0-9]+)?)\s*(KG|KGS|KILOGRAM|KILOGRAMS|G|GRAM|GRAMS)?$',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return null;
  final weight = double.tryParse(match.group(1)!);
  if (weight == null || !weight.isFinite || weight < 0) return null;
  final unit = (match.group(2) ?? 'G').toUpperCase();
  return unit.startsWith('K') ? weight * 1000 : weight;
}
