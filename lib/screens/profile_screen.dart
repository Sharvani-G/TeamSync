import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.kBgDeep,
        elevation: 0,
        title: Text('Profile', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<AppUser?>(
        stream: UserProfileService.instance.watchCurrentUser(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) return const Center(child: CircularProgressIndicator());

          return ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(color: AppColors.kBgCard, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.kDivider)),
                child: Row(
                  children: [
                    UserAvatar(name: user.name, username: user.username, size: 50.r, imageUrl: user.photoUrl),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: TextStyle(color: AppColors.kTextPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600)),
                          Text(user.email, style: TextStyle(color: AppColors.kTextSecond, fontSize: 13.sp)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              _ProfileItem(icon: Icons.person_outline, label: 'Edit Profile', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileDetailsScreen()))),
              _ProfileItem(icon: Icons.logout, label: 'Logout', color: AppColors.kDanger, onTap: () => AuthService.instance.signOutAndClearSession()),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ProfileItem({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color ?? AppColors.kTextPrimary, size: 22.sp),
      title: Text(label, style: TextStyle(color: color ?? AppColors.kTextPrimary, fontSize: 15.sp)),
      trailing: Icon(Icons.chevron_right, color: AppColors.kTextSecond, size: 20.sp),
    );
  }
}

class MyProfileDetailsScreen extends StatefulWidget {
  const MyProfileDetailsScreen({super.key});

  @override
  State<MyProfileDetailsScreen> createState() => _MyProfileDetailsScreenState();
}

class _MyProfileDetailsScreenState extends State<MyProfileDetailsScreen> {
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.kBgDeep,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: AppColors.kTextPrimary, size: 20.sp), onPressed: () => Navigator.pop(context)),
        title: Text('Edit Profile', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<AppUser?>(
        stream: UserProfileService.instance.watchCurrentUser(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) return const Center(child: CircularProgressIndicator());
          if (_nameController.text.isEmpty) _nameController.text = user.name;

          return Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Full Name', style: TextStyle(color: AppColors.kTextSecond, fontSize: 13.sp)),
                SizedBox(height: 8.h),
                TextField(
                  controller: _nameController,
                  style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.kBgInput,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: BorderSide.none),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await UserProfileService.instance.updateCurrentUserName(_nameController.text.trim());
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.kAccentBlue, padding: EdgeInsets.symmetric(vertical: 14.h)),
                    child: Text('Save Changes', style: TextStyle(color: AppColors.kWhite, fontSize: 14.sp)),
                  ),
                ),
                SizedBox(height: 32.h),
              ],
            ),
          );
        },
      ),
    );
  }
}
