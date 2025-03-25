import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.primary,
        foregroundColor: theme.onPrimary,
        title: const Text('About Response'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset('assets/images/response_transparent.png', height: 70),
            const SizedBox(height: 40),
            Text(
              'Response is a secure, anonymous messaging app built for academic exploration of cybersecurity, encryption, and privacy.',
              style: TextStyle(color: theme.onSurface, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Divider(color: theme.onSurface.withOpacity(0.2)),
            const SizedBox(height: 20),
            Text(
              '🔐 End-to-End Encryption',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'All messages are encrypted with AES-256 for content confidentiality, and the AES keys are exchanged securely using RSA-2048 encryption. We use self-signed X.509 certificates for public key distribution.',
              style: TextStyle(color: theme.onSurface, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 50),
            Text(
              '© 2025 Response Project. All rights reserved.\nThis app is for academic and research purposes only.',
              style: TextStyle(
                  fontSize: 12, color: theme.onSurface.withOpacity(0.6)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
