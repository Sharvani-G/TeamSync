import 'package:flutter/material.dart';

import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ground,
      appBar: const SimpleAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          Text(
            'Notifications & Alerts',
            style: AppTheme.displayFont(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.inkSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: AppTheme.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.rule, width: 1),
            ),
            child: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsService.instance.pushNotificationsEnabled,
                  builder: (context, value, _) {
                    return SwitchListTile(
                      value: value,
                      activeColor: AppTheme.accent,
                      onChanged: SettingsService.instance.setPushNotificationsEnabled,
                      title: Text(
                        'Push notifications',
                        style: AppTheme.bodyFont(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                        ),
                      ),
                      subtitle: Text(
                        'Allow browser and system push alerts on supported devices',
                        style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkSecondary),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, color: AppTheme.rule),
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsService.instance.joinRequestAlertsEnabled,
                  builder: (context, value, _) {
                    return SwitchListTile(
                      value: value,
                      activeColor: AppTheme.accent,
                      onChanged: SettingsService.instance.setJoinRequestAlertsEnabled,
                      title: Text(
                        'Join request alerts',
                        style: AppTheme.bodyFont(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                        ),
                      ),
                      subtitle: Text(
                        'Notify me when collaboration requests arrive for my projects',
                        style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkSecondary),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'More Options',
            style: AppTheme.displayFont(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.inkSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: AppTheme.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.rule, width: 1),
            ),
            child: ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.shield_outlined, color: AppTheme.accent, size: 20),
                ),
              ),
              title: Text(
                'Privacy Settings',
                style: AppTheme.bodyFont(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink,
                ),
              ),
              subtitle: Text(
                'Manage visibility, active status, and read receipts',
                style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkSecondary),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.inkSecondary, size: 20),
              onTap: () => Navigator.pushNamed(context, '/settings/privacy'),
            ),
          ),
        ],
      ),
    );
  }
}
