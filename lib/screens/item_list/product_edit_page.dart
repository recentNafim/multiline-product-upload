import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../models/display_room_item.dart';
import '../../services/display_room_api_service.dart';
import '../../utils/auto_image_file_name.dart';

/// Dedicated edit page for a persisted Display Room product.
/// The NORMAL PUT handler is used; IMAGE_ONLY is reserved for bulk uploads.
class ProductEditPage extends StatefulWidget {
  final DisplayRoomItem product;
  const ProductEditPage({super.key, required this.product});

  @override
  State<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {
  late final TextEditingController name;
  late final TextEditingController business;
  late final TextEditingController category;
  late final TextEditingController buyer;
  late final TextEditingController itemCode;
  late final TextEditingController displayRoom;
  late final TextEditingController sizeRange;
  late final TextEditingController weightText;
  late final TextEditingController moq;
  late final TextEditingController fob;
  late final TextEditingController updatedBy;
  late final TextEditingController material;
  late final TextEditingController cbm;
  final Set<int> removedImages = <int>{};
  final List<PlatformFile> newImages = <PlatformFile>[];
  bool saving = false;

  DisplayRoomItem get item => widget.product;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: item.description);
    business = TextEditingController(text: item.business);
    category = TextEditingController(text: item.productCategory);
    buyer = TextEditingController(text: item.buyer);
    itemCode = TextEditingController(text: item.itemCode);
    displayRoom = TextEditingController(text: item.displayRoomName);
    sizeRange = TextEditingController(text: item.sizeRange);
    weightText = TextEditingController(text: item.weightText);
    moq = TextEditingController(text: item.quantity?.toString() ?? '');
    fob = TextEditingController(text: item.fob?.toString() ?? '');
    updatedBy = TextEditingController(text:
        (item.updatedBy ?? item.createdBy)?.toString() ?? '');
    material = TextEditingController(text: item.materialSpecification);
    cbm = TextEditingController(text: item.cbm);
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      name, business, category, buyer, itemCode, displayRoom, sizeRange,
      weightText, moq, fob, updatedBy, material, cbm,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static String imageMime(PlatformFile f) {
    switch ((f.extension ?? f.name.split('.').last).toLowerCase()) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      default: throw FormatException('Unsupported image: ${f.name}');
    }
  }

  static bool validImage(PlatformFile file) {
    final bytes = file.bytes;
    if (bytes == null || bytes.length < 12 || bytes.length > 10 * 1024 * 1024) {
      return false;
    }
    final suffix = (file.extension ?? file.name.split('.').last).toLowerCase();
    if (suffix == 'jpeg' || suffix == 'jpg') {
      return bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;
    }
    if (suffix == 'png') {
      return bytes[0] == 137 && bytes[1] == 80 && bytes[2] == 78 &&
          bytes[3] == 71 && bytes[4] == 13 && bytes[5] == 10;
    }
    if (suffix == 'webp') {
      return String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    }
    return false;
  }

  int get existingCount => item.imageRecords.where((image) =>
      image.sl == null || !removedImages.contains(image.sl)).length;

  Future<void> chooseImages() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: true,
        withData: true,
      );
      if (picked == null) return;
      if (picked.files.any((file) => !validImage(file))) {
        message('Use valid JPG, PNG or WebP images, up to 10 MB each.');
        return;
      }
      if (existingCount + newImages.length + picked.files.length > 5) {
        message('Maximum 5 images per product. Remove an existing image first.');
        return;
      }
      if (!mounted) return;
      setState(() => newImages.addAll(picked.files));
    } catch (e) {
      message('Could not select images: $e');
    }
  }

  static double? gramsFromText(String text) {
    final match = RegExp(
      r'^([0-9]+(?:\.[0-9]+)?)\s*(KG|KGS|KILOGRAMS?|G|GRAMS?)?$',
      caseSensitive: false,
    ).firstMatch(text.trim().replaceAll(',', ''));
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null || !value.isFinite || value < 0) return null;
    return (match.group(2) ?? 'g').toLowerCase().startsWith('k')
        ? value * 1000 : value;
  }

  Future<void> save() async {
    if (saving) return;
    if (item.masterSl == null || item.sl == null) {
      message('Cannot update: master SL or product detail SL is missing.');
      return;
    }
    final minQty = double.tryParse(moq.text.trim());
    final price = double.tryParse(fob.text.trim());
    final userId = int.tryParse(updatedBy.text.trim());
    final problems = <String>[];
    if (name.text.trim().isEmpty) problems.add('Item Name is required');
    if (business.text.trim().isEmpty) problems.add('Business is required');
    if (business.text.trim().length > 500) problems.add('Business exceeds 500 characters');
    if (buyer.text.trim().length > 500) problems.add('Buyer exceeds 500 characters');
    if (category.text.trim().isEmpty) problems.add('Item Category is required');
    if (minQty == null || minQty <= 0) problems.add('MOQ must be greater than zero');
    if (price == null || price < 0) problems.add('FOB must be non-negative');
    if (userId == null || userId <= 0) problems.add('Updated By (Staff ID) required');
    if (sizeRange.text.trim().length > 500) problems.add('Size Range exceeds 500 characters');
    if (weightText.text.trim().length > 500) problems.add('Weight exceeds 500 characters');
    if (newImages.length + existingCount > 5) problems.add('Maximum 5 images allowed');
    // ITEM_CODE remains read-only because the PUT handler does not update it.
    if (itemCode.text.trim() != item.itemCode) {
      problems.add('Item Code cannot be changed with the current PUT API');
    }
    if (problems.isNotEmpty) {
      message(problems.join(' • '));
      return;
    }

    final newBusiness = business.text.trim();
    final newBuyer = buyer.text.trim();
    final businessChanged = newBusiness != item.business;
    final buyerChanged = newBuyer != item.buyer;
    if (businessChanged) {
      // Business is a MASTER value, not a detail-level product attribute.
      // The change affects every product belonging to this same master SL.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Change Business for this Display Room?'),
          content: Text(
            'Business is shared by every product under Master #${item.masterSl}. '
            'Changing it from "${item.business}" to "$newBusiness" will update '
            'the Business shown for ALL products in this Display Room. '
            'Buyer will be updated only for this product. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Update Business'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => saving = true);
    try {
      final now = DateTime.now();
      final body = <String, dynamic>{
        'mode': 'NORMAL',
        'master_sl': item.masterSl,
        'updated_by': userId,
        'business': newBusiness,
        'sub_category': item.subCategory,
        if (item.organizationId != null) 'organization_id': item.organizationId,
        if (item.displayRoomNo.isNotEmpty) 'display_room_no': item.displayRoomNo,
        'display_room_name': displayRoom.text.trim(),
        'details': [<String, dynamic>{
          'sl': item.sl,
          'item_code': item.itemCode,
          'description': name.text.trim(),
          'product_category': category.text.trim(),
          'buyer': newBuyer,
          'moq': minQty,
          'fob': price,
          'size_range': sizeRange.text.trim(),
          'weight_text': weightText.text.trim(),
          'weight': gramsFromText(weightText.text),
          'material_specification': material.text.trim(),
          'cbm': cbm.text.trim(),
          if (removedImages.isNotEmpty)
            'images_to_delete': [for (final id in removedImages) {'sl': id}],
          if (newImages.isNotEmpty)
            'images_to_add': [for (var index = 0; index < newImages.length; index++)
              <String, dynamic>{
                'file_base64': base64Encode(newImages[index].bytes!),
                'file_name': autoImageFileName(
                  itemCode: item.itemCode,
                  itemName: name.text.trim(),
                  excelSerial: item.sl ?? 1,
                  imageNumber: existingCount + index + 1,
                  image: {
                    'file_name': newImages[index].name,
                    'mime_type': imageMime(newImages[index]),
                  },
                  uploadTime: now,
                ),
                'mime_type': imageMime(newImages[index]),
              },
            ],
        }],
      };
      final response = await DisplayRoomApiService.updateItem(body);
      final data = jsonDecode(response.body);
      final apiStatus = data is Map ? data['status_code']?.toString() : null;
      if (response.statusCode < 200 || response.statusCode >= 300 || apiStatus != '200') {
        final error = data is Map ? data['message'] : response.body;
        throw Exception('HTTP ${response.statusCode}: $error');
      }
      // Older versions of the PUT handler return HTTP/API 200 even when
      // silently ignoring details[].buyer. Re-read the saved product whenever
      // Business or Buyer changed; never report a false save to the user.
      if (buyerChanged || businessChanged) {
        await verifyBusinessAndBuyer(
          expectedBusiness: newBusiness,
          expectedBuyer: newBuyer,
          verifyBusiness: businessChanged,
          verifyBuyer: buyerChanged,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      message('Product update failed: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> verifyBusinessAndBuyer({
    required String expectedBusiness,
    required String expectedBuyer,
    required bool verifyBusiness,
    required bool verifyBuyer,
  }) async {
    final response = await DisplayRoomApiService.getItemsByMasterSl(item.masterSl!);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('PUT completed, but GET verification failed (HTTP '
          '${response.statusCode}). Refresh the product list before retrying.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['status_code']?.toString() != '200' ||
        decoded['data'] is! List) {
      throw StateError('PUT completed, but GET verification could not read '
          'the product. Refresh the product list before retrying.');
    }
    Map<String, dynamic>? master;
    for (final raw in decoded['data'] as List) {
      if (raw is Map && raw['sl']?.toString() == item.masterSl.toString()) {
        master = Map<String, dynamic>.from(raw);
        break;
      }
    }
    if (master == null) {
      throw StateError('Product Master #${item.masterSl} was not returned '
          'after saving. Refresh before retrying.');
    }
    if (verifyBusiness && (master['business']?.toString().trim() ?? '') != expectedBusiness) {
      throw StateError('PUT returned success, but Business was not saved. '
          'Verify the deployed PUT handler.');
    }
    if (verifyBuyer) {
      Map<String, dynamic>? detail;
      final details = master['details'];
      if (details is List) {
        for (final raw in details) {
          if (raw is Map && raw['sl']?.toString() == item.sl.toString()) {
            detail = Map<String, dynamic>.from(raw);
            break;
          }
        }
      }
      if (detail == null) {
        throw StateError('Product #${item.sl} was not returned after saving. '
            'Refresh before retrying.');
      }
      if ((detail['buyer']?.toString().trim() ?? '') != expectedBuyer) {
        throw StateError('PUT returned success, but Buyer was NOT saved. '
            'Deploy the updated PUT handler (BUYER update) before retrying.');
      }
    }
  }

  Widget input(TextEditingController controller, String label,
      {bool numeric = false, bool readOnly = false, String? help, int lines = 1}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLines: lines,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        helperText: help,
        helperMaxLines: 2,
        filled: readOnly,
        border: const OutlineInputBorder(),
      ),
    );
  }

  String imageUrl(DisplayRoomPhoto photo) {
    final value = photo.imageUrl.isNotEmpty ? photo.imageUrl : photo.fileUrl;
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    return '${ApiConstants.imageBase}${value.split('/').last}';
  }

  Widget photoCard(Widget preview, String caption, {VoidCallback? onRemove, bool removed = false}) {
    return SizedBox(
      width: 152,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            SizedBox(height: 104, width: 132, child: ClipRRect(
              borderRadius: BorderRadius.circular(8), child: preview)),
            const SizedBox(height: 5),
            Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11)),
            if (onRemove != null) TextButton.icon(
              onPressed: saving ? null : onRemove,
              icon: Icon(removed ? Icons.undo : Icons.delete_outline, size: 16),
              label: Text(removed ? 'Restore' : 'Remove'),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      input(name, 'Item Name *'),
      input(business, 'Business *',
          help: 'Changing Business updates every product in this Display Room.'),
      input(category, 'Item Category *'),
      input(itemCode, 'Item Code', readOnly: true,
          help: 'Read only: current PUT handler does not update ITEM_CODE'),
      input(buyer, 'Buyer / Client Name',
          help: 'Editable. Saved to this product after the updated PUT API is deployed.'),
      input(displayRoom, 'Display Room Name'),
      input(sizeRange, 'Size Range / Dimensions (Optional)',
          help: 'Free text, e.g. S-M or 210 X 180 X 115CM'),
      input(weightText, 'Weight (Optional)',
          help: 'Free text, e.g. 0.740 kg, Lightweight'),
      input(moq, 'MOQ *', numeric: true),
      input(fob, 'FOB *', numeric: true),
      input(cbm, 'CBM'),
      input(material, 'Material Specification'),
      input(updatedBy, 'Updated By / Staff ID *', numeric: true),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Product'), actions: [
        TextButton.icon(
          onPressed: saving ? null : save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save Changes'),
        ),
        const SizedBox(width: 8),
      ]),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1060),
        child: ListView(padding: const EdgeInsets.all(18), children: [
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.description.isEmpty ? item.itemCode : item.description,
                style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('Master #${item.masterSl} • Product #${item.sl} • ${item.business}'),
              const SizedBox(height: 4),
              const Text('Edit product information without creating a duplicate.'),
            ],
          ))),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Product Information', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 15),
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 640 ? 2 : 1;
                final fieldWidth = (constraints.maxWidth - (columns - 1) * 14) / columns;
                return Wrap(spacing: 14, runSpacing: 15, children: [
                  for (final field in fields) SizedBox(width: fieldWidth, child: field),
                ]);
              }),
            ],
          ))),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Product Images (${existingCount + newImages.length}/5)',
                    style: Theme.of(context).textTheme.titleMedium)),
                OutlinedButton.icon(onPressed: saving ? null : chooseImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add Images')),
              ]),
              const SizedBox(height: 8),
              const Text('Changes are applied after Save. Keep up to five JPG/PNG/WebP images.'),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final photo in item.imageRecords)
                  photoCard(
                    Opacity(opacity: photo.sl != null && removedImages.contains(photo.sl) ? 0.35 : 1,
                      child: imageUrl(photo).isEmpty
                          ? const Icon(Icons.broken_image_outlined)
                          : Image.network(imageUrl(photo), fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))),
                    photo.fileName.isEmpty ? 'Existing image' : photo.fileName,
                    removed: photo.sl != null && removedImages.contains(photo.sl),
                    onRemove: photo.sl == null ? null : () => setState(() {
                      if (removedImages.contains(photo.sl)) {
                        if (existingCount + newImages.length >= 5) {
                          message('Maximum five images. Remove another image first.');
                        } else {
                          removedImages.remove(photo.sl);
                        }
                      } else {
                        removedImages.add(photo.sl!);
                      }
                    }),
                  ),
                for (var index = 0; index < newImages.length; index++)
                  photoCard(
                    Image.memory(newImages[index].bytes!, fit: BoxFit.cover),
                    newImages[index].name,
                    onRemove: () => setState(() => newImages.removeAt(index)),
                  ),
              ]),
            ],
          ))),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: saving ? null : save,
            icon: saving ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Saving...' : 'Save Product Changes')),
          const SizedBox(height: 20),
        ]),
      ))),
    );
  }
}
