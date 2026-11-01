import 'dart:html' as html;
import 'dart:typed_data';

void saveExcelTemplate(List<int> bytes, String fileName) {
  final blob = html.Blob([
    Uint8List.fromList(bytes),
  ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    html.AnchorElement(href: url)
      ..download = fileName
      ..click();
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
