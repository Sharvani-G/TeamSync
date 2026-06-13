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
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.kBgDeep,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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