import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.cyan.shade200),
        title: Text(
          'ABOUT RESPONSE',
          style: TextStyle(
            fontSize: 16,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w300,
            color: Colors.cyan.shade100,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Color(0xFF101720)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo with cyberpunk effect
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/response_transparent.png',
                    height: 70,
                    color: Colors.cyan.shade100,
                  ),
                ),

                const SizedBox(height: 40),

                // Main description with cyber styling
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121A24),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.cyan.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Response is a secure, anonymous messaging app built for academic exploration of cybersecurity, encryption, and privacy.',
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 30),

                // Separator with terminal style
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.cyan.withOpacity(0.2),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                      ),
                      child: Text(
                        'SECURITY',
                        style: TextStyle(
                          color: Colors.cyan.shade100,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.cyan.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Encryption section with cybersecurity aesthetic
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.cyan.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: Colors.cyan.shade300,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'END-TO-END ENCRYPTION',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.cyan.shade100,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'All messages are encrypted with AES-256 for content confidentiality, and the AES keys are exchanged securely using RSA-2048 encryption. We use self-signed X.509 certificates for public key distribution.',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                          height: 1.6,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 50),

                // Footer with cyberpunk styling
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.cyan.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '© 2025 RESPONSE PROJECT\nFOR ACADEMIC AND RESEARCH PURPOSES ONLY',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.cyan.shade100.withOpacity(0.4),
                      letterSpacing: 1.0,
                      height: 1.7,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}