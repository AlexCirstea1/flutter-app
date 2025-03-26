import 'package:flutter/material.dart';

class ConsentDialog extends StatelessWidget {
  final VoidCallback onConsentGiven;
  final VoidCallback onConsentDenied;
  final VoidCallback onLearnMore;

  const ConsentDialog({
    Key? key,
    required this.onConsentGiven,
    required this.onConsentDenied,
    required this.onLearnMore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        'Blockchain Service Consent',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Our application leverages blockchain technology to provide you with enhanced security, transparency, '
              'and trust. By enabling our blockchain service, your data is secured using state-of-the-art cryptography, '
              'and transactions become verifiable and tamper-proof.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Do you consent to the use of blockchain services for your account? Your consent helps us to maintain '
              'a secure and transparent platform. You can change this preference in your settings later.',
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: onLearnMore,
                child: const Text(
                  'Learn More',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onConsentDenied,
          child: const Text(
            'Opt out',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: onConsentGiven,
          child: const Text('I Agree'),
        ),
      ],
    );
  }
}
