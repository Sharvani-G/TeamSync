import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Appearance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ValueListenableBuilder(
              valueListenable: SettingsService.instance.themeMode,
              builder: (context, ThemeMode mode, _) {
                final isDark = mode == ThemeMode.dark;
                return SwitchListTile.adaptive(
                  title: const Text('Dark mode'),
                  value: isDark,
                  onChanged: (v) => SettingsService.instance.setDarkMode(v),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text('Language', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ValueListenableBuilder(
              valueListenable: SettingsService.instance.language,
              builder: (context, String lang, _) {
                return DropdownButton<String>(
                  value: lang,
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'es', child: Text('Spanish')),
                  ],
                  onChanged: (val) async {
                    if (val == null) return;
                    await SettingsService.instance.setLanguage(val);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Language updated')));
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
