import 'package:flutter/material.dart';

import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class PrivacySettingsPage extends StatelessWidget {
  const PrivacySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ground,
      appBar: const SimpleAppBar(title: 'Privacy'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          Text(
            'Presence & Visibility',
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
                  valueListenable: SettingsService.instance.profilePrivate,
                  builder: (context, value, _) {
                    return SwitchListTile(
                      value: value,
                      activeColor: AppTheme.accent,
                      onChanged: SettingsService.instance.setProfilePrivate,
                      title: Text(
                        'Private profile',
                        style: AppTheme.bodyFont(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                        ),
                      ),
                      subtitle: Text(
                        'Restrict profile contact information to confirmed collaborators',
                        style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkSecondary),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, color: AppTheme.rule),
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsService.instance.onlineStatusVisible,
                  builder: (context, value, _) {
                    return SwitchListTile(
                      value: value,
                      activeColor: AppTheme.accent,
                      onChanged: SettingsService.instance.setOnlineStatusVisible,
                      title: Text(
                        'Show online status',
                        style: AppTheme.bodyFont(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                        ),
                      ),
                      subtitle: Text(
                        'Let team members see an active dot when you are online in channels',
                        style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkSecondary),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, color: AppTheme.rule),
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsService.instance.readReceiptsEnabled,
                  builder: (context, value, _) {
                    return SwitchListTile(
                      value: value,
                      activeColor: AppTheme.accent,
                      onChanged: SettingsService.instance.setReadReceiptsEnabled,
                      title: Text(
                        'Read receipts',
                        style: AppTheme.bodyFont(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                        ),
                      ),
                      subtitle: Text(
                        'Send seen indicators when reading direct and channel messages',
                        style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkSecondary),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
