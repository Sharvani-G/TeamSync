import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/webrtc_client.dart';
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
  final _remoteRenderer = RTCVideoRenderer();
  late final WebRtcClient _client;
  bool _audioEnabled = true;
  bool _videoEnabled = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _client = WebRtcClient();
    _initWebRtc();
  }

  Future<void> _initWebRtc() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('callSessions')
          .doc(widget.callId)
          .get();

      if (!doc.exists) {
        throw Exception('Call session not found');
      }

      final data = doc.data()!;
      final startedBy = data['startedBy'] as String? ?? '';
      final roomName = data['roomName'] as String? ?? widget.callId;
      final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final isCaller = startedBy == myUid;

      _client.onLocalStream.listen((stream) {
        if (mounted) {
          setState(() {
            _localRenderer.srcObject = stream;
          });
        }
      });

      _client.onRemoteStream.listen((stream) {
        if (mounted) {
          setState(() {
            _remoteRenderer.srcObject = stream;
          });
        }
      });

      if (isCaller) {
        await _client.initAsCaller(roomName, audio: _audioEnabled, video: _videoEnabled);
      } else {
        await _client.initAsAnswerer(roomName, audio: _audioEnabled, video: _videoEnabled);
      }

      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error starting WebRTC: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _client.dispose();
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
            child: !_initialized
                ? const Center(child: CircularProgressIndicator())
                : GridView.count(
                    crossAxisCount: 2,
                    padding: EdgeInsets.all(16.w),
                    children: [
                      _VideoTile(label: 'You', renderer: _localRenderer),
                      if (_client.remoteStream != null)
                        _VideoTile(label: 'Collaborator', renderer: _remoteRenderer),
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
                  label: _audioEnabled ? 'Mute' : 'Unmute',
                  onTap: () {
                    final nextVal = !_audioEnabled;
                    _client.mute(!nextVal);
                    setState(() => _audioEnabled = nextVal);
                  },
                ),
                _CallAction(
                  icon: _videoEnabled ? Icons.videocam : Icons.videocam_off,
                  label: 'Video',
                  onTap: () {
                    final nextVal = !_videoEnabled;
                    _client.toggleCamera();
                    setState(() => _videoEnabled = nextVal);
                  },
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
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: RTCVideoView(renderer, mirror: label == 'You', objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
          ),
          Positioned(
            bottom: 8.h,
            left: 8.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                label,
                style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
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
