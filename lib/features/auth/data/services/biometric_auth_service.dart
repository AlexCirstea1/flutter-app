import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  final _auth = LocalAuthentication();

  Future<bool> isAvailable() => _auth.canCheckBiometrics;

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Scan your face or fingerprint to unlock Response',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
