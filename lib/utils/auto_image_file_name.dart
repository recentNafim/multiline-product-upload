// Every uploaded image receives its final name from the app, not from Excel
// or the selected source image. The backend receives this in images[].file_name.
// Keep this helper independent from Flutter for easy unit testing.

String _safeImageNamePart(String value, {String fallback = 'ITEM'}) {
  var cleaned = value.trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F\x7F]+'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^[._]+|[._]+$'), '');
  if (cleaned.isEmpty) cleaned = fallback;
  if (cleaned.length > 48) cleaned = cleaned.substring(0, 48);
  return cleaned;
}

String _imageExtension(Map<String, dynamic> image) {
  final originalName = (image['file_name'] ?? '').toString().toLowerCase();
  final dot = originalName.lastIndexOf('.');
  final originalExtension = dot < 0 ? '' : originalName.substring(dot + 1);
  if (const {'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(originalExtension)) {
    return originalExtension;
  }
  final mime = (image['mime_type'] ?? '').toString().toLowerCase();
  if (mime.contains('png')) return 'png';
  if (mime.contains('webp')) return 'webp';
  if (mime.contains('gif')) return 'gif';
  if (mime.contains('jpeg') || mime.contains('jpg')) return 'jpg';
  // Do not silently assign JPEG extension to an unknown image format.
  throw FormatException('Unsupported image format: $originalName ($mime)');
}

String autoImageFileName({
  required String itemCode,
  required String itemName,
  required int excelSerial,
  required int imageNumber,
  required Map<String, dynamic> image,
  required DateTime uploadTime,
}) {
  final code = _safeImageNamePart(itemCode, fallback: 'ITEM_CODE');
  final name = _safeImageNamePart(itemName, fallback: 'ITEM_NAME');
  final date = '${uploadTime.year.toString().padLeft(4, '0')}'
      '${uploadTime.month.toString().padLeft(2, '0')}'
      '${uploadTime.day.toString().padLeft(2, '0')}';
  final time = '${uploadTime.hour.toString().padLeft(2, '0')}'
      '${uploadTime.minute.toString().padLeft(2, '0')}'
      '${uploadTime.second.toString().padLeft(2, '0')}'
      '${uploadTime.millisecond.toString().padLeft(3, '0')}';
  final serial = excelSerial > 0 ? excelSerial : 1;
  final imageIndex = imageNumber.toString().padLeft(2, '0');
  final ext = _imageExtension(image);
  return '${code}_${name}_${serial}_${imageIndex}_${date}_${time}.$ext';
}

/// Assigns filenames immediately before POST. Source filename is *never*
/// forwarded to the API. Bytes and MIME type remain unchanged.
List<Map<String, dynamic>> assignAutomaticImageFileNames({
  required List<dynamic> images,
  required String itemCode,
  required String itemName,
  required int excelSerial,
  required DateTime uploadTime,
}) {
  return <Map<String, dynamic>>[
    for (var index = 0; index < images.length; index++)
      <String, dynamic>{
        ...Map<String, dynamic>.from(images[index] as Map),
        'file_name': autoImageFileName(
          itemCode: itemCode,
          itemName: itemName,
          excelSerial: excelSerial,
          imageNumber: index + 1,
          image: Map<String, dynamic>.from(images[index] as Map),
          uploadTime: uploadTime,
        ),
      },
  ];
}
