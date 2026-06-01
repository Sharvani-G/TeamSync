import 'package:flutter/material.dart';

import '../../services/settings_service.dart';

class PrivacySettingsPage extends StatelessWidget {
  const PrivacySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: SettingsService.instance.profilePrivate,
            builder: (context, value, _) {
              return SwitchListTile(
                value: value,
                onChanged: SettingsService.instance.setProfilePrivate,
                title: const Text('Private profile', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Restrict profile visibility to collaborators', style: TextStyle(color: Colors.white70)),
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: SettingsService.instance.onlineStatusVisible,
            builder: (context, value, _) {
              return SwitchListTile(
                value: value,
                onChanged: SettingsService.instance.setOnlineStatusVisible,
                title: const Text('Show online status', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Let teammates see when you are active', style: TextStyle(color: Colors.white70)),
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: SettingsService.instance.readReceiptsEnabled,
            builder: (context, value, _) {
              return SwitchListTile(
                value: value,
                onChanged: SettingsService.instance.setReadReceiptsEnabled,
                title: const Text('Read receipts', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Mark messages as read for collaborators', style: TextStyle(color: Colors.white70)),
              );
            },
          ),
        ],
      ),
    );
  }
}