// Browser sessionStorage persists refreshes in the same tab, and is cleared
// when the browser tab is closed. This is for UI convenience, not an
// authorization credential: the Oracle API must validate identity server-side.
import 'dart:html' as html;

const String _storageKey = 'mlil_admin_hris_identity_v1';
String? readAuthSession() {
  try {
    return html.window.sessionStorage[_storageKey];
  } catch (_) {
    return null;
  }
}
void saveAuthSession(String serialized) {
  try {
    html.window.sessionStorage[_storageKey] = serialized;
  } catch (_) {
    // Browsers can disable storage. Login will still work until refresh.
  }
}
void clearAuthSession() {
  try {
    html.window.sessionStorage.remove(_storageKey);
  } catch (_) {}
}
