import 'package:flutter/material.dart';

class ConsentDialog extends StatelessWidget {
  final VoidCallback onConsentGiven;
  final VoidCallback onConsentDenied;
  final VoidCallback onLearnMore;

  const ConsentDialog({
    super.key,
    required this.onConsentGiven,
    required this.onConsentDenied,
    required this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surface.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.1),
              blurRadius: 15,
              spreadRadius: -5,
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.security, size: 18, color: colorScheme.primary),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'BLOCKCHAIN SERVICE CONSENT',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: colorScheme.primary.withOpacity(0.1), height: 1),
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color,
                  fontSize: 13,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(
                    text: 'Our application leverages ',
                  ),
                  TextSpan(
                    text: 'BLOCKCHAIN TECHNOLOGY',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const TextSpan(
                    text:
                        ' to provide you with enhanced security, transparency, '
                        'and trust. Your data is secured using state-of-the-art cryptography, '
                        'and transactions become verifiable and tamper-proof.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Do you consent to the use of blockchain services for your account? Your consent helps us to maintain a secure and transparent platform.',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                /* ── DETAILS ─────────────────────────── */
                InkWell(
                  onTap: onLearnMore,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'DETAILS',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                          overflow: TextOverflow.fade,
                          softWrap: false,
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(), // push the two action buttons right

                /* ── OPT-OUT ────────────────────────── */
                TextButton(
                  onPressed: onConsentDenied,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'OPT OUT',
                    style: TextStyle(fontSize: 11, letterSpacing: 1),
                  ),
                ),

                const SizedBox(width: 8),

                /* ── I AGREE ─────────────────────────── */
                ElevatedButton(
                  onPressed: onConsentGiven,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(
                        color: colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    shadowColor: colorScheme.primary.withOpacity(0.15),
                    elevation: 6,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'I AGREE',
                    style: TextStyle(fontSize: 11, letterSpacing: 1),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
