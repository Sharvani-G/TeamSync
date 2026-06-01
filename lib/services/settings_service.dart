import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _keyDarkMode = 'settings_dark_mode';
  static const _keyLanguage = 'settings_language';
  static const _keyPushNotifications = 'settings_push_notifications';
  static const _keyJoinRequestAlerts = 'settings_join_request_alerts';
  static const _keyEmailDigest = 'settings_email_digest';
  static const _keyProfilePrivate = 'settings_profile_private';
  static const _keyOnlineStatusVisible = 'settings_online_status_visible';
  static const _keyReadReceipts = 'settings_read_receipts';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.dark);
  final ValueNotifier<String> language = ValueNotifier('en');
  final ValueNotifier<bool> pushNotificationsEnabled = ValueNotifier(true);
  final ValueNotifier<bool> joinRequestAlertsEnabled = ValueNotifier(true);
  final ValueNotifier<bool> emailDigestEnabled = ValueNotifier(false);
  final ValueNotifier<bool> profilePrivate = ValueNotifier(false);
  final ValueNotifier<bool> onlineStatusVisible = ValueNotifier(true);
  final ValueNotifier<bool> readReceiptsEnabled = ValueNotifier(true);

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

    pushNotificationsEnabled.value = _prefs?.getBool(_keyPushNotifications) ?? true;
    joinRequestAlertsEnabled.value = _prefs?.getBool(_keyJoinRequestAlerts) ?? true;
    emailDigestEnabled.value = _prefs?.getBool(_keyEmailDigest) ?? false;
    profilePrivate.value = _prefs?.getBool(_keyProfilePrivate) ?? false;
    onlineStatusVisible.value = _prefs?.getBool(_keyOnlineStatusVisible) ?? true;
    readReceiptsEnabled.value = _prefs?.getBool(_keyReadReceipts) ?? true;
  }

  Future<void> setDarkMode(bool enabled) async {
    themeMode.value = enabled ? ThemeMode.dark : ThemeMode.light;
    await _prefs?.setBool(_keyDarkMode, enabled);
  }

  Future<void> setLanguage(String langCode) async {
    language.value = langCode;
    await _prefs?.setString(_keyLanguage, langCode);
  }

  Future<void> setPushNotificationsEnabled(bool enabled) async {
    pushNotificationsEnabled.value = enabled;
    await _prefs?.setBool(_keyPushNotifications, enabled);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
        'pushNotificationsEnabled': enabled,
      }, SetOptions(merge: true));
    }
  }

  Future<void> setJoinRequestAlertsEnabled(bool enabled) async {
    joinRequestAlertsEnabled.value = enabled;
    await _prefs?.setBool(_keyJoinRequestAlerts, enabled);
  }

  Future<void> setEmailDigestEnabled(bool enabled) async {
    emailDigestEnabled.value = enabled;
    await _prefs?.setBool(_keyEmailDigest, enabled);
  }

  Future<void> setProfilePrivate(bool enabled) async {
    profilePrivate.value = enabled;
    await _prefs?.setBool(_keyProfilePrivate, enabled);
  }

  Future<void> setOnlineStatusVisible(bool enabled) async {
    onlineStatusVisible.value = enabled;
    await _prefs?.setBool(_keyOnlineStatusVisible, enabled);
  }

  Future<void> setReadReceiptsEnabled(bool enabled) async {
    readReceiptsEnabled.value = enabled;
    await _prefs?.setBool(_keyReadReceipts, enabled);
  }
}
