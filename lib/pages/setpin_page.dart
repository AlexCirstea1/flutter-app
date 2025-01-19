import 'package:flutter/material.dart';
import 'package:vaultx_app/config/logger_config.dart';

import '../services/auth_service.dart';
import '../services/storage_service.dart';

class SetPinPage extends StatefulWidget {
  const SetPinPage({super.key});

  @override
  State<SetPinPage> createState() => _SetPinPageState();
}

class _SetPinPageState extends State<SetPinPage> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Your PIN'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _pinController,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'PIN',
                hintText: 'Enter your desired PIN',
              ),
            ),
            TextField(
              controller: _confirmPinController,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
                hintText: 'Re-enter your PIN',
              ),
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 10),
            _isLoading
                ? const CircularProgressIndicator()
                : Column(
                    children: [
                      ElevatedButton(
                        onPressed: _savePin,
                        child: const Text('Save PIN'),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePin() async {
    // Ensure that the PIN is exactly 6 digits
    if (_pinController.text.length != 6 ||
        _confirmPinController.text.length != 6) {
      setState(() {
        _errorMessage = 'PIN must be exactly 6 digits!';
      });
      return;
    }

    // Check if both PINs match
    if (_pinController.text != _confirmPinController.text) {
      setState(() {
        _errorMessage = 'Pins do not match!';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null; // Reset error message
    });

    try {
      final accessToken = await _storageService.getAccessToken();
      if (accessToken != null) {
        bool success =
            await _authService.savePin(_pinController.text, accessToken);
        if (success) {
          await _storageService.saveHasPin(true);
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          setState(() {
            _errorMessage = 'Failed to save PIN. Please try again.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'User is not logged in.';
        });
      }
    } catch (error) {
      LoggerService.logError('Error saving PIN: $error');
      setState(() {
        _errorMessage = 'An error occurred. Please try again later.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }
}
