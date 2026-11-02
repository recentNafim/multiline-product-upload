import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Download a generated Excel file without any external asset or URL.
/// Deferring blob URL cleanup is important for Chromium and some mobile browsers.
void saveExcelTemplate(List<int> bytes, String fileName) {
  final blob = html.Blob(
    [Uint8List.fromList(bytes)],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  try {
    anchor.click();
  } finally {
    anchor.remove();
    // An immediate revoke can interrupt the browser's file download.
    Timer(const Duration(seconds: 10), () => html.Url.revokeObjectUrl(url));
  }
}
