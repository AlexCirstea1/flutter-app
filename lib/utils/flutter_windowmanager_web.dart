/// Web stub for flutter_windowmanager to maintain compatibility with web builds
class FlutterWindowManager {
  static const int FLAG_SECURE = 0x00000800;
  
  /// Mock implementation for web - does nothing as web doesn't support this functionality
  static Future<bool> addFlags(int flags) async {
    return true;
  }
  
  /// Mock implementation for web - does nothing as web doesn't support this functionality
  static Future<bool> clearFlags(int flags) async {
    return true;
  }
}