class DeleteParsedData {
  final List<DeleteProductRow> products;
  final List<DeleteMasterRow> masters;

  const DeleteParsedData({
    required this.products,
    required this.masters,
  });
}

class DeleteProductRow {
  final int? detailSl;
  final int? masterSl;
  final String itemCode;
  final String description;
  final String productCategory;
  final String business;
  final String subCategory;
  final String displayRoomNo;
  final String displayRoomName;
  final String imageUrl;

  const DeleteProductRow({
    required this.detailSl,
    required this.masterSl,
    required this.itemCode,
    required this.description,
    required this.productCategory,
    required this.business,
    required this.subCategory,
    required this.displayRoomNo,
    required this.displayRoomName,
    required this.imageUrl,
  });
}

class DeleteMasterRow {
  final int? masterSl;
  final String business;
  final String subCategory;
  final String displayRoomNo;
  final String displayRoomName;
  final String organizationCode;
  final int? organizationId;
  final String status;
  final int detailsCount;

  const DeleteMasterRow({
    required this.masterSl,
    required this.business,
    required this.subCategory,
    required this.displayRoomNo,
    required this.displayRoomName,
    required this.organizationCode,
    required this.organizationId,
    required this.status,
    required this.detailsCount,
  });
}

String deleteAsText(dynamic value) {
  return value?.toString().trim() ?? '';
}

int? deleteAsInt(dynamic value) {
  if (value == null) {
    return null;
  }

  final String text =
  value.toString().trim();

  if (text.isEmpty) {
    return null;
  }

  return int.tryParse(text) ??
      double.tryParse(text)?.toInt();
}
