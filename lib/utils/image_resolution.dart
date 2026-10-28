import 'dart:typed_data';
import 'dart:ui' as ui;

/// Read actual pixel dimensions (not the displayed Excel cell size).
/// No resize/recompression is performed; original image bytes stay intact.
class ImageResolution {
  final int width;
  final int height;
  const ImageResolution(this.width, this.height);

  int get shortSide => width < height ? width : height;
  int get longSide => width > height ? width : height;

  /// Full-size product images should ideally be at least 1200 x 900.
  /// Images smaller than 800 x 600 will look blurry in the full-screen view.
  bool get isLowResolution => shortSide < 600 || longSide < 800;

  @override
  String toString() => '$width x $height pixels';
}

Future<ImageResolution?> readImageResolution(Uint8List? bytes) async {
  if (bytes == null || bytes.isEmpty) return null;
  ui.Codec? codec;
  try {
    codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    try {
      return ImageResolution(frame.image.width, frame.image.height);
    } finally {
      frame.image.dispose();
    }
  } catch (_) {
    // Not a supported raster image or decoding failed: leave that to the
    // existing upload/preview error handling.
    return null;
  } finally {
    codec?.dispose();
  }
}
