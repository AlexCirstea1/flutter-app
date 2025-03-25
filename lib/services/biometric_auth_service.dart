import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  final LocalAuthentication auth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    return await auth.canCheckBiometrics;
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      bool isAuthenticated = await auth.authenticate(
        localizedReason: 'Authenticate to unlock Response',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return isAuthenticated;
    } catch (e) {
      return false;
    }
  }
}
