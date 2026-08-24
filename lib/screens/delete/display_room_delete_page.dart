import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../models/delete_models.dart';
import '../../services/display_room_api_service.dart';

class DisplayRoomDeletePage extends StatefulWidget {
  const DisplayRoomDeletePage({super.key});

  @override
  State<DisplayRoomDeletePage> createState() =>
      _DisplayRoomDeletePageState();
}

class _DisplayRoomDeletePageState extends State<DisplayRoomDeletePage> {
  static const String apiUrl = ApiConstants.deleteItem;
  static const String imageBaseUrl = ApiConstants.imageBase;

  final TextEditingController searchController =
  TextEditingController();

  bool isLoading = false;
  String? deletingKey;

  List<DeleteProductRow> products = [];
  List<DeleteProductRow> filteredProducts = [];

  List<DeleteMasterRow> masters = [];

  @override
  void initState() {
    super.initState();
    searchController.addListener(_applyFilter);
    _loadDeleteData();
  }

  // ==========================================================================
  // LOAD GET DATA
  // ==========================================================================

  Future<void> _loadDeleteData() async {
    if (isLoading) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await DisplayRoomApiService.getDeleteData();

      debugPrint('==========================================');
      debugPrint('DELETE PAGE GET');
      debugPrint('URL => $apiUrl');
      debugPrint('STATUS => ${response.statusCode}');
      debugPrint('==========================================');

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.body}',
        );
      }

      final dynamic decoded =
      jsonDecode(response.body);

      final parsed =
      _parseDeleteResponse(decoded);

      if (!mounted) {
        return;
      }

      setState(() {
        products = parsed.products;
        masters = parsed.masters;
      });

      _applyFilter();
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Delete page data load failed: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ==========================================================================
  // PARSE API RESPONSE
  //
  // Supports the current nested response:
  //
  // data: [
  //   {
  //     sl: MASTER_SL,
  //     ...
  //     details: [
  //       {
  //         sl: DETAIL_SL,
  //         ...
  //         images: [...]
  //       }
  //     ]
  //   }
  // ]
  //
  // Also supports a flat list for backward compatibility.
  // ==========================================================================

  DeleteParsedData _parseDeleteResponse(
      dynamic decoded,
      ) {
    final List<DeleteProductRow> productRows = [];
    final List<DeleteMasterRow> masterRows = [];

    List<dynamic> rootList = [];

    if (decoded is List) {
      rootList = decoded;
    } else if (decoded is Map) {
      const possibleKeys = [
        'data',
        'DATA',
        'items',
        'ITEMS',
        'item_list',
        'ITEM_LIST',
      ];

      for (final key in possibleKeys) {
        if (decoded[key] is List) {
          rootList =
          List<dynamic>.from(decoded[key]);
          break;
        }
      }
    }

    for (final dynamic raw in rootList) {
      if (raw is! Map) {
        continue;
      }

      final Map<String, dynamic> master =
      Map<String, dynamic>.from(raw);

      final dynamic detailsRaw =
          master['details'] ??
              master['DETAILS'];

      // ----------------------------------------------------------------------
      // NESTED MASTER + DETAILS RESPONSE
      // ----------------------------------------------------------------------
      if (detailsRaw is List) {
        final int? masterSl = deleteAsInt(
          master['sl'] ??
              master['SL'] ??
              master['master_sl'] ??
              master['MASTER_SL'],
        );

        final String business =
        deleteAsText(
          master['business'] ??
              master['BUSINESS'],
        );

        final String subCategory =
        deleteAsText(
          master['sub_category'] ??
              master['SUB_CATEGORY'],
        );

        final String displayRoomNo =
        deleteAsText(
          master['display_room_no'] ??
              master['DISPLAY_ROOM_NO'],
        );

        final String displayRoomName =
        deleteAsText(
          master['display_room_name'] ??
              master['DISPLAY_ROOM_NAME'],
        );

        final String organizationCode =
        deleteAsText(
          master['organization_code'] ??
              master['ORGANIZATION_CODE'],
        );

        final int? organizationId =
        deleteAsInt(
          master['organization_id'] ??
              master['ORGANIZATION_ID'],
        );

        final String status =
        deleteAsText(
          master['status'] ??
              master['STATUS'],
        );

        masterRows.add(
          DeleteMasterRow(
            masterSl: masterSl,
            business: business,
            subCategory: subCategory,
            displayRoomNo: displayRoomNo,
            displayRoomName: displayRoomName,
            organizationCode:
            organizationCode,
            organizationId:
            organizationId,
            status: status,
            detailsCount:
            detailsRaw.length,
          ),
        );

        for (final dynamic detailRaw
        in detailsRaw) {
          if (detailRaw is! Map) {
            continue;
          }

          final Map<String, dynamic> detail =
          Map<String, dynamic>.from(
            detailRaw,
          );

          productRows.add(
            DeleteProductRow(
              detailSl: deleteAsInt(
                detail['sl'] ??
                    detail['SL'] ??
                    detail['detail_sl'] ??
                    detail['DETAIL_SL'],
              ),
              masterSl: deleteAsInt(
                detail['m_sl'] ??
                    detail['M_SL'] ??
                    detail['master_sl'] ??
                    detail['MASTER_SL'],
              ) ??
                  masterSl,
              itemCode: deleteAsText(
                detail['item_code'] ??
                    detail['ITEM_CODE'],
              ),
              description: deleteAsText(
                detail['description'] ??
                    detail['DESCRIPTION'],
              ),
              productCategory: deleteAsText(
                detail['product_category'] ??
                    detail['PRODUCT_CATEGORY'],
              ),
              business: deleteAsText(
                detail['business'] ??
                    detail['BUSINESS'],
              ).isNotEmpty
                  ? deleteAsText(
                detail['business'] ??
                    detail['BUSINESS'],
              )
                  : business,
              subCategory: deleteAsText(
                detail['sub_category'] ??
                    detail['SUB_CATEGORY'],
              ).isNotEmpty
                  ? deleteAsText(
                detail['sub_category'] ??
                    detail['SUB_CATEGORY'],
              )
                  : subCategory,
              displayRoomNo: deleteAsText(
                detail['display_room_no'] ??
                    detail['DISPLAY_ROOM_NO'],
              ).isNotEmpty
                  ? deleteAsText(
                detail['display_room_no'] ??
                    detail['DISPLAY_ROOM_NO'],
              )
                  : displayRoomNo,
              displayRoomName: deleteAsText(
                detail['display_room_name'] ??
                    detail['DISPLAY_ROOM_NAME'],
              ).isNotEmpty
                  ? deleteAsText(
                detail['display_room_name'] ??
                    detail['DISPLAY_ROOM_NAME'],
              )
                  : displayRoomName,
              imageUrl:
              _firstImageUrl(detail),
            ),
          );
        }

        continue;
      }

      // ----------------------------------------------------------------------
      // FLAT DETAIL RESPONSE FALLBACK
      // ----------------------------------------------------------------------
      final int? detailSl = deleteAsInt(
        master['sl'] ??
            master['SL'] ??
            master['detail_sl'] ??
            master['DETAIL_SL'],
      );

      final int? masterSl = deleteAsInt(
        master['m_sl'] ??
            master['M_SL'] ??
            master['master_sl'] ??
            master['MASTER_SL'],
      );

      productRows.add(
        DeleteProductRow(
          detailSl: detailSl,
          masterSl: masterSl,
          itemCode: deleteAsText(
            master['item_code'] ??
                master['ITEM_CODE'],
          ),
          description: deleteAsText(
            master['description'] ??
                master['DESCRIPTION'],
          ),
          productCategory: deleteAsText(
            master['product_category'] ??
                master['PRODUCT_CATEGORY'],
          ),
          business: deleteAsText(
            master['business'] ??
                master['BUSINESS'],
          ),
          subCategory: deleteAsText(
            master['sub_category'] ??
                master['SUB_CATEGORY'],
          ),
          displayRoomNo: deleteAsText(
            master['display_room_no'] ??
                master['DISPLAY_ROOM_NO'],
          ),
          displayRoomName: deleteAsText(
            master['display_room_name'] ??
                master['DISPLAY_ROOM_NAME'],
          ),
          imageUrl:
          _firstImageUrl(master),
        ),
      );
    }

    // ------------------------------------------------------------------------
    // If flat response had no master list, derive masters from product rows.
    // ------------------------------------------------------------------------
    if (masterRows.isEmpty) {
      final Map<int, List<DeleteProductRow>>
      grouped = {};

      for (final item in productRows) {
        if (item.masterSl == null) {
          continue;
        }

        grouped
            .putIfAbsent(
          item.masterSl!,
              () => [],
        )
            .add(item);
      }

      for (final entry in grouped.entries) {
        final first =
            entry.value.first;

        masterRows.add(
          DeleteMasterRow(
            masterSl: entry.key,
            business: first.business,
            subCategory:
            first.subCategory,
            displayRoomNo:
            first.displayRoomNo,
            displayRoomName:
            first.displayRoomName,
            organizationCode: '',
            organizationId: null,
            status: '',
            detailsCount:
            entry.value.length,
          ),
        );
      }
    }

    return DeleteParsedData(
      products: productRows,
      masters: masterRows,
    );
  }

  // ==========================================================================
  // IMAGE URL
  // ==========================================================================

  String _firstImageUrl(
      Map<String, dynamic> data,
      ) {
    String normalize(dynamic value) {
      if (value == null) {
        return '';
      }

      String url =
      value.toString().trim();

      if (url.isEmpty ||
          url.toLowerCase() == 'null') {
        return '';
      }

      if (url.startsWith('http://') ||
          url.startsWith('https://')) {
        return url;
      }

      while (url.startsWith('/')) {
        url = url.substring(1);
      }

      if (url.isEmpty) {
        return '';
      }

      return '$imageBaseUrl'
          '${Uri.encodeComponent(url)}';
    }

    String url = normalize(
      data['image_url'] ??
          data['IMAGE_URL'],
    );

    if (url.isNotEmpty) {
      return url;
    }

    url = normalize(
      data['file_url'] ??
          data['FILE_URL'],
    );

    if (url.isNotEmpty) {
      return url;
    }

    final dynamic images =
        data['images'] ??
            data['IMAGES'];

    if (images is List) {
      for (final dynamic image
      in images) {
        if (image is! Map) {
          continue;
        }

        url = normalize(
          image['image_url'] ??
              image['IMAGE_URL'] ??
              image['file_url'] ??
              image['FILE_URL'],
        );

        if (url.isNotEmpty) {
          return url;
        }
      }
    }

    return '';
  }

  // ==========================================================================
  // FILTER
  // ==========================================================================

  void _applyFilter() {
    if (!mounted) {
      return;
    }

    final String query = searchController.text.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        filteredProducts = List<DeleteProductRow>.from(products);
        return;
      }

      filteredProducts = products.where((item) {
        return item.itemCode.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query) ||
            item.productCategory.toLowerCase().contains(query) ||
            item.business.toLowerCase().contains(query) ||
            item.subCategory.toLowerCase().contains(query) ||
            item.displayRoomNo.toLowerCase().contains(query) ||
            item.displayRoomName.toLowerCase().contains(query) ||
            (item.detailSl?.toString().contains(query) ?? false) ||
            (item.masterSl?.toString().contains(query) ?? false);
      }).toList();
    });
  }

  // ==========================================================================
  // SINGLE DELETE FLOW
  // ==========================================================================

  DeleteMasterRow? _findMasterBySl(int? masterSl) {
    if (masterSl == null) {
      return null;
    }

    for (final master in masters) {
      if (master.masterSl == masterSl) {
        return master;
      }
    }

    return null;
  }

  bool _isLastProductOfMaster(DeleteProductRow item) {
    final masterSl = item.masterSl;

    if (masterSl == null) {
      return false;
    }

    final count = products
        .where((product) => product.masterSl == masterSl)
        .length;

    return count <= 1;
  }

  Future<void> _confirmDeleteProduct(
      DeleteProductRow item,
      ) async {
    if (item.detailSl == null) {
      _showMessage(
        'এই item-এর DETAILS.SL পাওয়া যায়নি। Delete করা যাবে না।',
        isError: true,
      );
      return;
    }

    final bool deleteWholeMaster =
        _isLastProductOfMaster(item) &&
            _findMasterBySl(item.masterSl) != null;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.redAccent,
            size: 34,
          ),
          title: const Text('Delete Item?'),
          content: Text(
            'Item Code: ${item.itemCode.isEmpty ? '-' : item.itemCode}\n'
                'Description: ${item.description.isEmpty ? '-' : item.description}\n\n'
                '${deleteWholeMaster
                ? 'এটি এই Display Room-এর শেষ product। Delete করলে product, images এবং empty master record-ও automatically delete হবে.'
                : 'এই product এবং এর uploaded images permanently delete হবে.'}',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              icon: const Icon(
                Icons.delete_forever_outlined,
              ),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (deleteWholeMaster) {
      final master = _findMasterBySl(item.masterSl);

      if (master != null) {
        await _deleteMaster(master);
        return;
      }
    }

    await _deleteProduct(item);
  }

  Future<void> _deleteProduct(
      DeleteProductRow item,
      ) async {
    final int detailSl =
    item.detailSl!;

    final String key =
        'detail_$detailSl';

    if (deletingKey != null) {
      return;
    }

    setState(() {
      deletingKey = key;
    });

    try {
      final Uri uri =
      Uri.parse(apiUrl).replace(
        queryParameters: {
          'p_detail_sl':
          detailSl.toString(),
        },
      );

      debugPrint('==========================================');
      debugPrint('DELETE PRODUCT');
      debugPrint('URL => $uri');
      debugPrint('DETAIL SL => $detailSl');
      debugPrint('==========================================');

      final response = await DisplayRoomApiService.deleteProduct(detailSl);

      debugPrint(
        'DELETE STATUS => ${response.statusCode}',
      );
      debugPrint(
        'DELETE RESPONSE => ${response.body}',
      );

      dynamic decoded;

      try {
        decoded =
            jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      final dynamic apiStatus =
      decoded is Map
          ? decoded['status_code']
          : null;

      final String message =
      decoded is Map
          ? decoded['message']
          ?.toString() ??
          ''
          : response.body;

      final bool success =
          response.statusCode >= 200 &&
              response.statusCode < 300 &&
              (
                  apiStatus == null ||
                      apiStatus == 200 ||
                      apiStatus.toString() ==
                          '200'
              );

      if (!mounted) {
        return;
      }

      if (!success) {
        _showMessage(
          message.isEmpty
              ? 'Delete failed.'
              : message,
          isError: true,
        );
        return;
      }

      _showMessage(
        message.isEmpty
            ? 'Product deleted successfully.'
            : message,
      );

      await _loadDeleteData();
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Delete failed: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          deletingKey = null;
        });
      }
    }
  }

  // ==========================================================================
  // DELETE COMPLETE MASTER
  // ==========================================================================

  Future<void> _deleteMaster(
      DeleteMasterRow item,
      ) async {
    final int masterSl =
    item.masterSl!;

    final String key =
        'master_$masterSl';

    if (deletingKey != null) {
      return;
    }

    setState(() {
      deletingKey = key;
    });

    try {
      final Uri uri =
      Uri.parse(apiUrl).replace(
        queryParameters: {
          'p_master_sl':
          masterSl.toString(),
        },
      );

      debugPrint('==========================================');
      debugPrint('DELETE MASTER');
      debugPrint('URL => $uri');
      debugPrint('MASTER SL => $masterSl');
      debugPrint('==========================================');

      final response = await DisplayRoomApiService.deleteMaster(masterSl);

      debugPrint(
        'DELETE STATUS => ${response.statusCode}',
      );
      debugPrint(
        'DELETE RESPONSE => ${response.body}',
      );

      dynamic decoded;

      try {
        decoded =
            jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      final dynamic apiStatus =
      decoded is Map
          ? decoded['status_code']
          : null;

      final String message =
      decoded is Map
          ? decoded['message']
          ?.toString() ??
          ''
          : response.body;

      final bool success =
          response.statusCode >= 200 &&
              response.statusCode < 300 &&
              (
                  apiStatus == null ||
                      apiStatus == 200 ||
                      apiStatus.toString() ==
                          '200'
              );

      if (!mounted) {
        return;
      }

      if (!success) {
        _showMessage(
          message.isEmpty
              ? 'Item delete failed.'
              : message,
          isError: true,
        );
        return;
      }

      _showMessage(
        message.isEmpty
            ? 'Item deleted successfully.'
            : message,
      );

      await _loadDeleteData();
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Delete failed: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          deletingKey = null;
        });
      }
    }
  }

  // ==========================================================================
  // UI HELPERS
  // ==========================================================================

  Widget _buildProductImage(
      String imageUrl,
      ) {
    if (imageUrl.isEmpty) {
      return Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius:
          BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
        ),
      );
    }

    return ClipRRect(
      borderRadius:
      BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        errorBuilder: (
            context,
            error,
            stackTrace,
            ) {
          return Container(
            width: 76,
            height: 76,
            color:
            Colors.grey.shade100,
            alignment:
            Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Colors.grey,
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(
      DeleteProductRow item,
      ) {
    final String key =
        'detail_${item.detailSl}';

    final bool deleting =
        deletingKey == key ||
            (item.masterSl != null &&
                deletingKey == 'master_${item.masterSl}');

    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 0,
      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(16),
        side: BorderSide(
          color:
          Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding:
        const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            _buildProductImage(
              item.imageUrl,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description
                        .isNotEmpty
                        ? item.description
                        : item.itemCode
                        .isNotEmpty
                        ? item.itemCode
                        : 'Unnamed Product',
                    maxLines: 2,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    const TextStyle(
                      fontSize: 15,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    item.itemCode.isEmpty
                        ? 'Item Code: -'
                        : 'Item Code: ${item.itemCode}',
                    style:
                    TextStyle(
                      fontSize: 12,
                      color: Colors
                          .grey.shade700,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      _deleteChip(
                        'Detail SL: '
                            '${item.detailSl ?? '-'}',
                      ),
                      _deleteChip(
                        'Master SL: '
                            '${item.masterSl ?? '-'}',
                      ),
                      if (item
                          .productCategory
                          .isNotEmpty)
                        _deleteChip(
                          item.productCategory,
                        ),
                      if (item
                          .business
                          .isNotEmpty)
                        _deleteChip(
                          item.business,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            SizedBox(
              height: 40,
              child:
              FilledButton.icon(
                style:
                FilledButton.styleFrom(
                  backgroundColor:
                  Colors.redAccent,
                  foregroundColor:
                  Colors.white,
                ),
                onPressed:
                deletingKey != null
                    ? null
                    : () {
                  _confirmDeleteProduct(
                    item,
                  );
                },
                icon: deleting
                    ? const SizedBox(
                  width: 17,
                  height: 17,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons
                      .delete_outline_rounded,
                  size: 18,
                ),
                label: Text(
                  deleting
                      ? 'Deleting...'
                      : 'Delete',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deleteChip(
      String text,
      ) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius:
        BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style:
        const TextStyle(
          fontSize: 11,
        ),
      ),
    );
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        backgroundColor:
        isError
            ? Colors.red
            : Colors.green,
        content: Text(message),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delete Display Room Item',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
            isLoading || deletingKey != null
                ? null
                : _loadDeleteData,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              0,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.shade100,
              ),
            ),
            child: const Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Delete operation permanent. '
                        'একটি product delete করলে ওই product + images delete হবে. '
                        'যদি সেটি Display Room-এর শেষ product হয়, '
                        'empty master record-ও automatically delete হবে.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              14,
              16,
              10,
            ),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText:
                'Search item code, description, room, SL...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                ),
                suffixIcon:
                searchController.text.isNotEmpty
                    ? IconButton(
                  onPressed:
                  searchController.clear,
                  icon: const Icon(
                    Icons.close_rounded,
                  ),
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
              child:
              CircularProgressIndicator(),
            )
                : RefreshIndicator(
              onRefresh: _loadDeleteData,
              child:
              filteredProducts.isEmpty
                  ? ListView(
                physics:
                const AlwaysScrollableScrollPhysics(),
                children:
                const [
                  SizedBox(
                    height: 180,
                  ),
                  Icon(
                    Icons
                        .inventory_2_outlined,
                    size: 60,
                    color:
                    Colors.grey,
                  ),
                  SizedBox(
                    height: 12,
                  ),
                  Center(
                    child: Text(
                      'No items found.',
                    ),
                  ),
                ],
              )
                  : ListView.builder(
                physics:
                const AlwaysScrollableScrollPhysics(),
                padding:
                const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  30,
                ),
                itemCount:
                filteredProducts.length,
                itemBuilder:
                    (
                    context,
                    index,
                    ) {
                  return _buildProductCard(
                    filteredProducts[
                    index],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController
        .removeListener(
      _applyFilter,
    );
    searchController.dispose();
    super.dispose();
  }
}
