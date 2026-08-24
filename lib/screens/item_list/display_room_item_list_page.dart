import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../models/display_room_item.dart';
import '../../services/display_room_api_service.dart';

class DisplayRoomItemListPage extends StatefulWidget {
  const DisplayRoomItemListPage({super.key});

  @override
  State<DisplayRoomItemListPage> createState() =>
      _DisplayRoomItemListPageState();
}

class _DisplayRoomItemListPageState extends State<DisplayRoomItemListPage> {
  static const String listApiUrl = ApiConstants.listItems;
  static const String updateApiUrl = ApiConstants.updateItem;

  final searchController = TextEditingController();

  bool isLoading = false;
  List<DisplayRoomItem> items = [];
  List<DisplayRoomItem> filteredItems = [];

  @override
  void initState() {
    super.initState();
    searchController.addListener(_filterItems);
    getItems();
  }

  Future<void> getItems() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await DisplayRoomApiService.getItems();

      debugPrint('GET STATUS: ${response.statusCode}');
      debugPrint('GET RESPONSE: ${response.body}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final data = _extractList(decoded);

      final loadedItems = data
          .whereType<Map>()
          .map(
            (e) => DisplayRoomItem.fromJson(
          Map<String, dynamic>.from(e),
        ),
      )
          .toList();

      if (!mounted) return;

      setState(() {
        items = loadedItems;
        filteredItems = loadedItems;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage('Item load failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) return decoded;

    if (decoded is Map) {
      const possibleKeys = [
        'items',
        'ITEMS',
        'data',
        'DATA',
        'details',
        'DETAILS',
        'item_list',
        'ITEM_LIST',
      ];

      for (final key in possibleKeys) {
        if (decoded[key] is List) {
          return List<dynamic>.from(decoded[key]);
        }
      }
    }

    return [];
  }

  void _filterItems() {
    final query = searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        filteredItems = items;
      });
      return;
    }

    setState(() {
      filteredItems = items.where((item) {
        return item.itemCode.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query) ||
            item.productCategory.toLowerCase().contains(query) ||
            item.subInventoryCode.toLowerCase().contains(query) ||
            item.displayRoomName.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> openEditSheet(DisplayRoomItem item) async {
    if (item.sl == null) {
      _showMessage(
        'এই item-এর DETAILS.SL পাওয়া যায়নি। GET API-তে SL return করতে হবে।',
        isError: true,
      );
      return;
    }

    final updatedByController = TextEditingController(
      text: (item.updatedBy ?? item.createdBy)?.toString() ?? '',
    );
    final sourceSlController = TextEditingController(text: item.sourceSl);
    final productCategoryController =
    TextEditingController(text: item.productCategory);
    final printController = TextEditingController(text: item.printValue);
    final qrController = TextEditingController(text: item.itemQrCode);
    final itemCodeController = TextEditingController(text: item.itemCode);
    final descriptionController = TextEditingController(text: item.description);
    final uomController = TextEditingController(text: item.uom);
    final quantityController =
    TextEditingController(text: item.quantity?.toString() ?? '');
    final unitPriceController =
    TextEditingController(text: item.unitPrice?.toString() ?? '');
    final subInventoryController =
    TextEditingController(text: item.subInventoryCode);
    final locatorController =
    TextEditingController(text: item.locatorId?.toString() ?? '');
    final cbmController = TextEditingController(text: item.cbm);
    final fobController =
    TextEditingController(text: item.fob?.toString() ?? '');
    final weightController =
    TextEditingController(text: item.weight?.toString() ?? '');
    final specificationController =
    TextEditingController(text: item.materialSpecification);
    final fileUrlController = TextEditingController(text: item.fileUrl);
    final fileNameController = TextEditingController(text: item.fileName);
    final mimeController = TextEditingController(text: item.mimeType);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 960),
      builder: (sheetContext) {
        bool updating = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * .88,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Edit Item',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                item.itemCode,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: updating
                              ? null
                              : () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _editField(
                              label: 'Updated By',
                              controller: updatedByController,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 14),
                            _twoEditFields(
                              _editField(
                                label: 'Source SL',
                                controller: sourceSlController,
                              ),
                              _editField(
                                label: 'Product Category',
                                controller: productCategoryController,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _twoEditFields(
                              _editField(
                                label: 'Print',
                                controller: printController,
                              ),
                              _editField(
                                label: 'Item QR Code',
                                controller: qrController,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _editField(
                              label: 'Item Code',
                              controller: itemCodeController,
                            ),
                            const SizedBox(height: 14),
                            _editField(
                              label: 'Description',
                              controller: descriptionController,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 14),
                            _twoEditFields(
                              _editField(
                                label: 'UOM',
                                controller: uomController,
                              ),
                              _editField(
                                label: 'Quantity',
                                controller: quantityController,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _twoEditFields(
                              _editField(
                                label: 'Unit Price',
                                controller: unitPriceController,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                              _editField(
                                label: 'FOB',
                                controller: fobController,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _editField(
                              label: 'Sub Inventory Code',
                              controller: subInventoryController,
                            ),
                            const SizedBox(height: 14),
                            _twoEditFields(
                              _editField(
                                label: 'Locator ID',
                                controller: locatorController,
                                keyboardType: TextInputType.number,
                              ),
                              _editField(
                                label: 'CBM',
                                controller: cbmController,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _editField(
                              label: 'Material Specification',
                              controller: specificationController,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 14),
                            _twoEditFields(
                              _editField(
                                label: 'Weight',
                                controller: weightController,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                              _editField(
                                label: 'MIME Type',
                                controller: mimeController,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _twoEditFields(
                              _editField(
                                label: 'File Name',
                                controller: fileNameController,
                              ),
                              _editField(
                                label: 'File URL',
                                controller: fileUrlController,
                              ),
                            ),
                            const SizedBox(height: 25),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: updating
                            ? null
                            : () async {
                          final updatedBy = int.tryParse(
                            updatedByController.text.trim(),
                          );

                          if (updatedBy == null) {
                            _showMessage(
                              'Valid Updated By দিন',
                              isError: true,
                            );
                            return;
                          }

                          setSheetState(() {
                            updating = true;
                          });

                          final success = await updateItem(
                            item: item,
                            updatedBy: updatedBy,
                            sourceSl: sourceSlController.text,
                            productCategory:
                            productCategoryController.text,
                            printValue: printController.text,
                            qrCode: qrController.text,
                            itemCode: itemCodeController.text,
                            description: descriptionController.text,
                            uom: uomController.text,
                            quantity: quantityController.text,
                            unitPrice: unitPriceController.text,
                            subInventory: subInventoryController.text,
                            locatorId: locatorController.text,
                            cbm: cbmController.text,
                            fob: fobController.text,
                            weight: weightController.text,
                            specification:
                            specificationController.text,
                            fileUrl: fileUrlController.text,
                            fileName: fileNameController.text,
                            mimeType: mimeController.text,
                          );

                          if (!sheetContext.mounted) return;

                          if (success) {
                            Navigator.pop(sheetContext);
                            await getItems();
                          } else {
                            setSheetState(() {
                              updating = false;
                            });
                          }
                        },
                        icon: updating
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          updating ? 'Updating...' : 'Update Item',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    updatedByController.dispose();
    sourceSlController.dispose();
    productCategoryController.dispose();
    printController.dispose();
    qrController.dispose();
    itemCodeController.dispose();
    descriptionController.dispose();
    uomController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
    subInventoryController.dispose();
    locatorController.dispose();
    cbmController.dispose();
    fobController.dispose();
    weightController.dispose();
    specificationController.dispose();
    fileUrlController.dispose();
    fileNameController.dispose();
    mimeController.dispose();
  }

  Future<bool> updateItem({
    required DisplayRoomItem item,
    required int updatedBy,
    required String sourceSl,
    required String productCategory,
    required String printValue,
    required String qrCode,
    required String itemCode,
    required String description,
    required String uom,
    required String quantity,
    required String unitPrice,
    required String subInventory,
    required String locatorId,
    required String cbm,
    required String fob,
    required String weight,
    required String specification,
    required String fileUrl,
    required String fileName,
    required String mimeType,
  }) async {
    if (item.organizationId == null || item.displayRoomNo.trim().isEmpty) {
      _showMessage(
        'GET API-তে ORGANIZATION_ID এবং DISPLAY_ROOM_NO return করতে হবে।',
        isError: true,
      );
      return false;
    }

    final body = {
      'business': item.business,
      'sub_category': item.subCategory,
      'organization_id': item.organizationId,
      'display_room_no': item.displayRoomNo,
      'display_room_name': item.displayRoomName,
      'updated_by': updatedBy,
      'status': item.status,
      'assignee': item.assignee,
      'details': [
        {
          'sl': item.sl,
          'source_sl': sourceSl.trim(),
          'product_category': productCategory.trim(),
          'print': printValue.trim(),
          'item_qrcode': qrCode.trim(),
          'file_url': fileUrl.trim(),
          'file_name': fileName.trim(),
          'mime_type': mimeType.trim(),
          'item_code': itemCode.trim(),
          'description': description.trim(),
          'uom': uom.trim(),
          'quantity': double.tryParse(quantity.trim()),
          'unit_price': double.tryParse(unitPrice.trim()),
          'sub_inventory_code': subInventory.trim(),
          'locator_id': int.tryParse(locatorId.trim()),
          'cbm': cbm.trim(),
          'fob': double.tryParse(fob.trim()),
          'material_specification': specification.trim(),
          'weight': double.tryParse(weight.trim()),
        }
      ],
    };

    try {
      debugPrint(
        const JsonEncoder.withIndent('  ').convert(body),
      );

      final response = await DisplayRoomApiService.updateItem(body);

      debugPrint('PUT STATUS: ${response.statusCode}');
      debugPrint('PUT RESPONSE: ${response.body}');

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      final apiStatus = decoded is Map ? decoded['status_code'] : null;
      final message = decoded is Map
          ? decoded['message']?.toString() ?? ''
          : response.body;

      final success = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (apiStatus == null ||
              apiStatus == 200 ||
              apiStatus.toString() == '200');

      if (mounted) {
        _showMessage(
          message.isEmpty
              ? (success ? 'Updated successfully.' : 'Update failed.')
              : message,
          isError: !success,
        );
      }

      return success;
    } catch (e) {
      if (mounted) {
        _showMessage('Update failed: $e', isError: true);
      }
      return false;
    }
  }

  Widget _editField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _twoEditFields(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 550) {
          return Column(
            children: [
              first,
              const SizedBox(height: 14),
              second,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 14),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.red : Colors.green,
        content: Text(message),
      ),
    );
  }

  Widget _buildItemCard(DisplayRoomItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openEditSheet(item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemCode.isEmpty ? 'No Item Code' : item.itemCode,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _smallChip(item.productCategory),
                        _smallChip(item.uom),
                        _smallChip('Qty: ${item.quantity ?? 0}'),
                        _smallChip(item.subInventoryCode),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.edit_outlined),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallChip(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Display Room Items'),
        actions: [
          IconButton(
            tooltip: 'Delete Items',
            onPressed: () {
              Navigator.pushNamed(context, '/delete');
            },
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading ? null : getItems,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search item code, name, category...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                      onPressed: searchController.clear,
                      icon: const Icon(Icons.close),
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (!isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${filteredItems.length} item(s)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredItems.isEmpty
                    ? const Center(child: Text('No items found.'))
                    : RefreshIndicator(
                  onRefresh: getItems,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      return _buildItemCard(filteredItems[index]);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.removeListener(_filterItems);
    searchController.dispose();
    super.dispose();
  }
}
