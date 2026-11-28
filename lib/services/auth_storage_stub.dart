// Non-web platforms: keep the logged-in identity in memory only.
String? readAuthSession() => null;
void saveAuthSession(String serialized) {}
void clearAuthSession() {}
