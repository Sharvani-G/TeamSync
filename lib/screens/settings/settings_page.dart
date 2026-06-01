import 'package:flutter/material.dart';

import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBgDeep,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('Appearance'),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: SettingsService.instance.themeMode,
            builder: (context, mode, _) {
              final isDark = mode == ThemeMode.dark;
              return SwitchListTile(
                value: isDark,
                onChanged: SettingsService.instance.setDarkMode,
                title: const Text('Dark mode'),
                subtitle: const Text('Use a darker theme across TeamSync'),
              );
            },
          ),
          const SizedBox(height: 8),
          _SectionTitle('Notifications'),
          ValueListenableBuilder<bool>(
            valueListenable: SettingsService.instance.pushNotificationsEnabled,
            builder: (context, value, _) {
              return SwitchListTile(
                value: value,
                onChanged: SettingsService.instance.setPushNotificationsEnabled,
                title: const Text('Push notifications'),
                subtitle: const Text('Allow push alerts on supported devices'),
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: SettingsService.instance.joinRequestAlertsEnabled,
            builder: (context, value, _) {
              return SwitchListTile(
                value: value,
                onChanged: SettingsService.instance.setJoinRequestAlertsEnabled,
                title: const Text('Join request alerts'),
                subtitle: const Text('Notify me when collaboration requests arrive'),
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: SettingsService.instance.emailDigestEnabled,
            builder: (context, value, _) {
              return SwitchListTile(
                value: value,
                onChanged: SettingsService.instance.setEmailDigestEnabled,
                title: const Text('Weekly digest'),
                subtitle: const Text('Receive a weekly summary email'),
              );
            },
          ),
          const SizedBox(height: 8),
          _SectionTitle('Privacy'),
          ListTile(
            title: const Text('Privacy settings'),
            subtitle: const Text('Control visibility and activity sharing'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/settings/privacy'),
          ),
          const SizedBox(height: 8),
          _SectionTitle('Language'),
          DropdownButtonFormField<String>(
            initialValue: SettingsService.instance.language.value,
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'es', child: Text('Spanish')),
              DropdownMenuItem(value: 'fr', child: Text('French')),
            ],
            onChanged: (value) {
              if (value != null) {
                SettingsService.instance.setLanguage(value);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}