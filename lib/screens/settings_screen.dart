import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.kBgDeep,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.kTextPrimary, size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Settings', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _SettingsTile(
            title: 'Account Settings',
            subtitle: 'Manage your profile and security',
            icon: Icons.person_outline,
            onTap: () {},
          ),
          Divider(color: AppColors.kDivider, height: 1),
          _SettingsTile(
            title: 'Notifications',
            subtitle: 'Configure how you receive alerts',
            icon: Icons.notifications_none,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SettingsTile({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(vertical: 8.h),
      leading: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(color: AppColors.kBgCard, borderRadius: BorderRadius.circular(8.r)),
        child: Icon(icon, color: AppColors.kAccentLight, size: 22.sp),
      ),
      title: Text(title, style: TextStyle(color: AppColors.kTextPrimary, fontSize: 15.sp, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: AppColors.kTextSecond, fontSize: 13.sp)),
      trailing: Icon(Icons.chevron_right, color: AppColors.kTextHint, size: 20.sp),
    );
  }
}
