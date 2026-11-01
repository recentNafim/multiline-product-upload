import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/display_room_api_service.dart';
import '../../utils/auto_image_file_name.dart';
import '../../utils/excel_embedded_pictures.dart';
import '../../utils/excel_template_download.dart' as template_download;
import '../../utils/excel_value_utils.dart';

/// An image-only bulk update. ITEM CODE identifies a pre-existing product.
/// The existing GET ?p_item_code= and PUT images_to_delete/images_to_add
/// handlers are used; this page does NOT insert new products or change their
/// Buyer, FOB, MOQ, Size Range, quantity or other product attributes.
class BulkImageUpdatePage extends StatefulWidget {
  const BulkImageUpdatePage({super.key});

  @override
  State<BulkImageUpdatePage> createState() => _BulkImageUpdatePageState();
}

class _ImageUpdateRow {
  final int excelRow;
  final String itemCode;
  final List<String> filenames;
  final List<PlatformFile> embeddedPhotos;
  List<PlatformFile> photos = [];
  int? masterSl;
  int? detailSl;
  List<int> previousImageIds = [];
  String status = 'Pending';
  String message = '';

  _ImageUpdateRow({
    required this.excelRow,
    required this.itemCode,
    required this.filenames,
    required this.embeddedPhotos,
  });

  bool get isMatched => status == 'Matched';
}

class _BulkImageUpdatePageState extends State<BulkImageUpdatePage> {
  final _updatedByController = TextEditingController();
  String? _excelName;
  List<_ImageUpdateRow> _rows = [];
  final Map<String, PlatformFile> _externalPhotos = {};
  bool _busy = false;
  bool _checked = false;
  int _processed = 0;
  String? _pageError;

  @override
  void dispose() {
    _updatedByController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _downloadTemplate() {
    try {
      final excel = xls.Excel.createExcel();
      final sheet = excel['Sheet1'];
      sheet.appendRow([
        xls.TextCellValue('ITEM CODE'),
        xls.TextCellValue('IMAGE'),
      ]);
      final bytes = excel.encode();
      if (bytes == null) throw StateError('Could not encode Excel template');
      template_download.saveExcelTemplate(
        bytes, 'display_room_bulk_image_update_template.xlsx',
      );
    } catch (error) {
      _toast('Template download failed: $error');
    }
  }

  static String _key(String value) => value.trim().toUpperCase();

  static String _simpleFileName(String value) =>
      value.trim().replaceAll('\\', '/').split('/').last.toLowerCase();

  static String _mimeForImage(Uint8List bytes) {
    if (bytes.length > 3 && bytes[0] == 0xFF &&
        bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length > 8 &&
        bytes[0] == 137 && bytes[1] == 80 && bytes[2] == 78 &&
        bytes[3] == 71 && bytes[4] == 13 && bytes[5] == 10 &&
        bytes[6] == 26 && bytes[7] == 10) {
      return 'image/png';
    }
    if (bytes.length > 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    throw const FormatException('Only valid JPEG, PNG or WebP files are supported');
  }

  /// Keep the exact source image bytes; PUT supports 10 MB per image.
  static void _validatePhoto(PlatformFile file) {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw FormatException('Cannot read ${file.name}');
    }
    if (bytes.length > 10 * 1024 * 1024) {
      throw FormatException('${file.name} exceeds 10 MB');
    }
    _mimeForImage(bytes);
  }

  void _refreshRowValidation() {
    final seenCodes = <String, int>{};
    for (final row in _rows) {
      seenCodes.update(_key(row.itemCode), (old) => old + 1,
          ifAbsent: () => 1);
    }
    for (final row in _rows) {
      row.masterSl = null;
      row.detailSl = null;
      row.previousImageIds = [];
      row.status = 'Pending';
      row.message = '';
      row.photos = List<PlatformFile>.from(row.embeddedPhotos);
      if (row.photos.isEmpty) {
        for (final name in row.filenames) {
          final file = _externalPhotos[_simpleFileName(name)];
          if (file == null) {
            row.status = 'Invalid';
            row.message = 'Image file not selected: $name';
            break;
          }
          row.photos.add(file);
        }
      }
      if (row.itemCode.trim().isEmpty) {
        row.status = 'Invalid';
        row.message = 'ITEM CODE is empty';
      } else if ((seenCodes[_key(row.itemCode)] ?? 0) > 1) {
        row.status = 'Invalid';
        row.message = 'Repeated ITEM CODE in Excel';
      } else if (row.photos.isEmpty) {
        row.status = 'Invalid';
        row.message = 'Paste image in IMAGE cell, or enter filename and select that image';
      } else if (row.photos.length > 5) {
        row.status = 'Invalid';
        row.message = 'Maximum 5 images per product';
      } else {
        try {
          for (final image in row.photos) {
            _validatePhoto(image);
          }
        } catch (error) {
          row.status = 'Invalid';
          row.message = error.toString();
        }
      }
    }
    _checked = false;
    _processed = 0;
  }

  Future<void> _chooseExcel() async {
    if (_busy) return;
    setState(() { _busy = true; _pageError = null; });
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('Excel file data is missing');
      }
      final workbook = xls.Excel.decodeBytes(bytes);
      if (workbook.tables.isEmpty) {
        throw const FormatException('Workbook contains no sheets');
      }
      final sheet = workbook.tables.values.first;
      if (sheet.rows.isEmpty) {
        throw const FormatException('Excel sheet is empty');
      }
      final headings = sheet.rows.first.map((cell) =>
          normalizeHeader(asText(getExcelValue(cell)))).toList();
      final itemColumn = headings.indexOf('ITEM CODE');
      final imageColumn = headings.contains('IMAGE')
          ? headings.indexOf('IMAGE') : headings.indexOf('PICTURE');
      if (itemColumn < 0 || imageColumn < 0) {
        throw const FormatException('Excel row 1 must contain ITEM CODE and IMAGE headers');
      }
      final embedded = readExcelEmbeddedPictures(
        bytes, pictureColumnIndex: imageColumn,
      );
      final next = <_ImageUpdateRow>[];
      for (var index = 1; index < sheet.rows.length; index++) {
        final cells = sheet.rows[index];
        String cellAt(int column) => column >= cells.length
            ? '' : asText(getExcelValue(cells[column]));
        final code = cellAt(itemColumn);
        final photoNames = imageNamesFromExcelValue(cellAt(imageColumn));
        final photos = embedded[index] ?? const <PlatformFile>[];
        if (code.isEmpty && photoNames.isEmpty && photos.isEmpty) continue;
        next.add(_ImageUpdateRow(
          excelRow: index + 1,
          itemCode: code,
          filenames: photoNames,
          embeddedPhotos: List<PlatformFile>.from(photos),
        ));
      }
      if (next.isEmpty) throw const FormatException('No image rows found in Excel');
      if (next.length > 300) {
        throw const FormatException('Maximum 300 products per Excel file');
      }
      if (!mounted) return;
      setState(() {
        _excelName = file.name;
        _rows = next;
        _externalPhotos.clear();
        _refreshRowValidation();
      });
      _toast('${next.length} rows loaded. Review the preview before updating.');
    } catch (error) {
      if (mounted) setState(() => _pageError = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseExternalPhotos() async {
    if (_busy || _rows.isEmpty) return;
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: true,
        withData: true,
      );
      if (picked == null) return;
      final additions = <String, PlatformFile>{};
      final existingBytes = _externalPhotos.values.fold<int>(
          0, (sum, file) => sum + file.size);
      final addedBytes = picked.files.fold<int>(
          0, (sum, file) => sum + file.size);
      if (existingBytes + addedBytes > 120 * 1024 * 1024) {
        throw const FormatException('Selected image files exceed 120 MB total');
      }
      for (final photo in picked.files) {
        _validatePhoto(photo);
        final key = _simpleFileName(photo.name);
        if (additions.containsKey(key)) {
          throw FormatException('Duplicate image filename: ${photo.name}');
        }
        additions[key] = photo;
      }
      if (!mounted) return;
      setState(() {
        _externalPhotos.addAll(additions);
        _refreshRowValidation();
      });
    } catch (error) {
      _toast('Could not select image files: $error');
    }
  }

  /// Exact match by item code, not a fuzzy p_search. Detect duplicate products
  /// (including matches in different Display Room master records) and skip.
  Future<void> _checkMatches() async {
    if (_busy || _rows.isEmpty) return;
    setState(() { _busy = true; _pageError = null; _checked = false; });
    try {
      _refreshRowValidation();
      for (final row in _rows) {
        if (row.status == 'Invalid') continue;
        try {
          final response = await DisplayRoomApiService.getItemsByCode(row.itemCode);
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw FormatException('GET HTTP ${response.statusCode}');
          }
          final decoded = jsonDecode(response.body);
          if (decoded is! Map) throw const FormatException('Unexpected GET response');
          if (decoded['status_code']?.toString() != '200') {
            throw FormatException('${decoded['message'] ?? 'GET API failed'}');
          }
          final masters = decoded['data'];
          if (masters is! List) {
            throw const FormatException('GET API response has no data list');
          }
          final matches = <({int master, int detail, List<int> images})>[];
          var missingImageSl = false;
          for (final master in masters) {
            if (master is! Map) continue;
            final masterSl = int.tryParse('${master['sl']}');
            final details = master['details'];
            if (masterSl == null || details is! List) continue;
            for (final detail in details) {
              if (detail is! Map) continue;
              if (_key('${detail['item_code'] ?? ''}') != _key(row.itemCode)) {
                continue;
              }
              final detailSl = int.tryParse('${detail['sl']}');
              if (detailSl == null) continue;
              final imageIds = <int>[];
              final images = detail['images'];
              if (images is List) {
                for (final image in images) {
                  if (image is! Map) { missingImageSl = true; continue; }
                  final imageSl = int.tryParse('${image['sl']}');
                  if (imageSl == null) { missingImageSl = true; continue; }
                  imageIds.add(imageSl);
                }
              }
              matches.add((master: masterSl, detail: detailSl, images: imageIds));
            }
          }
          final totalRecords = int.tryParse('${decoded['total_records'] ?? masters.length}') ?? masters.length;
          if (totalRecords > 1 || matches.length > 1) {
            row.status = 'Conflict';
            row.message = 'Item Code matches multiple products/rooms; skipped';
          } else if (matches.isEmpty) {
            row.status = 'Not found';
            row.message = 'No existing product with this Item Code';
          } else if (missingImageSl) {
            row.status = 'Invalid';
            row.message = 'GET images[] missing SL; unsafe to replace';
          } else {
            final match = matches.single;
            row.masterSl = match.master;
            row.detailSl = match.detail;
            row.previousImageIds = match.images;
            row.status = 'Matched';
            row.message = '${match.images.length} saved gallery image(s) will be replaced';
          }
        } catch (error) {
          row.status = 'Failed';
          row.message = 'Match check failed: $error';
        }
        if (mounted) setState(() {});
      }
      if (mounted) setState(() => _checked = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateImages() async {
    if (_busy || !_checked) return;
    final staffId = int.tryParse(_updatedByController.text.trim());
    if (staffId == null || staffId <= 0) {
      _toast('Enter a valid Updated By (Staff ID) first.');
      return;
    }
    final matched = _rows.where((row) => row.isMatched).toList();
    if (matched.isEmpty) {
      _toast('There are no matched products to update.');
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm bulk image replacement'),
        content: Text('Replace existing gallery images for ${matched.length} matched product(s)? '
          'Only images will change. Existing image gallery entries are removed, '
          'and this action cannot be undone. Conflicts and invalid rows are skipped.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Replace Images')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() { _busy = true; _processed = 0; _pageError = null; });
    try {
      for (final row in matched) {
        row.status = 'Uploading';
        if (mounted) setState(() {});
        try {
          final timestamp = DateTime.now();
          final images = <Map<String, dynamic>>[];
          for (var index = 0; index < row.photos.length; index++) {
            final file = row.photos[index];
            final bytes = file.bytes!;
            final mime = _mimeForImage(bytes);
            final fileData = <String, dynamic>{
              'file_base64': base64Encode(bytes),
              'mime_type': mime,
              'file_name': file.name,
            };
            images.add(<String, dynamic>{
              ...fileData,
              'file_name': autoImageFileName(
                itemCode: row.itemCode,
                itemName: row.itemCode,
                excelSerial: row.excelRow,
                imageNumber: index + 1,
                image: fileData,
                uploadTime: timestamp,
              ),
            });
          }
          final payload = <String, dynamic>{
            'master_sl': row.masterSl,
            'updated_by': staffId,
            'details': [<String, dynamic>{
              'sl': row.detailSl,
              // Existing PUT handler recalculates inventory_item_id from
              // item_code even for image-only updates. Send the SAME code.
              'item_code': row.itemCode,
              'images_to_delete': [
                for (final id in row.previousImageIds) {'sl': id},
              ],
              'images_to_add': images,
            }],
          };
          final response = await DisplayRoomApiService.updateItem(payload);
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw FormatException('PUT HTTP ${response.statusCode}');
          }
          final body = jsonDecode(response.body);
          if (body is! Map || body['status_code']?.toString() != '200') {
            throw FormatException('API error: ${body is Map ? body['message'] : response.body}');
          }
          final added = int.tryParse('${body['added_images']}');
          final deleted = int.tryParse('${body['deleted_images']}');
          if ((added != null && added != images.length) ||
              (deleted != null && deleted != row.previousImageIds.length)) {
            throw const FormatException('Server image counters did not match request; verify manually');
          }
          row.status = 'Updated';
          row.message = '${images.length} new image(s) uploaded';
        } catch (error) {
          row.status = 'Failed';
          row.message = '$error';
        }
        _processed++;
        if (mounted) setState(() {});
      }
    } finally {
      if (mounted) setState(() { _busy = false; _checked = false; });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Matched': return Colors.teal;
      case 'Updated': return Colors.green;
      case 'Uploading': return Colors.blue;
      case 'Invalid':
      case 'Failed':
      case 'Conflict': return Colors.red;
      case 'Not found': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final matched = _rows.where((r) => r.isMatched).length;
    final updated = _rows.where((r) => r.status == 'Updated').length;
    final failed = _rows.where((r) => r.status == 'Failed').length;
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Product Image Update')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Replace existing product images by Item Code',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Excel column A: ITEM CODE. Column B: IMAGE. Insert/paste a '
          'picture anchored in each IMAGE cell (not just a hyperlink), or type '
          'image filenames and select those files separately. Maximum 5 pictures '
          'per item, 10 MB each, JPEG/PNG/WebP. The picture bytes are not compressed.'),
        const SizedBox(height: 8),
        const Text('Important: Format ITEM CODE cells as Text in Excel to keep leading zeros. '
          'No new product is created. Duplicate Item Codes in Excel or database are skipped.'),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _downloadTemplate,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Excel Template'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _chooseExcel,
            icon: const Icon(Icons.table_view_outlined),
            label: const Text('Select Excel with Images'),
          ),
          if (_rows.isNotEmpty) OutlinedButton.icon(
            onPressed: _busy ? null : _chooseExternalPhotos,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Select Named Image Files (optional)'),
          ),
        ]),
        if (_excelName != null) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Excel: $_excelName   |   ${_rows.length} product row(s)   '
            '|   ${_externalPhotos.length} external image file(s)'),
        ),
        const SizedBox(height: 14),
        SizedBox(width: 270, child: TextField(
          controller: _updatedByController,
          keyboardType: TextInputType.number,
          enabled: !_busy,
          decoration: const InputDecoration(
            labelText: 'Updated By / Staff ID *',
            border: OutlineInputBorder(),
          ),
        )),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: _busy || _rows.isEmpty ? null : _checkMatches,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('1. Check Item Code Matches'),
          ),
          FilledButton.icon(
            onPressed: _busy || !_checked || matched == 0 ? null : _updateImages,
            icon: const Icon(Icons.sync),
            label: Text('2. Replace Images ($matched matched)'),
          ),
        ]),
        if (_busy) const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: LinearProgressIndicator(),
        ),
        if (_pageError != null) Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_pageError!, style: const TextStyle(color: Colors.red)),
        ),
        if (_rows.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Preview and results — ${_rows.length} rows, $updated updated, '
              '$failed failed, $_processed processed',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Excel Row')),
                DataColumn(label: Text('Item Code')),
                DataColumn(label: Text('Image Preview')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Details')),
              ],
              rows: [for (final row in _rows)
                DataRow(cells: [
                  DataCell(Text('${row.excelRow}')),
                  DataCell(SelectableText(row.itemCode)),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    for (final photo in row.photos.take(3))
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Image.memory(photo.bytes!, width: 48, height: 48,
                            fit: BoxFit.cover, filterQuality: FilterQuality.medium,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image_outlined)),
                      ),
                    if (row.photos.length > 3) Text('+${row.photos.length - 3}'),
                  ])),
                  DataCell(Text(row.status, style: TextStyle(
                    color: _statusColor(row.status), fontWeight: FontWeight.w600))),
                  DataCell(SizedBox(width: 340, child: Text(row.message,
                      maxLines: 3, overflow: TextOverflow.ellipsis))),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('The Display Website will show the new images after refreshing '
            'its product list. Existing Buyer, Display Room Name, MOQ, Size Range '
            'and other product values are preserved.'),
        ],
      ]),
    );
  }
}
