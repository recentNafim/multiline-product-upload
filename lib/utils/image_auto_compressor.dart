import 'dart:typed_data';

import 'image_auto_compressor_stub.dart'
    if (dart.library.html) 'image_auto_compressor_web.dart' as platform;

/// Compress only oversized images before they reach Oracle's 10 MiB image
/// limit. Keeping the output below 9 MiB allows a small safety margin.
/// JPEG files remain JPEG; PNG/WebP files use WebP on the web to retain alpha.
/// No pubspec change is required.
Future<({Uint8List bytes, String mimeType})> optimizeOversizedUploadImage(
  Uint8List original,
  String sourceMimeType,
) => platform.optimizeImage(original, sourceMimeType);
