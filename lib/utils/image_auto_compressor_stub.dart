import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

/// Native fallback without extra dependencies. Flutter's built-in encoder can
/// produce PNG; progressively shrink the dimensions until the output fits.
Future<({Uint8List bytes, String mimeType})> optimizeImage(
  Uint8List original,
  String sourceMimeType,
) async {
  const maxOutput = 9 * 1024 * 1024;
  ui.Codec? probe;
  int width;
  int height;
  try {
    probe = await ui.instantiateImageCodec(original);
    final first = await probe.getNextFrame();
    width = first.image.width;
    height = first.image.height;
    first.image.dispose();
  } catch (_) {
    throw const FormatException('Cannot decode the selected image');
  } finally {
    probe?.dispose();
  }
  final longSide = math.max(width, height);
  for (final maxSide in <int>[2400, 2000, 1600, 1200, 900, 650, 450]) {
    final scale = math.min(1.0, maxSide / longSide);
    final newWidth = math.max(1, (width * scale).round());
    final newHeight = math.max(1, (height * scale).round());
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(
        original,
        targetWidth: newWidth,
        targetHeight: newHeight,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      try {
        final encoded = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (encoded == null) continue;
        final bytes = encoded.buffer.asUint8List(encoded.offsetInBytes, encoded.lengthInBytes);
        if (bytes.isNotEmpty && bytes.length <= maxOutput) {
          return (bytes: Uint8List.fromList(bytes), mimeType: 'image/png');
        }
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec?.dispose();
    }
  }
  throw const FormatException('Unable to resize this image under 10 MB');
}
