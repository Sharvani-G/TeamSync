import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _keyDarkMode = 'settings_dark_mode';
  static const _keyLanguage = 'settings_language';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.dark);
  final ValueNotifier<String> language = ValueNotifier('en');

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final dark = _prefs?.getBool(_keyDarkMode);
    final lang = _prefs?.getString(_keyLanguage);

    if (dark != null) {
      themeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
    }

    if (lang != null && lang.isNotEmpty) {
      language.value = lang;
    }
  }

  Future<void> setDarkMode(bool enabled) async {
    themeMode.value = enabled ? ThemeMode.dark : ThemeMode.light;
    await _prefs?.setBool(_keyDarkMode, enabled);
  }

  Future<void> setLanguage(String langCode) async {
    language.value = langCode;
    await _prefs?.setString(_keyLanguage, langCode);
  }
}
