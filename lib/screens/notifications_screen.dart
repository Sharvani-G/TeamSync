import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.kBgDeep,
        elevation: 0,
        title: Text('Notifications', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<List<ProjectNotificationItem>>(
        stream: ProjectService.instance.watchMyNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) return Center(child: Text('No notifications', style: TextStyle(color: AppColors.kTextSecond, fontSize: 14.sp)));

          return ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => Divider(color: AppColors.kDivider, height: 1),
            itemBuilder: (context, index) {
              final n = notifications[index];
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.title, style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500)),
                          SizedBox(height: 4.h),
                          Text(n.body, style: TextStyle(color: AppColors.kTextSecond, fontSize: 13.sp)),
                          SizedBox(height: 4.h),
                          Text('${n.createdAt.month}/${n.createdAt.day}', style: TextStyle(color: AppColors.kTextHint, fontSize: 11.sp)),
                        ],
                      ),
                    ),
                    if (n.read != true)
                      Container(width: 8.r, height: 8.r, decoration: const BoxDecoration(color: AppColors.kAccentBlue, shape: BoxShape.circle)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
