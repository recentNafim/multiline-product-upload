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

/// Standard client size-range format: 36-42 (decimal sizes like 6.5-10 also work).
/// Spaces and typographic dashes are normalized to the ASCII hyphen used by
/// the Oracle API. Do not convert sizes into dates or two separate fields.
String normalizeSizeRange(dynamic value) {
  return asText(value)
      .trim()
      .replaceAll(RegExp(r'\s*[-–—]\s*'), '-');
}

/// Return null when the size range is a valid number-number interval.
String? validateSizeRange(dynamic value) {
  final String range = normalizeSizeRange(value);
  if (range.isEmpty) {
    return 'Size Range is mandatory (e.g. 36-42)';
  }

  final match = RegExp(r'^([0-9]+(?:\.[0-9]+)?)-([0-9]+(?:\.[0-9]+)?)$')
      .firstMatch(range);
  if (match == null) {
    return 'Use numeric Size Range like 36-42 (not S-XL)';
  }

  final double lower = double.parse(match.group(1)!);
  final double upper = double.parse(match.group(2)!);
  if (lower > upper) {
    return 'Lower size must not be greater than upper size';
  }
  return null;
}
