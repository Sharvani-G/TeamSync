import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';

class IncomingCallOverlayScreen extends StatefulWidget {
  final String callerName;
  final String projectTitle;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallOverlayScreen({
    super.key,
    required this.callerName,
    required this.projectTitle,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<IncomingCallOverlayScreen> createState() => _IncomingCallOverlayScreenState();
}

class _IncomingCallOverlayScreenState extends State<IncomingCallOverlayScreen> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _dismissTimer = Timer(const Duration(seconds: 45), () {
      widget.onDecline();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.85),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60.r,
              backgroundColor: AppColors.kAccentBlue,
              child: Text(
                widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : '?',
                style: TextStyle(color: Colors.white, fontSize: 40.sp, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              '${widget.callerName} is calling',
              style: TextStyle(color: Colors.white, fontSize: 24.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8.h),
            Text(
              'From ${widget.projectTitle}',
              style: TextStyle(color: AppColors.kTextSecond, fontSize: 16.sp),
            ),
            SizedBox(height: 40.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CallActionBtn(
                  icon: Icons.call_end,
                  color: Colors.red,
                  label: 'Decline',
                  onTap: widget.onDecline,
                ),
                SizedBox(width: 40.w),
                _CallActionBtn(
                  icon: Icons.phone,
                  color: Colors.green,
                  label: 'Join',
                  onTap: widget.onAccept,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CallActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _CallActionBtn({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 70.w,
            height: 70.w,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, spreadRadius: 2),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32.sp),
          ),
        ),
        SizedBox(height: 12.h),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 13.sp)),
      ],
    );
  }
}
