import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/webrtc_client.dart';
import '../services/webrtc_socket_service.dart';
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
  bool _videoEnabled = true;
  bool _initialized = false;
  bool _cameraOn = true;
  bool _micOn = true;
  String? _roomName;

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
      _roomName = roomName;
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
        if (!mounted) return;
        setState(() {
          _remoteRenderer.srcObject = stream;
        });
      });

      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .get();
      final projectData = projectDoc.data() ?? {};
      final projectTitle = projectData['title'] as String? ?? 'Project';
      final collaboratorsMap = projectData['collaborators'] as Map<dynamic, dynamic>? ?? {};
      final createdBy = projectData['createdBy'] as String? ?? '';
      final teamMembers = <String>{
        createdBy,
        ...collaboratorsMap.keys.map((k) => k.toString()),
      };

      final invitedParticipantsRaw = data['invitedParticipants'] as List<dynamic>? ?? [];
      final List<String> invitedParticipants = invitedParticipantsRaw.isNotEmpty
          ? invitedParticipantsRaw.map((e) => e.toString()).toList()
          : teamMembers.toList();

      final targets = invitedParticipants
          .where((uid) => uid != myUid)
          .toList();

      if (isCaller) {
        await _client.initAsCaller(
          roomName,
          audio: _audioEnabled,
          video: _videoEnabled,
          targetUserIds: targets,
          projectId: widget.projectId,
          projectTitle: projectTitle,
        );
      } else {
        await _client.initAsAnswerer(
          roomName,
          audio: _audioEnabled,
          video: _videoEnabled,
          projectId: widget.projectId,
        );
      }

      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error starting WebRTC: $e');
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Permission Required'),
            content: Text('$e'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // go back
                  openAppSettings(); // from permission_handler
                },
                child: const Text('Open Settings'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // go back
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _endCall() async {
    try {
      _client.localStream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}
    final rName = _roomName;
    if (rName != null) {
      try {
        await WebRtcSocketService.instance.emitEndCall(rName);
      } catch (_) {}
    }
    try {
      await _client.dispose();
    } catch (_) {}
    if (mounted) {
      Navigator.pop(context);
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
          onPressed: _endCall,
        ),
        title: Text('Video Call', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Expanded(
            child: !_initialized
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      // Remote Stream (Full Screen Tile)
                      Positioned.fill(
                        child: RTCVideoView(
                          _remoteRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                      // Local Stream (Small Floating Preview Tile)
                      if (_cameraOn && _client.localStream != null)
                        Positioned(
                          bottom: 16,
                          right: 16,
                          width: 100,
                          height: 140,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: RTCVideoView(
                                _localRenderer,
                                mirror: true,
                                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 32.h, left: 16.w, right: 16.w),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 20.w,
              children: [
                _CallAction(
                  icon: _micOn ? Icons.mic : Icons.mic_off,
                  label: _micOn ? 'Mute' : 'Unmute',
                  onTap: () {
                    final audioTrack = _client.localStream
                        ?.getAudioTracks().isNotEmpty == true
                        ? _client.localStream!.getAudioTracks().first
                        : null;
                    if (audioTrack != null) {
                      audioTrack.enabled = !audioTrack.enabled;
                      setState(() => _micOn = audioTrack.enabled);
                    }
                  },
                ),
                _CallAction(
                  icon: _cameraOn ? Icons.videocam : Icons.videocam_off,
                  label: 'Video',
                  onTap: () {
                    final videoTrack = _client.localStream
                        ?.getVideoTracks().isNotEmpty == true
                        ? _client.localStream!.getVideoTracks().first
                        : null;
                    if (videoTrack != null) {
                      videoTrack.enabled = !videoTrack.enabled;
                      setState(() => _cameraOn = videoTrack.enabled);
                    }
                  },
                ),
                _CallAction(
                  icon: Icons.flip_camera_ios,
                  label: 'Switch',
                  onTap: () async {
                    final videoTrack = _client.localStream
                        ?.getVideoTracks().isNotEmpty == true
                        ? _client.localStream!.getVideoTracks().first
                        : null;
                    if (videoTrack != null) {
                      await Helper.switchCamera(videoTrack);
                    }
                  },
                ),
                _CallAction(
                  icon: Icons.call_end,
                  label: 'End',
                  color: AppColors.kDanger,
                  onTap: _endCall,
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
