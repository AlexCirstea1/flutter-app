import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vaultx_app/features/auth/data/services/auth_service.dart';

import '../../features/auth/data/services/biometric_auth_service.dart';
import '../data/services/service_locator.dart';
import '../data/services/storage_service.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> with TickerProviderStateMixin {
  /* ───────── deps ───────── */
  final _authService = serviceLocator<AuthService>();
  final _storageService = StorageService();
  final _bioService = BiometricAuthService();

  /* ───────── ui state ───── */
  String _inputPin = '';
  String? _errorMessage;
  String _currentlyPressed = '';
  bool _bioTried = false;

  late final AnimationController _wiggleCtrl;
  late final Animation<double> _wiggleAnim;
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();

    _wiggleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _wiggleAnim = Tween<double>(begin: 0, end: 16)
        .chain(CurveTween(curve: Curves.elasticInOut))
        .animate(_wiggleCtrl);

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 1, end: 1.2).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    // automatic biometric attempt if user opted-in
    _maybeStartBiometric();
  }

  /* ───────── biometric logic ───────── */

  Future<void> _maybeStartBiometric() async {
    final opted = await _storageService.isBiometricEnabled();
    final avail = await _bioService.isAvailable();
    if (!opted || !avail) return;

    // wait a frame (so the page transition finishes first)
    SchedulerBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    if (_bioTried) return; // only once per visit
    _bioTried = true;

    final ok = await _bioService.authenticate();
    if (ok && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _maybeAskEnableBiometric() async {
    final opted = await _storageService.isBiometricEnabled();
    final avail = await _bioService.isAvailable();
    if (opted || !avail) return;

    final enable = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Enable Face / Fingerprint Login?'),
            content: const Text(
              'Next time you can unlock the app using biometrics instead of the PIN.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('NOT NOW'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ENABLE'),
              ),
            ],
          ),
        ) ??
        false;

    if (enable) await _storageService.setBiometricEnabled(true);
  }

  /* ───────── pin flow ───────── */

  void _onNumberPress(String n) {
    if (_inputPin.length >= 6) return;
    setState(() {
      _inputPin += n;
      _errorMessage = null;
    });
    if (_inputPin.length == 6) _validatePin();
  }

  Future<void> _validatePin() async {
    final token = await _storageService.getAccessToken();
    final isValid = await _authService.validatePin(_inputPin, token!);

    if (!isValid) {
      _wiggleCtrl.forward(from: 0);
      setState(() {
        _errorMessage = 'Incorrect PIN';
        _inputPin = '';
      });
      return;
    }

    await _maybeAskEnableBiometric();
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  void _deletePin() {
    if (_inputPin.isEmpty) return;
    setState(() => _inputPin = _inputPin.substring(0, _inputPin.length - 1));
  }

  /* ───────── lifecycle ───────── */
  @override
  void dispose() {
    _wiggleCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  /* ───────── build ───────── */

  @override
  Widget build(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    final tt = Theme.of(ctx).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text('Enter your PIN', style: tt.titleMedium),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 60),

            /* ●●●●●●  circles  ●●●●●● */
            AnimatedBuilder(
              animation: _wiggleCtrl,
              builder: (_, __) => Transform.translate(
                offset: Offset(
                  _wiggleAnim.value *
                      (_wiggleCtrl.status == AnimationStatus.forward ? 1 : 0),
                  0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    final filled = i < _inputPin.length;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: AnimatedBuilder(
                        animation: _glowCtrl,
                        builder: (_, __) => Transform.scale(
                          scale: filled ? _glowAnim.value : 1,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled ? cs.primary : Colors.transparent,
                              border: Border.all(
                                  color: cs.primary.withOpacity(0.5)),
                              boxShadow: filled
                                  ? [
                                      BoxShadow(
                                        color: cs.primary.withOpacity(0.4),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : [],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),

            /* error text */
            AnimatedOpacity(
              opacity: _errorMessage == null ? 0 : 1,
              duration: const Duration(milliseconds: 300),
              child:
                  Text(_errorMessage ?? '', style: TextStyle(color: cs.error)),
            ),
            const Spacer(),

            /* keypad */
            Column(
              children: [
                _numRow(['1', '2', '3']),
                _numRow(['4', '5', '6']),
                _numRow(['7', '8', '9']),
                _numRow(['', '0', '⌫']),
              ],
            ),

            /* biometric retry button (if available) */
            FutureBuilder<bool>(
              future: _bioService.isAvailable(),
              builder: (_, snap) {
                if (snap.data != true) return const SizedBox();
                return IconButton(
                  icon: Icon(Icons.fingerprint, size: 32, color: cs.primary),
                  tooltip: 'Use Face / Fingerprint',
                  onPressed: _tryBiometric,
                );
              },
            ),
            const Spacer(),
            TextButton(
              onPressed: () => ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('PIN recovery not implemented'))),
              child: Text('Forgot your PIN?',
                  style: tt.bodyMedium?.copyWith(
                      color: tt.bodyMedium?.color?.withOpacity(0.7))),
            ),
          ],
        ),
      ),
    );
  }

  /* keypad helper */
  Widget _numRow(List<String> nums) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: nums.map((n) {
        return GestureDetector(
          onTapDown: (_) => setState(() => _currentlyPressed = n),
          onTapUp: (_) {
            setState(() => _currentlyPressed = '');
            n == '⌫' ? _deletePin() : _onNumberPress(n);
          },
          onTapCancel: () => setState(() => _currentlyPressed = ''),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 100),
            scale: _currentlyPressed == n ? 0.9 : 1,
            child: Container(
              width: 70,
              height: 70,
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surface.withOpacity(0.3),
                border: Border.all(color: cs.primary.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  n,
                  style: txt.bodyLarge?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
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
