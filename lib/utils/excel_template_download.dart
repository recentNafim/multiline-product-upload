// Platform-specific download so the app still compiles outside Web.
export 'excel_template_download_stub.dart'
    if (dart.library.html) 'excel_template_download_web.dart';
