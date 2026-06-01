import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/project_service.dart';
import '../services/webrtc_environment.dart';
import '../theme/app_colors.dart';

class InCallScreen extends StatefulWidget {
  final String projectId;
  final String callId;
  const InCallScreen({super.key, required this.projectId, required this.callId});

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  MediaStream? _localStream;
  bool _audioEnabled = true;
  bool _videoEnabled = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });
    _localRenderer.srcObject = _localStream;
    setState(() {});
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _localStream?.dispose();
    super.dispose();
  }

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
        title: Text('Video Call', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: EdgeInsets.all(16.w),
              children: [
                _VideoTile(label: 'You', renderer: _localRenderer),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 32.h, left: 16.w, right: 16.w),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 24.w,
              children: [
                _CallAction(
                  icon: _audioEnabled ? Icons.mic : Icons.mic_off,
                  label: 'Mute',
                  onTap: () => setState(() => _audioEnabled = !_audioEnabled),
                ),
                _CallAction(
                  icon: _videoEnabled ? Icons.videocam : Icons.videocam_off,
                  label: 'Video',
                  onTap: () => setState(() => _videoEnabled = !_videoEnabled),
                ),
                _CallAction(
                  icon: Icons.call_end,
                  label: 'End',
                  color: AppColors.kDanger,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final String label;
  final RTCVideoRenderer renderer;
  const _VideoTile({required this.label, required this.renderer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(8.w),
      decoration: BoxDecoration(color: AppColors.kBlack, borderRadius: BorderRadius.circular(12.r)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: RTCVideoView(renderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
      ),
    );
  }
}

class _CallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _CallAction({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56.r,
            height: 56.r,
            decoration: BoxDecoration(color: color ?? AppColors.kBgElevated, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.kWhite, size: 24.sp),
          ),
        ),
        SizedBox(height: 8.h),
        Text(label, style: TextStyle(color: AppColors.kTextSecond, fontSize: 11.sp)),
      ],
    );
  }
}
