import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleAppBar(title: 'About'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App Logo & Name
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.groups_outlined,
                        size: 48,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'TeamSync',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Team Collaboration Platform',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Version Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Version Information',
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Version', '1.0.0'),
                    const SizedBox(height: 12),
                    _buildInfoRow('Build', '2024.05.23'),
                    const SizedBox(height: 12),
                    _buildInfoRow('Platform', 'Flutter'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // About Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About TeamSync',
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'TeamSync is a comprehensive team collaboration platform built with Flutter and Firebase. '
                      'It enables teams to manage projects, communicate in real-time, and conduct video calls - '
                      'all in one integrated application.\n\n'
                      'Our mission is to make team collaboration effortless and productive.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Features
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Key Features',
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeature('Project Management', Icons.folder_outlined),
                    const SizedBox(height: 12),
                    _buildFeature('Real-Time Chat', Icons.chat_outlined),
                    const SizedBox(height: 12),
                    _buildFeature('Video Calling', Icons.videocam_outlined),
                    const SizedBox(height: 12),
                    _buildFeature('Collaboration Tools', Icons.groups_outlined),
                    const SizedBox(height: 12),
                    _buildFeature('User Profiles', Icons.person_outlined),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Legal & Links
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms of Service'),
                    trailing: const Icon(Icons.arrow_forward_ios_outlined,
                        size: 16),
                    onTap: () => _launchURL('https://example.com/terms'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.arrow_forward_ios_outlined,
                        size: 16),
                    onTap: () => _launchURL('https://example.com/privacy'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.language_outlined),
                    title: const Text('Website'),
                    trailing: const Icon(Icons.arrow_forward_ios_outlined,
                        size: 16),
                    onTap: () => _launchURL('https://example.com'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Credits
            Card(
              color: const Color(0xFFF9FAFB),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Built with',
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 12),
                    _buildTechStack('Flutter', Icons.flutter_dash_outlined),
                    const SizedBox(height: 8),
                    _buildTechStack('Firebase', Icons.cloud_outlined),
                    const SizedBox(height: 8),
                    _buildTechStack('Dart', Icons.code_outlined),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Footer
            Center(
              child: Column(
                children: [
                  const Text(
                    '© 2024 TeamSync. All rights reserved.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Made with ❤ for teams everywhere',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeature(String name, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(width: 12),
        Text(
          name,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildTechStack(String name, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 12),
        Text(
          name,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
