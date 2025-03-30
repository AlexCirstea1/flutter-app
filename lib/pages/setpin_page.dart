import 'package:flutter/material.dart';
import '../config/logger_config.dart';
import '../services/auth_service.dart';
import '../services/service_locator.dart';
import '../services/storage_service.dart';

class SetPinPage extends StatefulWidget {
  const SetPinPage({super.key});

  @override
  State<SetPinPage> createState() => _SetPinPageState();
}

class _SetPinPageState extends State<SetPinPage>
    with SingleTickerProviderStateMixin {
  final String _step1Title = 'SET NEW PIN';
  final String _step2Title = 'CONFIRM PIN';

  String _pin = '';
  String _confirmPin = '';
  bool _isConfirmStep = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _currentlyPressed = "";

  // For animations
  late AnimationController _wiggleController;
  late Animation<double> _wiggleAnimation;

  final AuthService _authService = serviceLocator<AuthService>();
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _wiggleAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(
        parent: _wiggleController,
        curve: Curves.elasticInOut,
      ),
    );
  }

  void _onNumberPress(String number) {
    if (_isConfirmStep) {
      if (_confirmPin.length < 6) {
        setState(() {
          _confirmPin += number;
          _errorMessage = null;
        });

        if (_confirmPin.length == 6) {
          _validateAndSavePin();
        }
      }
    } else {
      if (_pin.length < 6) {
        setState(() {
          _pin += number;
          _errorMessage = null;
        });

        if (_pin.length == 6) {
          setState(() {
            _isConfirmStep = true;
          });
        }
      }
    }
  }

  void _deleteDigit() {
    if (_isConfirmStep) {
      if (_confirmPin.isNotEmpty) {
        setState(() {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
          _errorMessage = null;
        });
      }
    } else {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
          _errorMessage = null;
        });
      }
    }
  }

  void _resetInput() {
    setState(() {
      if (_isConfirmStep) {
        _confirmPin = '';
      } else {
        _pin = '';
      }
      _errorMessage = null;
    });
  }

  void _backToFirstStep() {
    setState(() {
      _isConfirmStep = false;
      _confirmPin = '';
      _errorMessage = null;
    });
  }

  Future<void> _validateAndSavePin() async {
    if (_pin != _confirmPin) {
      _wiggleController.forward().then((_) => _wiggleController.reverse());
      setState(() {
        _errorMessage = 'PINs do not match!';
        _confirmPin = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final accessToken = await _storageService.getAccessToken();
      if (accessToken != null) {
        bool success = await _authService.savePin(_pin, accessToken);
        if (success) {
          await _storageService.saveHasPin(true);
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          setState(() {
            _errorMessage = 'Failed to save PIN. Please try again.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'User is not authenticated.';
          _isLoading = false;
        });
      }
    } catch (error) {
      LoggerService.logError('Error saving PIN: $error');
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _wiggleController.dispose();
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
          _isConfirmStep ? _step2Title : _step1Title,
          style: theme.appBarTheme.titleTextStyle,
        ),
        centerTitle: true,
        leading: _isConfirmStep
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: colorScheme.primary),
                onPressed: _backToFirstStep,
              )
            : IconButton(
                icon: Icon(Icons.close, color: colorScheme.primary),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surface,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Text(
                _isConfirmStep
                    ? 'Please confirm your 6-digit security PIN'
                    : 'Create a 6-digit security PIN',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              AnimatedBuilder(
                animation: _wiggleController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      _wiggleAnimation.value *
                          (_wiggleController.status == AnimationStatus.forward
                              ? 1
                              : 0),
                      0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        final currentPin = _isConfirmStep ? _confirmPin : _pin;
                        final filled = index < currentPin.length;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
                            width: 18,
                            height: 18,
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
                      }),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              AnimatedOpacity(
                opacity: _errorMessage != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: colorScheme.error.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMessage ?? '',
                    style: TextStyle(color: colorScheme.error, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const Spacer(),
              if (_isLoading)
                CircularProgressIndicator(color: colorScheme.secondary)
              else
                Column(
                  children: [
                    _buildNumberRow(["1", "2", "3"]),
                    _buildNumberRow(["4", "5", "6"]),
                    _buildNumberRow(["7", "8", "9"]),
                    _buildNumberRow(["C", "0", "⌫"]),
                  ],
                ),
              const Spacer(),
              Text(
                'PIN will be required to access the app',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
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

            if (number == "⌫") {
              _deleteDigit();
            } else if (number == "C") {
              _resetInput();
            } else {
              _onNumberPress(number);
            }
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
                  color: number == "C"
                      ? colorScheme.error.withOpacity(0.3)
                      : colorScheme.primary.withOpacity(0.1),
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
                child: number == "⌫"
                    ? Icon(
                        Icons.backspace_outlined,
                        color: theme.textTheme.bodyLarge?.color,
                        size: 22,
                      )
                    : number == "C"
                        ? Icon(
                            Icons.clear,
                            color: colorScheme.error,
                            size: 22,
                          )
                        : Text(
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
