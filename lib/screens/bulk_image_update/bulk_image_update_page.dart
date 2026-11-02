import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/display_room_api_service.dart';

/// Bulk replacement of existing product gallery images using IMAGE FILENAMES.
/// No Excel workbook is needed. Example: 92223337980.jpg -> item 92223337980.
/// Multiple images for a single item: ITEMCODE__1.jpg, ITEMCODE__2.png.
///
/// Only the existing GET (exact p_item_code) and PUT
/// (images_to_delete/images_to_add) endpoints are used. This page does NOT
/// create products or modify Buyer, Display Room Name, MOQ, FOB or Size Range.
class BulkImageUpdatePage extends StatefulWidget {
  const BulkImageUpdatePage({super.key});

  @override
  State<BulkImageUpdatePage> createState() => _BulkImageUpdatePageState();
}

class _ImageUpdateRow {
  final String itemCode;
  final List<PlatformFile> photos;
  int? masterSl;
  int? detailSl;
  List<int> previousImageIds = [];
  String status = 'Pending';
  String message = '';

  _ImageUpdateRow({required this.itemCode, required this.photos});

  bool get isMatched => status == 'Matched';
}

class _BulkImageUpdatePageState extends State<BulkImageUpdatePage> {
  static const int _maxImageBytes = 10 * 1024 * 1024;
  static const int _maxTotalBytes = 120 * 1024 * 1024;
  static const int _maxProducts = 300;
  static const int _maxImagesPerProduct = 5;

  final TextEditingController _updatedByController = TextEditingController();
  // Keyed by the original (case-insensitive) filename, NOT the item code.
  final Map<String, PlatformFile> _filesByName = {};
  List<_ImageUpdateRow> _rows = [];
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static String _key(String value) => value.trim().toUpperCase();

  static String _baseFilename(String value) =>
      value.trim().replaceAll('\\', '/').split('/').last;

  /// Exact filename stem is the item code. For multiple images per product,
  /// ONLY a double-underscore + 1..5 suffix is treated as an image number.
  /// Single dashes/underscores remain part of the actual item code.
  static String _itemCodeFromFilename(String filename) {
    final name = _baseFilename(filename);
    final dot = name.lastIndexOf('.');
    if (dot <= 0) {
      throw FormatException('Image filename needs an extension: $name');
    }
    var stem = name.substring(0, dot).trim();
    final numbered = RegExp(r'^(.*)__([1-5])$').firstMatch(stem);
    if (numbered != null) stem = numbered.group(1)!.trim();
    if (stem.isEmpty) {
      throw FormatException('Image filename has no Item Code: $name');
    }
    return stem;
  }

  static int _imageOrder(String filename) {
    final name = _baseFilename(filename);
    final dot = name.lastIndexOf('.');
    final stem = dot < 0 ? name : name.substring(0, dot);
    final numbered = RegExp(r'__(\d+)$').firstMatch(stem);
    return numbered == null ? 0 : (int.tryParse(numbered.group(1)!) ?? 0);
  }

  static String _mimeForImage(Uint8List bytes) {
    if (bytes.length > 3 &&
        bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 137 && bytes[1] == 80 && bytes[2] == 78 &&
        bytes[3] == 71 && bytes[4] == 13 && bytes[5] == 10 &&
        bytes[6] == 26 && bytes[7] == 10) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    throw const FormatException('File is not a valid JPEG, PNG or WebP image');
  }

  static void _validatePhoto(PlatformFile file) {
    final name = _baseFilename(file.name);
    final dot = name.lastIndexOf('.');
    final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      throw FormatException('$name: only JPG, JPEG, PNG, WebP allowed');
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw FormatException('$name: could not read the image bytes');
    }
    if (bytes.length > _maxImageBytes) {
      throw FormatException('$name: maximum 10 MB per image');
    }
    final actual = _mimeForImage(bytes);
    final expected = (extension == 'jpg' || extension == 'jpeg')
        ? 'image/jpeg' : 'image/$extension';
    if (expected != actual) {
      throw FormatException('$name: extension does not match image content');
    }
  }

  /// Build one preview/upload row per distinct code, preserving leading zeros.
  /// A file's plain stem is a code, never an Excel row or a fuzzy name match.
  void _rebuildRows() {
    final grouped = <String, _ImageUpdateRow>{};
    for (final file in _filesByName.values) {
      final code = _itemCodeFromFilename(file.name);
      final key = _key(code);
      grouped.putIfAbsent(key, () => _ImageUpdateRow(itemCode: code, photos: []))
          .photos.add(file);
    }
    _rows = grouped.values.toList()
      ..sort((a, b) => a.itemCode.toLowerCase().compareTo(b.itemCode.toLowerCase()));
    for (final row in _rows) {
      row.photos.sort((a, b) {
        final bySequence = _imageOrder(a.name).compareTo(_imageOrder(b.name));
        return bySequence == 0
            ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
            : bySequence;
      });
      if (row.photos.length > _maxImagesPerProduct) {
        row.status = 'Invalid';
        row.message = 'Maximum 5 images per Item Code';
        continue;
      }
      try {
        for (final image in row.photos) {
          _validatePhoto(image);
        }
        row.status = 'Pending';
        row.message = 'Ready to check the existing product';
      } catch (error) {
        row.status = 'Invalid';
        row.message = error.toString();
      }
    }
    _checked = false;
    _processed = 0;
  }

  /// Allows choosing many images at once, including many different item codes.
  /// Selecting a second batch adds to the selection; duplicate names are blocked.
  Future<void> _chooseImages() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: true,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;

      final incoming = <String, PlatformFile>{};
      for (final file in picked.files) {
        _itemCodeFromFilename(file.name);
        _validatePhoto(file);
        final filenameKey = _key(_baseFilename(file.name));
        if (_filesByName.containsKey(filenameKey) || incoming.containsKey(filenameKey)) {
          throw FormatException('Duplicate filename: ${file.name}. Remove it before selecting again.');
        }
        incoming[filenameKey] = file;
      }
      final existingBytes = _filesByName.values.fold<int>(0, (n, p) => n + p.size);
      final newBytes = incoming.values.fold<int>(0, (n, p) => n + p.size);
      if (existingBytes + newBytes > _maxTotalBytes) {
        throw const FormatException('Total selected images must be 120 MB or less');
      }
      final allCodes = <String>{
        ..._rows.map((r) => _key(r.itemCode)),
        ...incoming.values.map((f) => _key(_itemCodeFromFilename(f.name))),
      };
      if (allCodes.length > _maxProducts) {
        throw const FormatException('Maximum 300 distinct Item Codes per batch');
      }
      if (!mounted) return;
      setState(() {
        _filesByName.addAll(incoming);
        _pageError = null;
        _rebuildRows();
      });
      _toast('${incoming.length} image(s) selected. Please review Item Code matches.');
    } catch (error) {
      if (mounted) setState(() => _pageError = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _removeImage(PlatformFile file) {
    if (_busy) return;
    setState(() {
      _filesByName.remove(_key(_baseFilename(file.name)));
      _rebuildRows();
    });
  }

  void _clearImages() {
    if (_busy) return;
    setState(() {
      _filesByName.clear();
      _rows = [];
      _checked = false;
      _processed = 0;
      _pageError = null;
    });
  }

  /// Only EXACT p_item_code lookups are allowed. Conflicting database rows
  /// (including identical codes in different Display Rooms) are never updated.
  Future<void> _checkMatches() async {
    if (_busy || _rows.isEmpty) return;
    setState(() {
      _busy = true;
      _checked = false;
      _processed = 0;
      _pageError = null;
    });
    try {
      for (final row in _rows) {
        row.masterSl = null;
        row.detailSl = null;
        row.previousImageIds = [];
        if (row.photos.length > _maxImagesPerProduct) {
          row.status = 'Invalid';
          row.message = 'Maximum 5 images per Item Code';
          continue;
        }
        try {
          for (final image in row.photos) {
            _validatePhoto(image);
          }
        } catch (error) {
          row.status = 'Invalid';
          row.message = error.toString();
          continue;
        }
        row.status = 'Checking';
        if (mounted) setState(() {});
        try {
          final response = await DisplayRoomApiService.getItemsByCode(row.itemCode);
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw FormatException('GET HTTP ${response.statusCode}');
          }
          final decoded = jsonDecode(response.body);
          if (decoded is! Map || decoded['status_code']?.toString() != '200') {
            throw FormatException('GET API: ${decoded is Map ? decoded['message'] : 'unexpected response'}');
          }
          final masters = decoded['data'];
          if (masters is! List) {
            throw const FormatException('GET response has no data array');
          }
          final matches = <({int master, int detail, List<int> images})>[];
          var missingImageSl = false;
          for (final master in masters) {
            if (master is! Map) continue;
            final masterSl = int.tryParse('${master['sl']}');
            final details = master['details'];
            if (masterSl == null || details is! List) continue;
            for (final detail in details) {
              if (detail is! Map || _key('${detail['item_code'] ?? ''}') != _key(row.itemCode)) {
                continue;
              }
              final detailSl = int.tryParse('${detail['sl']}');
              if (detailSl == null) continue;
              final imageIds = <int>[];
              final images = detail['images'];
              if (images is List) {
                for (final image in images) {
                  if (image is! Map) {
                    missingImageSl = true;
                    continue;
                  }
                  final imageSl = int.tryParse('${image['sl']}');
                  if (imageSl == null) {
                    missingImageSl = true;
                    continue;
                  }
                  imageIds.add(imageSl);
                }
              }
              matches.add((master: masterSl, detail: detailSl, images: imageIds));
            }
          }
          // The GET response returns a count of ALL matching masters even
          // if pagination limits the data array to its first page.
          final totalRecords = int.tryParse('${decoded['total_records'] ?? masters.length}')
              ?? masters.length;
          if (totalRecords > 1 || matches.length > 1) {
            row.status = 'Conflict';
            row.message = 'This Item Code exists in multiple products / rooms. Skipped.';
          } else if (matches.isEmpty) {
            row.status = 'Not found';
            row.message = 'No existing product has this exact Item Code';
          } else if (missingImageSl) {
            row.status = 'Invalid';
            row.message = 'Saved image metadata has no SL; replacement is unsafe';
          } else {
            final match = matches.single;
            row.masterSl = match.master;
            row.detailSl = match.detail;
            row.previousImageIds = match.images;
            row.status = 'Matched';
            row.message = '${match.images.length} old image(s) will be replaced by '
                '${row.photos.length} selected image(s)';
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
      _toast('Enter a valid Updated By / Staff ID first');
      return;
    }
    final matched = _rows.where((row) => row.isMatched).toList();
    if (matched.isEmpty) {
      _toast('No uniquely matched products to update');
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replace product images?'),
        content: Text('This will replace the existing image gallery for '
            '${matched.length} uniquely matched product(s). Only images will change. '
            'The action cannot be undone. Missing/duplicate Item Codes are skipped.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Replace Images'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      _busy = true;
      _processed = 0;
      _pageError = null;
    });
    try {
      // Fail closed: an older PUT handler ignores "mode" and could update
      // inventory_item_id while processing image requests. Confirm the new
      // safe API is deployed BEFORE sending any real product update.
      final capabilityResponse = await DisplayRoomApiService.updateItem(
        {'mode': 'CAPABILITY_CHECK'},
      );
      if (capabilityResponse.statusCode < 200 ||
          capabilityResponse.statusCode >= 300) {
        throw const FormatException(
          'Server does not support safe IMAGE_ONLY updates yet. Update the PUT API first.',
        );
      }
      final capability = jsonDecode(capabilityResponse.body);
      if (capability is! Map ||
          capability['status_code']?.toString() != '200' ||
          capability['supports_image_only'] != true ||
          capability['image_only_version'] != 'v1') {
        throw const FormatException(
          'Safe IMAGE_ONLY API was not detected. No products have been changed.',
        );
      }

      for (final row in matched) {
        row.status = 'Uploading';
        if (mounted) setState(() {});
        try {
          final images = <Map<String, dynamic>>[];
          for (final file in row.photos) {
            final bytes = file.bytes!;
            images.add({
              'file_base64': base64Encode(bytes),
              'mime_type': _mimeForImage(bytes),
              // Preserve the original Item Code filename in database metadata.
              // The existing PUT API generates a unique physical server filename.
              'file_name': _baseFilename(file.name),
            });
          }
          final payload = <String, dynamic>{
            'mode': 'IMAGE_ONLY',
            'master_sl': row.masterSl,
            'updated_by': staffId,
            'details': [<String, dynamic>{
              'sl': row.detailSl,
              // Safe PUT verifies the exact filename-derived Item Code but
              // does not update any product data fields.
              'item_code': row.itemCode,
              'images_to_delete': [
                for (final id in row.previousImageIds) {'sl': id},
              ],
              'images_to_add': images,
            }],
          };
          final response = await DisplayRoomApiService.updateItem(payload);
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw FormatException('PUT HTTP ${response.statusCode}: '
                '${response.body.length > 220 ? response.body.substring(0, 220) : response.body}');
          }
          final result = jsonDecode(response.body);
          if (result is! Map || result['status_code']?.toString() != '200' ||
              result['mode'] != 'IMAGE_ONLY') {
            throw FormatException('Safe IMAGE_ONLY PUT failed: ${result is Map ? result['message'] : 'invalid response'}');
          }
          final added = int.tryParse('${result['added_images']}');
          final deleted = int.tryParse('${result['deleted_images']}');
          if (added != images.length || deleted != row.previousImageIds.length) {
            throw const FormatException(
              'The server returned unexpected gallery counts. Check the updated product before retrying.',
            );
          }
          row.status = 'Updated';
          row.message = '${images.length} image(s) saved successfully';
        } catch (error) {
          row.status = 'Failed';
          row.message = '$error';
        }
        _processed++;
        if (mounted) setState(() {});
      }
    } catch (error) {
      if (mounted) {
        setState(() => _pageError = error.toString());
      }
      _toast('Bulk Image Update stopped: $error');
    } finally {
      if (mounted) setState(() {
        _busy = false;
        _checked = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Matched': return Colors.teal;
      case 'Updated': return Colors.green;
      case 'Uploading':
      case 'Checking': return Colors.blue;
      case 'Failed':
      case 'Invalid':
      case 'Conflict': return Colors.red;
      case 'Not found': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Widget _imagePreview(PlatformFile file) {
    final bytes = file.bytes;
    return Stack(children: [
      Container(
        width: 88,
        height: 100,
        margin: const EdgeInsets.only(right: 9, top: 5),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Expanded(child: bytes == null
              ? const Center(child: Icon(Icons.broken_image_outlined))
              : Image.memory(bytes, width: 88, fit: BoxFit.cover,
                  cacheWidth: 176, cacheHeight: 160,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.broken_image_outlined)))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Text(file.name, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall),
          ),
        ]),
      ),
      if (!_busy)
        Positioned(
          right: 1,
          top: 0,
          child: InkWell(
            onTap: () => _removeImage(file),
            child: Container(
              decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matched = _rows.where((r) => r.isMatched).length;
    final updated = _rows.where((r) => r.status == 'Updated').length;
    final failed = _rows.where((r) => r.status == 'Failed').length;
    final conflicts = _rows.where((r) => r.status == 'Conflict' || r.status == 'Not found').length;

    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Image Update by Item Code')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Upload renamed images — no Excel required',
            style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Rename each image file to its product Item Code, then select '
            'all images together. The app reads each filename, finds one exact '
            'matching product and replaces its existing pictures.'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Filename examples', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              const SelectableText('92223337980.jpg   →   Item Code 92223337980\n'
                  '00123456.png        →   Item Code 00123456\n'
                  '92223337980__2.png  →   2nd photo of 92223337980'),
              const SizedBox(height: 6),
              const Text('For several photos of the SAME product, use __1, __2 ... __5 '
                  'before the extension. For different products, simply rename '
                  'each file as its exact Item Code. Leading zeros are preserved.'),
              const SizedBox(height: 6),
              const Text('JPEG / PNG / WebP only • 10 MB per image • maximum 5 per '
                  'product • 120 MB total • original quality (no compression).'),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: _busy ? null : _chooseImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_filesByName.isEmpty
                ? 'Select Multiple Images' : 'Add More Images'),
          ),
          OutlinedButton.icon(
            onPressed: _busy || _filesByName.isEmpty ? null : _clearImages,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Clear Selection'),
          ),
        ]),
        const SizedBox(height: 12),
        if (_rows.isNotEmpty) Text(
          '${_filesByName.length} image(s) selected for ${_rows.length} Item Code(s)',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: TextField(
            controller: _updatedByController,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Updated By / Staff ID *',
              border: OutlineInputBorder(),
              helperText: 'Required by the existing PUT API',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 8, children: [
          FilledButton.tonalIcon(
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
          Text('Image preview & results', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('${_rows.length} Item Code(s) • $updated updated • $failed failed • '
              '$conflicts missing/conflicting • $_processed processed'),
          const SizedBox(height: 8),
          ..._rows.map((row) => Card(
            key: ValueKey(_key(row.itemCode)),
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 18),
                      SelectableText(row.itemCode, style: theme.textTheme.titleMedium),
                      Text('${row.photos.length} image(s)'),
                      Chip(
                        side: BorderSide(color: _statusColor(row.status)),
                        label: Text(row.status,
                            style: TextStyle(color: _statusColor(row.status))),
                      ),
                    ]),
                const SizedBox(height: 4),
                if (row.message.isNotEmpty) Text(row.message),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [for (final photo in row.photos) _imagePreview(photo)]),
                ),
              ]),
            ),
          )),
          const SizedBox(height: 12),
          const Text('Safety: only a single exact Item Code match is updated. '
              'If a code exists in multiple products / Display Rooms, it is '
              'skipped. Only product images are replaced; Buyer, Display Room '
              'Name, MOQ, FOB, Size Range and 3D Model remain unchanged.'),
          const SizedBox(height: 8),
          const Text('Note: the current PUT API removes old image gallery rows '
              'but does not automatically delete their physical server files. '
              'Refresh the Display Website after successful updates.'),
        ],
      ]),
    );
  }
}
