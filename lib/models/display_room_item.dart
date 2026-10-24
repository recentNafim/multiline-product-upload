class DisplayRoomItem {
  final int? sl;
  final int? masterSl;
  final String business;
  final String subCategory;
  final int? organizationId;
  final String organizationCode;
  final String displayRoomNo;
  final String displayRoomName;
  final String status;
  final int? assignee;
  final int? createdBy;
  final int? updatedBy;
  final String sourceSl;
  final String productCategory;
  final String printValue;
  final String itemQrCode;
  final String fileUrl;
  final String fileName;
  final String mimeType;
  final String itemCode;
  final String description;
  final String uom;
  final double? quantity;
  final double? unitPrice;
  final String subInventoryCode;
  final int? locatorId;
  final String cbm;
  final double? fob;
  final double? weight;
  final String materialSpecification;
  final String sizeRange;
  final List<String> images;

  const DisplayRoomItem({required this.sl, required this.masterSl,
    required this.business, required this.subCategory, required this.organizationId,
    required this.organizationCode, required this.displayRoomNo, required this.displayRoomName,
    required this.status, required this.assignee, required this.createdBy, required this.updatedBy,
    required this.sourceSl, required this.productCategory, required this.printValue,
    required this.itemQrCode, required this.fileUrl, required this.fileName,
    required this.mimeType, required this.itemCode, required this.description,
    required this.uom, required this.quantity, required this.unitPrice,
    required this.subInventoryCode, required this.locatorId, required this.cbm,
    required this.fob, required this.weight, required this.materialSpecification,
    required this.sizeRange, required this.images});

  factory DisplayRoomItem.fromMasterDetail(Map<String, dynamic> master,
      Map<String, dynamic> detail) {
    String s(dynamic v) => v?.toString().trim() ?? '';
    int? i(dynamic v) => v is num ? v.toInt() : int.tryParse(s(v));
    double? d(dynamic v) => v is num ? v.toDouble() : double.tryParse(s(v));
    // Read both traditional ORDS snake_case and uppercase / camelCase keys.
    dynamic byNormalizedKey(Map<String, dynamic> map, Set<String> expected) {
      for (final entry in map.entries) {
        final key = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (expected.contains(key) && s(entry.value).isNotEmpty) {
          return entry.value;
        }
      }
      return null;
    }
    final sizeRangeValue = byNormalizedKey(
      detail, const {'sizerange', 'sizewise', 'sizewiserange'},
    ) ?? byNormalizedKey(
      master, const {'sizerange', 'sizewise', 'sizewiserange'},
    );
    final explicitMoq = byNormalizedKey(
      detail, const {'moq', 'minimumorderquantity', 'minimumqty'},
    ) ?? byNormalizedKey(
      master, const {'moq', 'minimumorderquantity', 'minimumqty'},
    );
    final rawImages = detail['images'];
    final photos = <String>[];
    if (rawImages is List) {
      for (final photo in rawImages) {
        if (photo is Map) {
          final name = s(photo['image_url'] ?? photo['file_url'] ?? photo['file_name']);
          if (name.isNotEmpty) photos.add(name);
        } else if (s(photo).isNotEmpty) { photos.add(s(photo)); }
      }
    }
    return DisplayRoomItem(
      sl: i(detail['sl']), masterSl: i(master['sl']),
      business: s(master['business']), subCategory: s(master['sub_category']),
      organizationId: i(master['organization_id'] ?? detail['organization_id']),
      organizationCode: s(master['organization_code']),
      displayRoomNo: s(master['display_room_no']),
      displayRoomName: s(master['display_room_name']),
      status: s(master['status']), assignee: i(master['assignee']),
      createdBy: i(master['created_by']), updatedBy: i(master['updated_by']),
      sourceSl: s(detail['source_sl']), productCategory: s(detail['product_category']),
      printValue: s(detail['print']), itemQrCode: s(detail['item_qrcode']),
      fileUrl: s(detail['file_url']), fileName: s(detail['file_name']),
      mimeType: s(detail['mime_type']), itemCode: s(detail['item_code']),
      description: s(detail['description']), uom: s(detail['uom']),
      quantity: d(explicitMoq ?? detail['quantity']), unitPrice: d(detail['unit_price']),
      subInventoryCode: s(detail['sub_inventory_code']), locatorId: i(detail['locator_id']),
      cbm: s(detail['cbm']), fob: d(detail['fob']), weight: d(detail['weight']),
      materialSpecification: s(detail['material_specification']),
      sizeRange: s(sizeRangeValue), images: photos,
    );
  }
}
