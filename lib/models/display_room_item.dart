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

  const DisplayRoomItem({
    required this.sl,
    required this.masterSl,
    required this.business,
    required this.subCategory,
    required this.organizationId,
    required this.organizationCode,
    required this.displayRoomNo,
    required this.displayRoomName,
    required this.status,
    required this.assignee,
    required this.createdBy,
    required this.updatedBy,
    required this.sourceSl,
    required this.productCategory,
    required this.printValue,
    required this.itemQrCode,
    required this.fileUrl,
    required this.fileName,
    required this.mimeType,
    required this.itemCode,
    required this.description,
    required this.uom,
    required this.quantity,
    required this.unitPrice,
    required this.subInventoryCode,
    required this.locatorId,
    required this.cbm,
    required this.fob,
    required this.weight,
    required this.materialSpecification,
  });

  factory DisplayRoomItem.fromJson(Map<String, dynamic> json) {
    dynamic v(String lower, String upper) => json[lower] ?? json[upper];

    final note = _text(v('note', 'NOTE'));

    return DisplayRoomItem(
      sl: _int(v('sl', 'SL')),
      masterSl: _int(v('m_sl', 'M_SL')),
      business: _text(v('business', 'BUSINESS')),
      subCategory: _text(v('sub_category', 'SUB_CATEGORY')),
      organizationId: _int(v('organization_id', 'ORGANIZATION_ID')),
      organizationCode: _text(v('organization_code', 'ORGANIZATION_CODE')),
      displayRoomNo: _text(v('display_room_no', 'DISPLAY_ROOM_NO')),
      displayRoomName: _text(v('display_room_name', 'DISPLAY_ROOM_NAME')),
      status: _text(v('status', 'STATUS')),
      assignee: _int(v('assignee', 'ASSIGNEE')),
      createdBy: _int(v('created_by', 'CREATED_BY')),
      updatedBy: _int(v('updated_by', 'UPDATED_BY')),
      sourceSl: _extractNote(note, 'SOURCE_SL'),
      productCategory: _text(v('product_category', 'PRODUCT_CATEGORY')),
      printValue: _extractNote(note, 'PRINT'),
      itemQrCode: _extractNote(note, 'ITEM_QRCODE'),
      fileUrl: _text(v('file_url', 'FILE_URL')),
      fileName: _text(v('file_name', 'FILE_NAME')),
      mimeType: _text(v('mime_type', 'MIME_TYPE')),
      itemCode: _text(v('item_code', 'ITEM_CODE')),
      description: _text(v('description', 'DESCRIPTION')),
      uom: _text(v('uom', 'UOM')),
      quantity: _double(v('quantity', 'QUANTITY')),
      unitPrice: _double(v('unit_price', 'UNIT_PRICE')),
      subInventoryCode:
      _text(v('sub_inventory_code', 'SUB_INVENTORY_CODE')),
      locatorId: _int(v('locator_id', 'LOCATOR_ID')),
      cbm: _text(v('cbm', 'CBM')),
      fob: _double(v('fob', 'FOB')),
      weight: _double(v('weight', 'WEIGHT')),
      materialSpecification:
      _text(v('material_specification', 'MATERIAL_SPECIFICATION')),
    );
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static int? _int(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString()) ??
        double.tryParse(value.toString())?.toInt();
  }

  static double? _double(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  static String _extractNote(String note, String key) {
    if (note.isEmpty) return '';

    for (final part in note.split(';')) {
      final index = part.indexOf('=');
      if (index <= 0) continue;

      final currentKey = part.substring(0, index).trim().toUpperCase();
      if (currentKey == key.toUpperCase()) {
        return part.substring(index + 1).trim();
      }
    }

    return '';
  }
}
