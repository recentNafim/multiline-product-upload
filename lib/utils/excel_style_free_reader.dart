import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Reads cell values without parsing xl/styles.xml. This avoids `excel`'s
/// "custom numFmtId starts at 164" failure in otherwise valid Office files.
/// No file is modified, and the original bytes remain available for embedded
/// pictures and GLB/image payloads.
class ExcelImportSheet {
  const ExcelImportSheet({required this.name, required this.rows});

  final String name;
  final List<List<dynamic>> rows;
}

ExcelImportSheet readExcelSheetWithoutStyles(Uint8List originalBytes) {
  final archive = ZipDecoder().decodeBytes(originalBytes);
  final files = <String, ArchiveFile>{
    for (final file in archive.files)
      if (file.isFile) file.name.replaceAll('\\', '/'): file,
  };

  XmlDocument? readXml(String path) {
    final entry = files[path];
    if (entry == null) return null;
    final dynamic content = entry.content;
    if (content is! List<int>) {
      throw FormatException('Cannot read $path from workbook');
    }
    return XmlDocument.parse(utf8.decode(content));
  }

  XmlElement? firstNamed(XmlNode element, String localName) {
    for (final node in element.descendants.whereType<XmlElement>()) {
      if (node.name.local == localName) return node;
    }
    return null;
  }

  Iterable<XmlElement> named(XmlNode element, String localName) =>
      element.descendants.whereType<XmlElement>()
          .where((node) => node.name.local == localName);

  final workbook = readXml('xl/workbook.xml');
  if (workbook == null) {
    throw const FormatException('Not a valid .xlsx workbook (workbook.xml missing)');
  }
  final sheets = named(workbook, 'sheet').toList();
  if (sheets.isEmpty) {
    throw const FormatException('Excel has no worksheets');
  }
  final firstSheet = sheets.first;
  final sheetName = firstSheet.getAttribute('name') ?? 'Sheet1';
  String? sheetRelId;
  for (final a in firstSheet.attributes) {
    if (a.name.local == 'id') {
      sheetRelId = a.value;
      break;
    }
  }
  if (sheetRelId == null) {
    throw const FormatException('Worksheet relationship ID missing');
  }

  final relationships = readXml('xl/_rels/workbook.xml.rels');
  if (relationships == null) {
    throw const FormatException('Excel worksheet relationships missing');
  }
  String? target;
  for (final relation in named(relationships, 'Relationship')) {
    if (relation.getAttribute('Id') == sheetRelId &&
        relation.getAttribute('TargetMode') != 'External') {
      target = relation.getAttribute('Target');
      break;
    }
  }
  if (target == null) {
    throw FormatException('Worksheet $sheetName has no target');
  }
  String resolvePart(String parent, String child) {
    final value = child.replaceAll('\\', '/');
    if (value.startsWith('/')) return value.substring(1);
    final dir = parent.substring(0, parent.lastIndexOf('/') + 1);
    final parts = <String>[];
    for (final part in '$dir$value'.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else {
        parts.add(part);
      }
    }
    return parts.join('/');
  }

  final worksheet = readXml(resolvePart('xl/workbook.xml', target));
  if (worksheet == null) {
    throw const FormatException('Excel worksheet XML missing');
  }

  // Shared string values may be plain or split into multiple rich-text runs.
  final sharedStrings = <String>[];
  final sharedDoc = readXml('xl/sharedStrings.xml');
  if (sharedDoc != null) {
    for (final si in named(sharedDoc, 'si')) {
      sharedStrings.add(named(si, 't').map((e) => e.innerText).join());
    }
  }

  dynamic readCell(XmlElement cell) {
    final type = cell.getAttribute('t') ?? '';
    if (type == 'inlineStr') {
      final inline = firstNamed(cell, 'is');
      return inline == null ? '' : named(inline, 't').map((e) => e.innerText).join();
    }
    final value = firstNamed(cell, 'v')?.innerText;
    if (value == null) {
      // Formulas without a cached result should be treated as empty.
      // Never upload the formula expression as product data.
      return null;
    }
    if (type == 's') {
      final index = int.tryParse(value);
      if (index == null || index < 0 || index >= sharedStrings.length) {
        throw FormatException('Invalid shared string index: $value');
      }
      return sharedStrings[index];
    }
    if (type == 'b') return value == '1';
    if (type == 'str' || type == 'e' || type == 'd') return value;
    // Preserve integers and decimals without interpreting cell styles.
    final integer = int.tryParse(value);
    if (integer != null) return integer;
    return double.tryParse(value) ?? value;
  }

  int columnIndex(String? cellReference) {
    if (cellReference == null) return -1;
    var result = 0;
    var found = false;
    for (final unit in cellReference.codeUnits) {
      final upper = unit >= 97 && unit <= 122 ? unit - 32 : unit;
      if (upper < 65 || upper > 90) break;
      result = result * 26 + (upper - 64);
      found = true;
    }
    return found ? result - 1 : -1;
  }

  final resultRows = <List<dynamic>>[];
  final sheetData = firstNamed(worksheet, 'sheetData');
  if (sheetData == null) {
    return ExcelImportSheet(name: sheetName, rows: resultRows);
  }
  for (final row in sheetData.children.whereType<XmlElement>()
      .where((e) => e.name.local == 'row')) {
    final excelRowNumber = int.tryParse(row.getAttribute('r') ?? '') ??
        resultRows.length + 1;
    if (excelRowNumber <= 0 || excelRowNumber > 100000) {
      throw FormatException('Invalid Excel row number: $excelRowNumber');
    }
    while (resultRows.length < excelRowNumber - 1) {
      resultRows.add(<dynamic>[]);
    }
    final values = <dynamic>[];
    var nextColumn = 0;
    for (final cell in row.children.whereType<XmlElement>()
        .where((e) => e.name.local == 'c')) {
      final column = columnIndex(cell.getAttribute('r'));
      final index = column >= 0 ? column : nextColumn;
      // Do not allocate a huge array for a corrupt A1-style reference.
      if (index > 16383) {
        throw FormatException('Invalid Excel column index: $index');
      }
      while (values.length <= index) {
        values.add(null);
      }
      values[index] = readCell(cell);
      nextColumn = index + 1;
    }
    if (excelRowNumber <= resultRows.length) {
      resultRows[excelRowNumber - 1] = values;
    } else {
      resultRows.add(values);
    }
  }
  return ExcelImportSheet(name: sheetName, rows: resultRows);
}
