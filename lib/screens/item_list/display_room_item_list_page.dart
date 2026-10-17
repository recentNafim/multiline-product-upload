import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/display_room_item.dart';
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

  @override
  void initState() {
    super.initState();
    searchController.addListener(() { if (mounted) setState(() {}); });
    getItems();
  }

  Future<void> getItems() async {
    if (isLoading) return;
    setState(() {isLoading = true; error = null;});
    try {
      final response = await DisplayRoomApiService.getItems();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      final decoded = jsonDecode(response.body);
      final data = decoded is Map ? (decoded['data'] ?? decoded['items']) : decoded;
      final result = <DisplayRoomItem>[];
      if (data is List) {
        for (final raw in data) {
          if (raw is! Map) continue;
          final master = Map<String, dynamic>.from(raw);
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
    if (item.sl == null || item.organizationId == null || item.displayRoomNo.isEmpty) {
      _message('Item SL, Organization ID or Display Room No missing in API response');
      return;
    }
    final code = TextEditingController(text: item.itemCode);
    final description = TextEditingController(text: item.description);
    final size = TextEditingController(text: item.sizeRange);
    final moq = TextEditingController(text: item.quantity?.toString() ?? '');
    final fob = TextEditingController(text: item.fob?.toString() ?? '');
    final category = TextEditingController(text: item.productCategory);
    final updatedBy = TextEditingController(text: (item.updatedBy ?? item.createdBy ?? 0).toString());
    bool busy = false;
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) =>
          AlertDialog(
            title: Text('Edit ${item.itemCode}'),
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
              ],
            ))),
            actions: [
              TextButton(onPressed: busy ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel')),
              FilledButton(onPressed: busy ? null : () async {
                final newMoq = double.tryParse(moq.text.trim());
                final newFob = double.tryParse(fob.text.trim());
                if (code.text.trim().isEmpty || category.text.trim().isEmpty ||
                    size.text.trim().isEmpty || newMoq == null || newMoq <= 0 ||
                    newFob == null || newFob < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Item Code, Category, Size Range, MOQ (>0), FOB (>=0) are required')));
                  return;
                }
                setDialogState(() => busy = true);
                try {
                  final body = <String, dynamic>{
                    'business': item.business,
                    'sub_category': item.subCategory,
                    'organization_id': item.organizationId,
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
                      'file_url': item.fileUrl,
                      'file_name': item.fileName,
                      'mime_type': item.mimeType,
                      'item_code': code.text.trim(),
                      'description': description.text.trim(),
                      'uom': item.uom,
                      'quantity': newMoq,
                      'moq': newMoq,
                      'size_range': size.text.trim(),
                      'unit_price': item.unitPrice,
                      'sub_inventory_code': item.subInventoryCode,
                      'locator_id': item.locatorId,
                      'cbm': item.cbm,
                      'fob': newFob,
                      'material_specification': item.materialSpecification,
                      'weight': item.weight,
                    }],
                  };
                  final response = await DisplayRoomApiService.updateItem(body);
                  final result = jsonDecode(response.body);
                  final status = result is Map ? result['status_code'] : null;
                  if (response.statusCode < 200 || response.statusCode >= 300 ||
                    (status != null && status.toString() != '200')) {
                    throw Exception(result is Map ? result['message'] ?? response.body : response.body);
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

  Widget _field(TextEditingController controller, String label, {bool numeric = false}) =>
    Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(
      controller: controller, keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    ));

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final filtered = items.where((p) => query.isEmpty ||
      [p.itemCode, p.description, p.business, p.productCategory, p.displayRoomName,
       p.sizeRange].any((text) => text.toLowerCase().contains(query))).toList();
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
