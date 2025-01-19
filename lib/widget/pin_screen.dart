import 'package:flutter/material.dart';
import 'package:vaultx_app/services/auth_service.dart';

import '../services/storage_service.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  String _inputPin = ""; // Store the user's input PIN
  bool _showDeleteButton = false; // Control the visibility of the delete button
  String _currentlyPressed = ""; // Track which button is being pressed
  String? _errorMessage; // To display an error message if PIN is incorrect

  // Animation controller and tween for smooth wiggle effect
  late AnimationController _controller;
  late Animation<double> _wiggleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), // Slightly slower duration
    );
    _wiggleAnimation = Tween<double>(begin: -8, end: 8)
        .chain(
            CurveTween(curve: Curves.elasticOut)) // Smooth and elastic effect
        .animate(_controller);
  }

  void _onNumberPress(String number) {
    if (_inputPin.length < 6) {
      setState(() {
        _inputPin += number;
        _showDeleteButton = _inputPin.isNotEmpty;
        _errorMessage = null; // Reset error message on new input
      });

      if (_inputPin.length == 6) {
        _validatePin();
      }
    }
  }

  Future<void> _validatePin() async {
    String? accessToken = await _storageService.getAccessToken();
    bool isValid = await _authService.validatePin(_inputPin, accessToken!);

    if (isValid) {
      // Navigate to the home screen if the PIN is correct
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Start the wiggle animation and display error message for incorrect PIN
      _controller.forward(from: 0);
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter PIN'),
        automaticallyImplyLeading: false, // Disable back button
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Even spacing
          children: <Widget>[
            // Extra space above the PIN input
            const SizedBox(height: 80),
            // Display the PIN as dots with smooth animations and wiggle effect
            Column(
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_wiggleAnimation.value, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              index < _inputPin.length
                                  ? Icons.circle
                                  : Icons.circle_outlined,
                              size: 24,
                              color: Colors.black26,
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                // Reserve space for the error message to avoid shifting layout
                SizedBox(
                  height: 20, // Fixed height for error message space
                  child: _errorMessage != null
                      ? Text(
                          _errorMessage!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 16),
                        )
                      : const SizedBox
                          .shrink(), // Invisible when there's no error
                ),
              ],
            ),
            // Custom keypad for numbers with animated press effect
            Expanded(
              child: Column(
                children: [
                  _buildNumberRow(["1", "2", "3"]),
                  _buildNumberRow(["4", "5", "6"]),
                  _buildNumberRow(["7", "8", "9"]),
                  _buildNumberRow(["", "0", _showDeleteButton ? "⌫" : ""]),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                // Add functionality for "Forgot your passcode?" button
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Passcode recovery not implemented yet')),
                );
              },
              child: const Text('Forgot your passcode?'),
            ),
          ],
        ),
      ),
    );
  }

  // Builds a row of number buttons with translucent circular styling
  Widget _buildNumberRow(List<String> numbers) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: numbers.map((number) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: number.isEmpty
                  ? const SizedBox.shrink() // Empty space for the first row
                  : GestureDetector(
                      onTapDown: (_) => setState(() {
                        _currentlyPressed = number; // Track the pressed button
                      }),
                      onTapUp: (_) => setState(() {
                        _currentlyPressed = ""; // Reset after press
                        if (number == "⌫") {
                          _deletePin();
                        } else {
                          _onNumberPress(number);
                        }
                      }),
                      onTapCancel: () => setState(() {
                        _currentlyPressed = ""; // Handle cancel state
                      }),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 100),
                        scale: _currentlyPressed == number
                            ? 0.9
                            : 1.0, // Button scales down when pressed
                        child: ElevatedButton(
                          onPressed:
                              null, // Disable button press as we use GestureDetector
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(20.0),
                            backgroundColor: Colors.black
                                .withOpacity(0.1), // Translucent background
                            shape: const CircleBorder(),
                            elevation: 5,
                            shadowColor:
                                Colors.black.withOpacity(0.2), // Soft shadow
                          ),
                          child: Text(
                            number,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color:
                                  Colors.white, // White text color like in iOS
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
