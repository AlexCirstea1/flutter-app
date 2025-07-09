class DummyPasswordStore {
  static final Map<String, String> _passwords = {};

  static void setPassword(String username, String password) {
    _passwords[username] = password;
  }

  static String? getPassword(String username) {
    return _passwords[username];
  }
}