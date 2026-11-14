import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Some Excel-authored files incorrectly repeat built-in number formats
/// (IDs 0..163) inside xl/styles.xml's *custom* numFmts list. The `excel`
/// package expects that list to start at ID 164, so Excel.decodeBytes can
/// throw "custom numFmtId starts at 164 but found a value of 44".
///
/// Only remove those duplicate built-in declarations. Excel still knows
/// the built-in IDs used by the style references, and all cell values,
/// pictures, drawing anchors, sheet names, and other ZIP entries stay intact.
/// This function is intended ONLY as a fallback after that exact decode error.
Uint8List repairBuiltInNumberFormats(Uint8List originalBytes) {
  final archive = ZipDecoder().decodeBytes(originalBytes);
  const stylesPath = 'xl/styles.xml';
  ArchiveFile? stylesFile;
  for (final entry in archive.files) {
    if (entry.name.replaceAll('\\', '/') == stylesPath) {
      stylesFile = entry;
      break;
    }
  }
  if (stylesFile == null || !stylesFile.isFile) return originalBytes;

  final dynamic contents = stylesFile.content;
  if (contents is! List<int>) {
    throw const FormatException('Cannot read Excel styles.xml');
  }

  final document = XmlDocument.parse(utf8.decode(contents));
  final formats = document.findAllElements('numFmts');
  if (formats.isEmpty) return originalBytes;
  final numFmts = formats.first;
  var removed = 0;
  for (final format in numFmts.findElements('numFmt').toList()) {
    final id = int.tryParse(format.getAttribute('numFmtId') ?? '');
    if (id != null && id < 164) {
      format.remove();
      removed++;
    }
  }
  if (removed == 0) return originalBytes;
  numFmts.setAttribute('count', numFmts.findElements('numFmt').length.toString());

  final fixedStyles = utf8.encode(document.toXmlString());
  final repaired = Archive();
  for (final entry in archive.files) {
    if (entry.name.replaceAll('\\', '/') == stylesPath) {
      repaired.addFile(ArchiveFile(stylesPath, fixedStyles.length, fixedStyles));
    } else {
      repaired.addFile(entry);
    }
  }
  final bytes = ZipEncoder().encode(repaired);
  if (bytes == null || bytes.isEmpty) {
    throw const FormatException('Unable to normalize Excel styles');
  }
  return Uint8List.fromList(bytes);
}
