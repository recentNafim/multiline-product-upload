import 'dart:convert';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';

String normalizeHeader(String value) => value.trim().toUpperCase()
    .replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ');

/// Map common customer Excel headings onto the existing upload contract.
/// This changes only how column headings are interpreted; cell values stay
/// intact and absent optional fields remain absent.
String canonicalUploadHeader(String raw) {
  final header = normalizeHeader(raw);
  final compact = header.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (const <String>{
    'SIZE', 'SIZES', 'SIZERANGE', 'SIZERANGES', 'DIMENSION', 'DIMENSIONS',
    'PRODUCTSIZE', 'PRODUCTDIMENSION', 'PRODUCTDIMENSIONS',
    'SIZEANDDIMENSION', 'SIZEANDDIMENSIONS', 'MEASUREMENT', 'MEASUREMENTS',
  }.contains(compact) ||
      compact.startsWith('SIZERANGE') ||
      compact.startsWith('PRODUCTSIZE') ||
      compact.startsWith('DIMENSION') ||
      compact.startsWith('PRODUCTDIMENSION') ||
      const <String>{'SIZECM', 'SIZEMM', 'SIZEINCH', 'SIZEINCHES'}
          .contains(compact)) {
    return 'SIZE RANGE';
  }
  if (const <String>{
    'WEIGHT', 'WEIGHTTEXT', 'WT', 'NETWEIGHT', 'GROSSWEIGHT',
    'PRODUCTWEIGHT', 'ITEMWEIGHT', 'WEIGHTG', 'WEIGHTGM', 'WEIGHTGRAM',
    'WEIGHTGRAMS', 'WEIGHTKG', 'WEIGHTKGS', 'WEIGHTKILOGRAM',
    'WEIGHTKILOGRAMS', 'NETWEIGHTKG', 'GROSSWEIGHTKG',
    'PRODUCTWEIGHTKG', 'ITEMWEIGHTKG',
  }.contains(compact) ||
      compact.startsWith('NETWEIGHT') ||
      compact.startsWith('GROSSWEIGHT') ||
      compact.startsWith('PRODUCTWEIGHT') ||
      compact.startsWith('ITEMWEIGHT') ||
      const <String>{'WEIGHTLB', 'WEIGHTLBS', 'WEIGHTPOUND', 'WEIGHTPOUNDS'}
          .contains(compact)) {
    return 'WEIGHT';
  }
  if (const <String>{'ITEMDESCRIPTION', 'PRODUCTNAME', 'PRODUCTDESCRIPTION'}
      .contains(compact)) return 'ITEM NAME';
  return header;
}

/// For explicit unit-bearing weight headings, retain the source unit.
/// Example: WEIGHT (KG) with numeric 0.740 -> "0.740 kg".
/// WEIGHT with no unit remains exactly as supplied (no assumed conversion).
String excelWeightWithHeadingUnit(dynamic value, String rawHeading) {
  final entered = asText(value);
  if (entered.isEmpty) return '';
  if (double.tryParse(entered.replaceAll(',', '')) == null) return entered;
  final upper = normalizeHeader(rawHeading);
  if (RegExp(r'(^|[^A-Z])KG(S)?($|[^A-Z])').hasMatch(upper) ||
      upper.contains('KILOGRAM')) return '$entered kg';
  if (RegExp(r'(^|[^A-Z])G(RAM|RAMS|M)?($|[^A-Z])').hasMatch(upper)) {
    return '$entered g';
  }
  if (RegExp(r'(^|[^A-Z])LBS?($|[^A-Z])').hasMatch(upper) ||
      upper.contains('POUND')) return '$entered lb';
  return entered;
}

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

/// Preserve free-form size/dimension text exactly apart from edge spaces.
String normalizeSizeRange(dynamic value) => asText(value).trim();

/// SIZE RANGE is optional and free-form. No footwear-specific validation.
/// The Oracle VARCHAR2(500) storage still imposes its technical limit.
String? validateSizeRange(dynamic value) {
  final range = normalizeSizeRange(value);
  if (range.length > 500) return 'Size/Dimensions cannot exceed 500 characters';
  return null;
}

/// Legacy numeric grams helper. Arbitrary text is always saved separately
/// in WEIGHT_TEXT; null here is valid and must never reject an upload.
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
