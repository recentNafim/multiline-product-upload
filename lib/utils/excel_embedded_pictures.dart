import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart';

// Excel's embedded pictures are drawing objects, NOT values of the cells
// underneath them. The excel package decodes cell values but does not put
// drawing images in PICTURE cells. Resolve XLSX drawing anchors and .rels so
// pictures pasted on F2/F3 can be uploaded without selecting separate files.
//
// Keys in the result are zero-based Excel row indexes (header is row 0).
// A picture is accepted only when its top-left anchor is in PICTURE column.
Map<int, List<PlatformFile>> readExcelEmbeddedPictures(
  Uint8List xlsxBytes, {
  required int pictureColumnIndex,
}) {
  if (pictureColumnIndex < 0 || xlsxBytes.length > 80 * 1024 * 1024) {
    return <int, List<PlatformFile>>{};
  }

  final archive = ZipDecoder().decodeBytes(xlsxBytes);
  final entries = <String, ArchiveFile>{
    for (final file in archive)
      if (file.isFile) file.name.replaceAll('\\', '/'): file,
  };

  // archive 3.x, which is required by excel 4.0.6, exposes file content
  // via ArchiveFile.content. readBytes() belongs to archive 4.x.
  Uint8List? entryBytes(ArchiveFile? entry) {
    if (entry == null || !entry.isFile) return null;
    final dynamic content = entry.content;
    if (content is Uint8List) return content;
    if (content is List<int>) return Uint8List.fromList(content);
    return null;
  }

  XmlDocument? readXml(String path) {
    final data = entryBytes(entries[path]);
    if (data == null) return null;
    return XmlDocument.parse(utf8.decode(data));
  }

  // The first sheet is the same sheet chosen by Excel.decodeBytes above.
  final book = readXml('xl/workbook.xml');
  final sheets = book?.descendants.whereType<XmlElement>().where(
        (element) => element.name.local == 'sheet',
      );
  if (sheets == null || sheets.isEmpty) return {};

  final sheetRelId = sheets.first.getAttribute(
    'id',
    namespace: 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
  );
  if (sheetRelId == null) return {};

  final bookRels = _excelRelationships(readXml('xl/_rels/workbook.xml.rels'));
  final sheetTarget = bookRels[sheetRelId];
  if (sheetTarget == null) return {};
  final sheetPath = _resolveExcelPath('xl/workbook.xml', sheetTarget);

  final sheetDoc = readXml(sheetPath);
  if (sheetDoc == null) return {};
  final sheetDrawing = sheetDoc.descendants.whereType<XmlElement>().where(
        (element) => element.name.local == 'drawing',
      );
  if (sheetDrawing.isEmpty) return {};

  final sheetDrawingId = sheetDrawing.first.getAttribute(
    'id',
    namespace: 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
  );
  if (sheetDrawingId == null) return {};

  final sheetRelsPath = _excelRelationshipFilePath(sheetPath);
  final sheetRels = _excelRelationships(readXml(sheetRelsPath));
  final drawingTarget = sheetRels[sheetDrawingId];
  if (drawingTarget == null) return {};
  final drawingPath = _resolveExcelPath(sheetPath, drawingTarget);

  final drawingDoc = readXml(drawingPath);
  if (drawingDoc == null) return {};
  final imageRels = _excelRelationships(
    readXml(_excelRelationshipFilePath(drawingPath)),
  );

  final result = <int, List<PlatformFile>>{};
  var totalImageBytes = 0;
  for (final anchor in drawingDoc.descendants.whereType<XmlElement>()) {
    if (anchor.name.local != 'twoCellAnchor' &&
        anchor.name.local != 'oneCellAnchor') {
      continue;
    }

    final from = _directXmlChild(anchor, 'from');
    if (from == null) continue;
    final col = int.tryParse(_directXmlChild(from, 'col')?.innerText ?? '');
    final row = int.tryParse(_directXmlChild(from, 'row')?.innerText ?? '');
    if (col != pictureColumnIndex || row == null || row < 1) continue;

    // Excel supports several shapes per cell; allow up to five pictures.
    for (final pic in anchor.descendants.whereType<XmlElement>().where(
          (element) => element.name.local == 'pic',
        )) {
      final blips = pic.descendants.whereType<XmlElement>().where(
            (element) => element.name.local == 'blip',
          );
      if (blips.isEmpty) continue;
      final imageRelId = blips.first.getAttribute(
        'embed',
        namespace: 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
      );
      final imageTarget = imageRels[imageRelId];
      if (imageTarget == null) continue;
      final imagePath = _resolveExcelPath(drawingPath, imageTarget);
      final suffix = imagePath.toLowerCase().split('.').last;
      if (!const ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(suffix)) {
        continue;
      }
      final file = entries[imagePath];
      if (file == null || file.size > 12 * 1024 * 1024) continue;

      final rowImages = result.putIfAbsent(row, () => <PlatformFile>[]);
      if (rowImages.length >= 5) continue;
      final bytes = entryBytes(file);
      if (bytes == null || bytes.isEmpty) continue;
      totalImageBytes += bytes.length;
      if (totalImageBytes > 60 * 1024 * 1024) {
        throw FormatException('Excel embedded pictures exceed 60 MB');
      }
      rowImages.add(PlatformFile(
        name: 'excel_row_${row + 1}_image_${rowImages.length + 1}.$suffix',
        size: bytes.length,
        bytes: Uint8List.fromList(bytes),
      ));
    }
  }
  return result;
}

XmlElement? _directXmlChild(XmlElement parent, String localName) {
  for (final node in parent.children.whereType<XmlElement>()) {
    if (node.name.local == localName) return node;
  }
  return null;
}

Map<String, String> _excelRelationships(XmlDocument? document) {
  if (document == null) return {};
  return <String, String>{
    for (final rel in document.descendants.whereType<XmlElement>())
      if (rel.name.local == 'Relationship' &&
          rel.getAttribute('Id') != null &&
          rel.getAttribute('Target') != null &&
          rel.getAttribute('TargetMode') != 'External')
        rel.getAttribute('Id')!: rel.getAttribute('Target')!,
  };
}

String _excelRelationshipFilePath(String partPath) {
  final slash = partPath.lastIndexOf('/');
  final parent = partPath.substring(0, slash);
  final fileName = partPath.substring(slash + 1);
  return '$parent/_rels/$fileName.rels';
}

String _resolveExcelPath(String fromPath, String toPath) {
  if (toPath.startsWith('/')) return toPath.substring(1);
  final path = '${fromPath.substring(0, fromPath.lastIndexOf('/') + 1)}$toPath';
  final segments = <String>[];
  for (final part in path.replaceAll('\\', '/').split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (segments.isNotEmpty) segments.removeLast();
    } else {
      segments.add(part);
    }
  }
  return segments.join('/');
}
