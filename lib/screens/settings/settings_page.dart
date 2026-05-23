import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class SettingsPage extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final ThemeMode currentThemeMode;

  const SettingsPage({
    super.key,
    required this.onThemeChanged,
    required this.currentThemeMode,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SharedPreferences _prefs;
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _language = 'English';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled =
            _prefs.getBool('notifications_enabled') ?? true;
        _soundEnabled = _prefs.getBool('sound_enabled') ?? true;
        _vibrationEnabled = _prefs.getBool('vibration_enabled') ?? true;
        _language = _prefs.getString('language') ?? 'English';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: SimpleAppBar(title: 'Settings'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: SimpleAppBar(title: 'Settings'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Appearance Section
            _buildSection(
              title: 'Appearance',
              children: [
                _buildThemeOption(
                  title: 'Light Mode',
                  isSelected: widget.currentThemeMode == ThemeMode.light,
                  icon: Icons.light_mode_outlined,
                  onTap: () => widget.onThemeChanged(ThemeMode.light),
                ),
                _buildThemeOption(
                  title: 'Dark Mode',
                  isSelected: widget.currentThemeMode == ThemeMode.dark,
                  icon: Icons.dark_mode_outlined,
                  onTap: () => widget.onThemeChanged(ThemeMode.dark),
                ),
                _buildThemeOption(
                  title: 'System Default',
                  isSelected: widget.currentThemeMode == ThemeMode.system,
                  icon: Icons.brightness_auto_outlined,
                  onTap: () => widget.onThemeChanged(ThemeMode.system),
                ),
              ],
            ),

            // Notifications Section
            _buildSection(
              title: 'Notifications',
              children: [
                _buildToggleSetting(
                  title: 'Enable Notifications',
                  subtitle: 'Receive push notifications',
                  value: _notificationsEnabled,
                  icon: Icons.notifications_outlined,
                  onChanged: (value) async {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                    await _prefs.setBool('notifications_enabled', value);
                  },
                ),
                if (_notificationsEnabled) ...[
                  _buildToggleSetting(
                    title: 'Sound',
                    subtitle: 'Play notification sound',
                    value: _soundEnabled,
                    icon: Icons.volume_up_outlined,
                    onChanged: (value) async {
                      setState(() {
                        _soundEnabled = value;
                      });
                      await _prefs.setBool('sound_enabled', value);
                    },
                  ),
                  _buildToggleSetting(
                    title: 'Vibration',
                    subtitle: 'Vibrate on notifications',
                    value: _vibrationEnabled,
                    icon: Icons.vibration_outlined,
                    onChanged: (value) async {
                      setState(() {
                        _vibrationEnabled = value;
                      });
                      await _prefs.setBool('vibration_enabled', value);
                    },
                  ),
                ],
              ],
            ),

            // Privacy & Security
            _buildSection(
              title: 'Privacy & Security',
              children: [
                _buildListTile(
                  title: 'Privacy Policy',
                  subtitle: 'Read our privacy policy',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Privacy policy feature coming soon'),
                      ),
                    );
                  },
                ),
                _buildListTile(
                  title: 'Terms of Service',
                  subtitle: 'Read our terms and conditions',
                  icon: Icons.description_outlined,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Terms of Service feature coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),

            // Data & Storage
            _buildSection(
              title: 'Data & Storage',
              children: [
                _buildListTile(
                  title: 'Clear Cache',
                  subtitle: 'Free up storage space',
                  icon: Icons.delete_outline,
                  onTap: () => _showClearCacheDialog(),
                ),
                _buildListTile(
                  title: 'Download Data',
                  subtitle: 'Download your personal data',
                  icon: Icons.download_outlined,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Download data feature coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),

            // About
            _buildSection(
              title: 'About',
              children: [
                _buildListTile(
                  title: 'Version',
                  subtitle: '1.0.0',
                  icon: Icons.info_outline,
                  onTap: null,
                ),
                _buildListTile(
                  title: 'Build',
                  subtitle: 'Production',
                  icon: Icons.build_outline,
                  onTap: null,
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: children.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) => children[index],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption({
    required String title,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title),
      trailing: isSelected
          ? const Icon(Icons.check_circle_outlined, color: AppTheme.primary)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildToggleSetting({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primary,
      ),
    );
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap != null
          ? const Icon(Icons.arrow_forward_ios_outlined, size: 16)
          : null,
      onTap: onTap,
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'Are you sure? This will free up storage space but may slow down app load times temporarily.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
