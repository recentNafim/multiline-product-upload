import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../models/display_room_item.dart';
import '../../core/constants/api_constants.dart';
import '../../utils/auto_image_file_name.dart';
import '../../services/display_room_api_service.dart';

class DisplayRoomItemListPage extends StatefulWidget {
  const DisplayRoomItemListPage({super.key});
  @override
  State<DisplayRoomItemListPage> createState() => _DisplayRoomItemListPageState();
}

class _DisplayRoomItemListPageState extends State<DisplayRoomItemListPage> {
  final searchController = TextEditingController();
  bool isLoading = false;
  String? error;
  List<DisplayRoomItem> items = [];
  // This report/list page uses the same fixed Category/Sub Category options
  // as the entry page and the separate user dashboard.
  static const List<String> _categoryOptions = <String>[
    'Footwear', 'Bag & Luggage', 'Tent', 'Umbrella', 'Handicraft',
  ];
  static const List<String> _subCategoryOptions = <String>[
    'Export', 'Domestic',
  ];
  String? _selectedCategory;
  String? _selectedSubCategory;

  @override
  void initState() {
    super.initState();
    searchController.addListener(() { if (mounted) setState(() {}); });
    getItems();
  }

  // Only comparisons are normalized; the Oracle BUSINESS and SUB_CATEGORY
  // values are preserved. Historic data sometimes spells Footwear as Footware.
  static String _normalizeFilterValue(String value) {
    final normalized = value.trim().toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (normalized == 'footware') return 'footwear';
    return normalized;
  }

  static bool _matchesFilter(String actual, String? selected) {
    return selected == null || selected.isEmpty ||
        _normalizeFilterValue(actual) == _normalizeFilterValue(selected);
  }

  Future<void> getItems() async {
    if (isLoading) return;
    setState(() { isLoading = true; error = null; });
    try {
      const pageSize = 100;
      final result = <DisplayRoomItem>[];
      final seenMasters = <String>{};
      var page = 1;
      while (true) {
        final response = await DisplayRoomApiService.getItems(page: page, limit: pageSize);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }
        final decoded = jsonDecode(response.body);
        final data = decoded is Map ? (decoded['data'] ?? decoded['items']) : decoded;
        if (data is! List || data.isEmpty) break;
        for (final raw in data) {
          if (raw is! Map) continue;
          final master = Map<String, dynamic>.from(raw);
          final masterKey = master['sl']?.toString();
          if (masterKey != null && !seenMasters.add(masterKey)) continue;
          final details = master['details'];
          if (details is List && details.isNotEmpty) {
            for (final item in details) {
              if (item is Map) {
                result.add(DisplayRoomItem.fromMasterDetail(
                  master, Map<String, dynamic>.from(item)));
              }
            }
          } else if (master.containsKey('item_code')) {
            result.add(DisplayRoomItem.fromMasterDetail(master, master));
          }
        }
        final totalPages = decoded is Map
            ? int.tryParse(decoded['total_pages']?.toString() ?? '')
            : null;
        if (totalPages != null && totalPages >= 0) {
          if (page >= totalPages) break;
        } else if (data.length < pageSize) {
          break;
        }
        page++;
      }
      if (!mounted) return;
      setState(() => items = result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> openEditSheet(DisplayRoomItem item) async {
    // The ORDS GET response may omit display_room_no when it is NULL.
    // Organization is optional in the upload UI.  Neither value should
    // prevent opening the edit dialog: the DETAIL SL identifies this row.
    if (item.sl == null || item.masterSl == null) {
      _message('Cannot edit: Product Detail SL or Master SL is missing from the GET API.');
      return;
    }
    debugPrint('Edit product detail SL=${item.sl}, master SL=${item.masterSl}, '
        'organizationId=${item.organizationId}, '
        'displayRoomNo=${item.displayRoomNo.isEmpty ? "<missing>" : item.displayRoomNo}');
    final code = TextEditingController(text: item.itemCode);
    final description = TextEditingController(text: item.description);
    final size = TextEditingController(text: item.sizeRange);
    final moq = TextEditingController(text: item.quantity?.toString() ?? '');
    final fob = TextEditingController(text: item.fob?.toString() ?? '');
    final category = TextEditingController(text: item.productCategory);
    final updatedBy = TextEditingController(text: (item.updatedBy ?? item.createdBy)?.toString() ?? '');
    bool busy = false;
    // Only explicitly deleted image IDs are sent to Oracle.
    final removedImageIds = <int>{};
    final newImages = <PlatformFile>[];
    int excelSerial = item.sl ?? 1;
    // Preserve the Excel SERIAL in names generated during initial upload.
    final serialMatch = RegExp(
      r'_(\d+)_(\d{2})_(\d{8})_(\d{9})\.(?:jpg|jpeg|png|webp)$',
      caseSensitive: false,
    ).firstMatch(item.fileName);
    if (serialMatch != null) {
      excelSerial = int.tryParse(serialMatch.group(1)!) ?? excelSerial;
    }
    Future<void> imageAction(StateSetter change, {int? replaceSl}) async {
      try {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
          allowMultiple: replaceSl == null,
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        final picked = result.files;
        for (final file in picked) {
          final bytes = file.bytes;
          if (bytes == null || bytes.isEmpty) {
            throw FormatException('Cannot read image: ${file.name}');
          }
          if (bytes.length > 10 * 1024 * 1024) {
            throw FormatException('${file.name}: image must be 10 MB or less');
          }
          if (!_isSupportedImage(bytes, file.extension ?? '')) {
            throw FormatException('${file.name}: only valid JPG/PNG/WebP images supported');
          }
        }
        final nextRemoved = {...removedImageIds};
        if (replaceSl != null) nextRemoved.add(replaceSl);
        final retained = item.imageRecords.where(
          (p) => p.sl == null || !nextRemoved.contains(p.sl),
        ).length;
        if (retained + newImages.length + picked.length > 5) {
          throw const FormatException('Maximum 5 images per product');
        }
        change(() {
          removedImageIds..clear()..addAll(nextRemoved);
          newImages.addAll(picked);
        });
      } catch (e) {
        if (mounted) _message('Image selection failed: $e');
      }
    }
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) =>
          AlertDialog(
            title: Text('Edit ${item.itemCode.isNotEmpty ? item.itemCode : item.description}'),
            content: SizedBox(width: 540, child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(code, 'Item Code'),
                _field(description, 'Item Name / Description'),
                _field(category, 'Item Category'),
                _field(size, 'Size Range'),
                _field(moq, 'MOQ', numeric: true),
                _field(fob, 'FOB', numeric: true),
                _field(updatedBy, 'Updated By', numeric: true),
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerLeft, child: Text(
                  'Product Images (${item.imageRecords.length - removedImageIds.length + newImages.length}/5)',
                  style: Theme.of(context).textTheme.titleMedium,
                )),
                const SizedBox(height: 6),
                ...item.imageRecords.map((photo) {
                  final removed = photo.sl != null && removedImageIds.contains(photo.sl);
                  return Card(child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(children: [
                      SizedBox(width: 72, height: 72,
                        child: _existingImageThumb(photo)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        removed ? 'Removed on Save' : (photo.fileName.isEmpty ? 'Saved image' : photo.fileName),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      )),
                      if (photo.sl != null)
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: removed ? 'Restore image' : 'Remove image',
                            icon: Icon(removed ? Icons.undo : Icons.delete_outline,
                              color: removed ? null : Colors.red),
                            onPressed: busy ? null : () {
                              setDialogState(() {
                                if (removed) {
                                  final nextSize = item.imageRecords.length - removedImageIds.length + newImages.length + 1;
                                  if (nextSize > 5) {
                                    _message('Remove a new photo before restoring (maximum 5)');
                                  } else {
                                    removedImageIds.remove(photo.sl);
                                  }
                                } else {
                                  removedImageIds.add(photo.sl!);
                                }
                              });
                            },
                          ),
                          if (!removed)
                            TextButton(
                              onPressed: busy ? null : () => imageAction(setDialogState, replaceSl: photo.sl),
                              child: const Text('Replace'),
                            ),
                        ])
                      else const Tooltip(message: 'Image SL missing in GET API',
                        child: Icon(Icons.info_outline)),
                    ]),
                  ));
                }),
                ...newImages.asMap().entries.map((entry) => Card(
                  child: Padding(padding: const EdgeInsets.all(8),
                    child: Row(children: [
                      SizedBox(width: 72, height: 72,
                        child: Image.memory(entry.value.bytes!, fit: BoxFit.cover,
                          filterQuality: FilterQuality.high)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('New: ${entry.value.name}', maxLines: 2,
                        overflow: TextOverflow.ellipsis)),
                      IconButton(tooltip: 'Discard new image',
                        onPressed: busy ? null : () => setDialogState(
                          () => newImages.removeAt(entry.key)),
                        icon: const Icon(Icons.close)),
                    ]),
                  ),
                )),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => imageAction(setDialogState),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add Original Photos'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Keep up to 5 images. Remove/replace only takes effect after Save. '
                    'Original image bytes are uploaded without resizing.'),
                ),
              ],
            ))),
            actions: [
              TextButton(onPressed: busy ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel')),
              FilledButton(onPressed: busy ? null : () async {
                final newMoq = double.tryParse(moq.text.trim());
                final newFob = double.tryParse(fob.text.trim());
                final errors = <String>[];
                // ITEM CODE is optional per the current client requirement.
                if (description.text.trim().isEmpty) {
                  errors.add('Item Name / Description is required');
                }
                if (category.text.trim().isEmpty) {
                  errors.add('Item Category is required');
                }
                final normalizedSize = size.text.trim().replaceAll(
                  RegExp(r'\s*-\s*'), '-',
                );
                final match = RegExp(r'^(\d+(?:\.\d+)?)-(\d+(?:\.\d+)?)$')
                    .firstMatch(normalizedSize);
                if (match == null ||
                    double.parse(match.group(1)!) > double.parse(match.group(2)!)) {
                  errors.add('Size Range must be like 36-42');
                }
                if (newMoq == null || newMoq <= 0) {
                  errors.add('MOQ must be greater than 0');
                }
                if (newFob == null || newFob < 0) {
                  errors.add('FOB must be 0 or greater');
                }
                if (item.imageRecords.isNotEmpty &&
                    item.imageRecords.length - removedImageIds.length + newImages.length < 1) {
                  errors.add('At least one product image is required');
                }
                if (item.masterSl == null) errors.add('Master SL is missing');
                if ((int.tryParse(updatedBy.text.trim()) ?? 0) <= 0) {
                  errors.add('Updated By (Staff ID) is required');
                }
                if (errors.isNotEmpty) {
                  await showDialog<void>(
                    context: dialogContext,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Please correct these fields'),
                      content: Text(errors.join('\n')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                  return;
                }
                setDialogState(() => busy = true);
                try {
                  final body = <String, dynamic>{
                    'business': item.business,
                    'sub_category': item.subCategory,
                    'master_sl': item.masterSl,
                    if (item.organizationId != null)
                      'organization_id': item.organizationId,
                    // The GET handler can omit display_room_no entirely.
                    // Do not invent a value or block editing when it is missing.
                    if (item.displayRoomNo.trim().isNotEmpty)
                      'display_room_no': item.displayRoomNo,
                    'display_room_name': item.displayRoomName,
                    'updated_by': int.tryParse(updatedBy.text) ?? 0,
                    'status': item.status,
                    'assignee': item.assignee,
                    'details': [<String, dynamic>{
                      'sl': item.sl,
                      'source_sl': item.sourceSl,
                      'product_category': category.text.trim(),
                      'print': item.printValue,
                      'item_qrcode': item.itemQrCode,
                      'item_code': code.text.trim(),
                      'description': description.text.trim(),
                      'uom': item.uom,
                      // Stock quantity is NOT MOQ. Do not overwrite stock.
                      'moq': newMoq,
                      'size_range': normalizedSize,
                      'unit_price': item.unitPrice,
                      'sub_inventory_code': item.subInventoryCode,
                      'locator_id': item.locatorId,
                      'cbm': item.cbm,
                      'fob': newFob,
                      'material_specification': item.materialSpecification,
                      'weight': item.weight,
                      if (removedImageIds.isNotEmpty)
                        'images_to_delete': [
                          for (final sl in removedImageIds) {'sl': sl},
                        ],
                      if (newImages.isNotEmpty) 'images_to_add': [
                        for (var idx = 0; idx < newImages.length; idx++)
                          <String, dynamic>{
                            'file_base64': base64Encode(newImages[idx].bytes!),
                            'file_name': autoImageFileName(
                              itemCode: code.text.trim(),
                              itemName: description.text.trim(),
                              excelSerial: excelSerial,
                              imageNumber: item.imageRecords.length -
                                  removedImageIds.length + idx + 1,
                              image: {
                                'file_name': newImages[idx].name,
                                'mime_type': _mimeFromExtension(newImages[idx].extension ?? ''),
                              },
                              uploadTime: DateTime.now(),
                            ),
                            'mime_type': _mimeFromExtension(newImages[idx].extension ?? ''),
                          },
                      ],
                    }],
                  };
                  final response = await DisplayRoomApiService.updateItem(body);
                  final responseJson = jsonDecode(response.body);
                  final status = responseJson is Map
                      ? responseJson['status_code'] : null;
                  // ORDS may respond HTTP 200 while PL/SQL returns status_code=500.
                  if (response.statusCode < 200 || response.statusCode >= 300 ||
                      (status != null && status.toString() != '200')) {
                    final apiMessage = responseJson is Map
                        ? (responseJson['message'] ?? responseJson['error_message'] ?? response.body)
                        : response.body;
                    throw Exception('HTTP ${response.statusCode}, API status '
                        '${status ?? "unknown"}: $apiMessage');
                  }
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
                    setDialogState(() => busy = false);
                  }
                }
              }, child: Text(busy ? 'Saving...' : 'Save')),
            ],
          )),
      );
      if (result == true) {
        _message('Item updated');
        await getItems();
      }
    } finally {
      // Wait for the dialog exit animation before disposing controllers.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      code.dispose(); description.dispose(); size.dispose(); moq.dispose();
      fob.dispose(); category.dispose(); updatedBy.dispose();
    }
  }

  static String _mimeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        throw FormatException('Unsupported image type .$extension');
    }
  }

  static bool _isSupportedImage(Uint8List bytes, String extension) {
    if (bytes.length < 12) return false;
    final ext = extension.toLowerCase();
    if (ext == 'jpg' || ext == 'jpeg') {
      return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    }
    if (ext == 'png') {
      const header = [137, 80, 78, 71, 13, 10, 26, 10];
      for (var i = 0; i < header.length; i++) {
        if (bytes[i] != header[i]) return false;
      }
      return true;
    }
    if (ext == 'webp') {
      return String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    }
    return false;
  }

  Widget _existingImageThumb(DisplayRoomPhoto photo) {
    var url = photo.imageUrl.trim();
    if (url.isEmpty) url = photo.fileUrl.trim();
    if (url.isNotEmpty && !url.startsWith('http')) {
      url = '${ApiConstants.imageBase}${url.split('/').last}';
    }
    if (url.isEmpty) return const Icon(Icons.broken_image_outlined);
    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          child: SizedBox(
            width: 780, height: 600,
            child: Stack(children: [
              InteractiveViewer(minScale: 0.5, maxScale: 5,
                child: Center(child: Image.network(url, fit: BoxFit.contain,
                  filterQuality: FilterQuality.high))),
              Positioned(right: 4, top: 4, child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(),
              )),
            ]),
          ),
        ),
      ),
      child: Image.network(url, width: 72, height: 72,
        fit: BoxFit.cover, filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
    );
  }

  Widget _field(TextEditingController controller, String label, {bool numeric = false}) =>
    Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(
      controller: controller, keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    ));

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final filtered = items.where((p) {
      final matchesSearch = query.isEmpty ||
        [p.itemCode, p.description, p.business, p.productCategory,
         p.subCategory, p.displayRoomName, p.sizeRange]
          .any((text) => text.toLowerCase().contains(query));
      // Match the existing master BUSINESS and SUB_CATEGORY response fields.
      final matchesCategory = _matchesFilter(p.business, _selectedCategory);
      final matchesSubCategory = _matchesFilter(p.subCategory, _selectedSubCategory);
      return matchesSearch && matchesCategory && matchesSubCategory;
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Display Room Items'), actions: [
        IconButton(tooltip: 'Delete Items', icon: const Icon(Icons.delete_outline),
          onPressed: () => Navigator.pushNamed(context, '/delete')),
        IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh),
          onPressed: isLoading ? null : getItems),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(
          controller: searchController,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
            hintText: 'Search item code, category, size range...'),
        )),
        // Fixed dropdowns on the Items/Report page, without database lookups.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 245,
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String>('report-category-${_selectedCategory ?? 'all'}'),
                  value: _selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  hint: const Text('All Categories'),
                  items: _categoryOptions.map((choice) => DropdownMenuItem<String>(
                    value: choice,
                    child: Text(choice, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedCategory = value),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String>('report-subcategory-${_selectedSubCategory ?? 'all'}'),
                  value: _selectedSubCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sub Category',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  hint: const Text('All Sub Categories'),
                  items: _subCategoryOptions.map((choice) => DropdownMenuItem<String>(
                    value: choice,
                    child: Text(choice, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedSubCategory = value),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear Filters'),
                onPressed: () => setState(() {
                  _selectedCategory = null;
                  _selectedSubCategory = null;
                  searchController.clear();
                }),
              ),
            ],
          ),
        ),
        if (isLoading) const LinearProgressIndicator(),
        if (error != null) Padding(padding: const EdgeInsets.all(12),
          child: Text(error!, style: const TextStyle(color: Colors.red))),
        Expanded(child: filtered.isEmpty && !isLoading
          ? const Center(child: Text('No products found'))
          : ListView.builder(itemCount: filtered.length, itemBuilder: (context, index) {
            final p = filtered[index];
            return Card(margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(p.description.isEmpty ? p.itemCode : p.description),
                subtitle: Text('${p.itemCode}  •  ${p.business}  •  ${p.productCategory}\n'
                  'Size Range: ${p.sizeRange.isEmpty ? '-' : p.sizeRange}  •  '
                  'MOQ: ${p.quantity ?? 0}  •  FOB: ${p.fob ?? 0}'),
                isThreeLine: true,
                trailing: IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined),
                  onPressed: () => openEditSheet(p)),
              ),
            );
          })),
      ]),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
