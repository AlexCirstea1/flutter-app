import 'package:flutter/material.dart';
import 'package:vaultx_app/services/auth_service.dart';

import '../services/biometric_auth_service.dart';
import '../services/service_locator.dart';
import '../services/storage_service.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> with TickerProviderStateMixin {
  final AuthService _authService = serviceLocator<AuthService>();
  final StorageService _storageService = StorageService();
  String _inputPin = "";
  String? _errorMessage;
  bool _showDeleteButton = false;
  String _currentlyPressed = "";

  late AnimationController _wiggleController;
  late Animation<double> _wiggleAnimation;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _wiggleAnimation = Tween<double>(begin: 0, end: 16)
        .chain(CurveTween(curve: Curves.elasticInOut))
        .animate(_wiggleController);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // _tryBiometricAuth();
  }

  void _onNumberPress(String number) {
    if (_inputPin.length < 6) {
      setState(() {
        _inputPin += number;
        _showDeleteButton = _inputPin.isNotEmpty;
        _errorMessage = null;
      });

      if (_inputPin.length == 6) {
        _validatePin();
      }
    }
  }

  Future<void> _tryBiometricAuth() async {
    final biometricAuth = BiometricAuthService();
    final available = await biometricAuth.isBiometricAvailable();

    if (available) {
      final authenticated = await biometricAuth.authenticateWithBiometrics();
      if (authenticated && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  Future<void> _validatePin() async {
    final token = await _storageService.getAccessToken();
    final isValid = await _authService.validatePin(_inputPin, token!);

    if (isValid) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      _wiggleController.forward(from: 0);
      setState(() {
        _errorMessage = "Incorrect PIN";
        _inputPin = "";
        _showDeleteButton = false;
      });
    }
  }

  void _deletePin() {
    if (_inputPin.isNotEmpty) {
      setState(() {
        _inputPin = _inputPin.substring(0, _inputPin.length - 1);
        _showDeleteButton = _inputPin.isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Enter your PIN',
          style: theme.appBarTheme.titleTextStyle,
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 60),
            AnimatedBuilder(
              animation: _wiggleController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                      _wiggleAnimation.value *
                          (_wiggleController.status == AnimationStatus.forward
                              ? 1
                              : 0),
                      0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      final filled = index < _inputPin.length;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: AnimatedBuilder(
                          animation: _glowController,
                          builder: (context, _) {
                            return Transform.scale(
                              scale: filled ? _glowAnimation.value : 1.0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: filled
                                      ? colorScheme.primary
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: colorScheme.primary.withOpacity(0.5),
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: filled
                                      ? [
                                    BoxShadow(
                                      color: colorScheme.primary
                                          .withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                      : [],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            AnimatedOpacity(
              opacity: _errorMessage != null ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Text(
                _errorMessage ?? '',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
            const Spacer(),
            Column(
              children: [
                _buildNumberRow(["1", "2", "3"]),
                _buildNumberRow(["4", "5", "6"]),
                _buildNumberRow(["7", "8", "9"]),
                _buildNumberRow(["", "0", "⌫"]),
              ],
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN recovery not implemented')),
                );
              },
              child: Text(
                'Forgot your PIN?',
                style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberRow(List<String> numbers) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((number) {
        return GestureDetector(
          onTapDown: (_) => setState(() => _currentlyPressed = number),
          onTapUp: (_) {
            setState(() => _currentlyPressed = "");
            number == "⌫" ? _deletePin() : _onNumberPress(number);
          },
          onTapCancel: () => setState(() => _currentlyPressed = ""),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 100),
            scale: _currentlyPressed == number ? 0.9 : 1.0,
            child: Container(
              width: 70,
              height: 70,
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Center(
                child: Text(
                  number,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
