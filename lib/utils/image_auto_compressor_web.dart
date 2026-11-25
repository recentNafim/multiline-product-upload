// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

/// Browser canvas encoder: inexpensive for Flutter Web, no dependency or
/// custom JavaScript required. The image is never uploaded uncompressed.
Future<({Uint8List bytes, String mimeType})> optimizeImage(
  Uint8List original,
  String sourceMimeType,
) async {
  const maxOutput = 9 * 1024 * 1024;
  final blobUrl = html.Url.createObjectUrlFromBlob(
    html.Blob([original], sourceMimeType),
  );
  final element = html.ImageElement();
  final loaded = Completer<void>();
  final onLoad = element.onLoad.listen((_) {
    if (!loaded.isCompleted) loaded.complete();
  });
  final onError = element.onError.listen((_) {
    if (!loaded.isCompleted) {
      loaded.completeError(const FormatException('Browser cannot decode this image'));
    }
  });
  try {
    element.src = blobUrl;
    await loaded.future.timeout(const Duration(seconds: 45));
    final width = element.naturalWidth;
    final height = element.naturalHeight;
    if (width < 1 || height < 1) {
      throw const FormatException('Image dimensions are invalid');
    }
    final longSide = math.max(width, height);
    final outputMime = sourceMimeType == 'image/jpeg'
        ? 'image/jpeg' : 'image/webp';

    // Try higher resolution and quality first. The 9 MiB margin ensures the
    // binary payload, rather than its base64 representation, meets Oracle's
    // 10 MiB save_image(...) restriction.
    for (final maxSide in <int>[3200, 2800, 2400, 2000, 1600, 1200, 900, 650]) {
      final scale = math.min(1.0, maxSide / longSide);
      final outWidth = math.max(1, (width * scale).round());
      final outHeight = math.max(1, (height * scale).round());
      final canvas = html.CanvasElement(width: outWidth, height: outHeight);
      final context = canvas.context2D;
      // JPEG has no alpha; render transparent pixels on white instead of black.
      if (outputMime == 'image/jpeg') {
        context.fillStyle = '#FFFFFF';
        context.fillRect(0, 0, outWidth, outHeight);
      }
      context.drawImageScaled(element, 0, 0, outWidth, outHeight);
      for (final quality in <double>[0.90, 0.82, 0.72, 0.62]) {
        final dataUrl = canvas.toDataUrl(outputMime, quality);
        if (!dataUrl.startsWith('data:$outputMime;base64,')) {
          throw FormatException('$outputMime encoding is not available in this browser');
        }
        final encoded = dataUrl.substring(dataUrl.indexOf(',') + 1);
        // Base64 length check avoids allocating giant byte arrays for drafts
        // that are clearly above the final size limit.
        if (encoded.length > ((maxOutput + 2) ~/ 3) * 4) continue;
        final converted = base64Decode(encoded);
        if (converted.isNotEmpty && converted.length <= maxOutput) {
          return (bytes: converted, mimeType: outputMime);
        }
      }
    }
    throw const FormatException('Unable to reduce this image below the Oracle 10 MB limit');
  } finally {
    await onLoad.cancel();
    await onError.cancel();
    html.Url.revokeObjectUrl(blobUrl);
  }
}
