import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'PRIVACY POLICY',
          style: theme.appBarTheme.titleTextStyle,
        ),
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back, color: theme.appBarTheme.iconTheme?.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildSectionHeader(context, 'Privacy Policy', Icons.shield),
              _buildTimestamp(context, 'Last Updated: May 20, 2025'),
              _buildParagraph(
                  context,
                  'This Privacy Policy describes how we collect, use, process, and disclose your information, '
                  'including personal information, in conjunction with your access to and use of the SecureChat application.'),
              _buildSectionTitle(context, '1. Information We Collect'),
              _buildParagraph(context,
                  'We collect several types of information from and about users of our application, including:'),
              _buildBulletPoint(context,
                  'Personal Identifiers: Email address and username when you create an account.'),
              _buildBulletPoint(context,
                  'Device Information: IP address, device type, operating system version, unique device identifiers.'),
              _buildBulletPoint(context,
                  'Usage Data: How you interact with our application, features you use, and time spent on the platform.'),
              _buildBulletPoint(context,
                  'Communication Data: Messages you send and receive through the application (encrypted end-to-end).'),
              _buildBulletPoint(context,
                  'Digital Keys: Public keys used for end-to-end encryption.'),
              _buildSectionTitle(context, '2. How We Use Your Information'),
              _buildParagraph(context, 'We use the information we collect to:'),
              _buildBulletPoint(
                  context, 'Provide, maintain, and improve our services.'),
              _buildBulletPoint(context,
                  'Process and complete transactions, and send related information.'),
              _buildBulletPoint(context,
                  'Send technical notices, updates, security alerts, and support messages.'),
              _buildBulletPoint(context,
                  'Respond to your comments, questions, and customer service requests.'),
              _buildBulletPoint(context,
                  'Detect, investigate, and prevent fraudulent transactions and other illegal activities.'),
              _buildSectionTitle(context, '3. Blockchain Technology'),
              _buildParagraph(
                  context,
                  'If you provide consent, certain metadata about your communications may be stored using '
                  'blockchain technology. This provides enhanced security and immutability for your data. '
                  'No message content is ever stored on the blockchain, only cryptographic proofs of communication.'),
              _buildParagraph(
                  context,
                  'You can withdraw your consent for blockchain usage at any time through the application settings, '
                  'though this will not affect data already stored on the blockchain.'),
              _buildSectionTitle(context, '4. End-to-End Encryption'),
              _buildParagraph(
                  context,
                  'All messages are encrypted end-to-end, which means they can only be read by the sender and intended '
                  'recipient(s). We do not have access to the content of your communications.'),
              _buildSectionTitle(context, '5. Data Retention'),
              _buildParagraph(
                  context,
                  'We store your information for as long as your account is active or as needed to provide you services. '
                  'If you delete your account, we will delete or anonymize your information within 30 days, except where:'),
              _buildBulletPoint(context,
                  'We are required to maintain certain information for legal purposes.'),
              _buildBulletPoint(context,
                  'Information has been stored on the blockchain with your consent (which is immutable by design).'),
              _buildBulletPoint(context,
                  'Information is necessary to prevent fraud or future abuse.'),
              _buildSectionTitle(context, '6. Your Rights and Choices'),
              _buildParagraph(context,
                  'Depending on your location, you may have certain rights regarding your personal information:'),
              _buildBulletPoint(context,
                  'Access: You can request access to your personal information.'),
              _buildBulletPoint(context,
                  'Correction: You can request that we correct inaccurate information.'),
              _buildBulletPoint(context,
                  'Deletion: You can request deletion of your personal information, subject to certain limitations.'),
              _buildBulletPoint(context,
                  'Objection: You can object to our processing of your personal information.'),
              _buildBulletPoint(context,
                  'Data Portability: You can request a copy of your data in a structured, machine-readable format.'),
              _buildSectionTitle(context, '7. Security'),
              _buildParagraph(
                  context,
                  'We implement appropriate technical and organizational measures to protect your personal information. '
                  'However, no method of transmission over the Internet or electronic storage is 100% secure. '
                  'Therefore, while we strive to protect your personal information, we cannot guarantee absolute security.'),
              _buildSectionTitle(context, '8. Changes to This Privacy Policy'),
              _buildParagraph(
                  context,
                  'We may update this Privacy Policy from time to time. The updated version will be indicated by an updated "Last Updated" date. '
                  'If we make material changes to this Privacy Policy, we will notify you through the application.'),
              _buildSectionTitle(context, '9. Contact Us'),
              _buildParagraph(context,
                  'If you have any questions about this Privacy Policy, please contact us at:'),
              _buildContactBox(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.5,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context, String text) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildParagraph(BuildContext context, String text) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: theme.textTheme.bodyMedium?.color,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: TextStyle(
              fontSize: 14,
              color: theme.textTheme.bodyMedium?.color,
              height: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactBox(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.email_outlined, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'privacy@response.app',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.primary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.business_outlined,
                  size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'VaultX Technologies, Inc.\n123 Encryption Ave, Suite 256\nCyberCity, CA 94321',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
