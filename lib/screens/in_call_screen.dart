import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/webrtc_client.dart';
import '../services/webrtc_socket_service.dart';
import '../theme/app_theme.dart';

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
            title: Text('Permission Required', style: AppTheme.displayFont(fontSize: 18, fontWeight: FontWeight.w700)),
            content: Text('$e', style: AppTheme.bodyFont(fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: Text('Open Settings', style: AppTheme.bodyFont(color: AppTheme.accent, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text('Cancel', style: AppTheme.bodyFont(color: AppTheme.inkSecondary)),
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
      backgroundColor: AppTheme.field,
      appBar: AppBar(
        backgroundColor: AppTheme.field,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: _endCall,
        ),
        title: Text(
          'Video Call',
          style: AppTheme.displayFont(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: !_initialized
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
                          bottom: 20,
                          right: 20,
                          width: 110,
                          height: 155,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
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
          // Call Control Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: const BoxDecoration(
              color: AppTheme.field,
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CallAction(
                  icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                  label: _micOn ? 'Mute' : 'Unmute',
                  onTap: () {
                    final audioTrack = _client.localStream?.getAudioTracks().isNotEmpty == true
                        ? _client.localStream!.getAudioTracks().first
                        : null;
                    if (audioTrack != null) {
                      audioTrack.enabled = !audioTrack.enabled;
                      setState(() => _micOn = audioTrack.enabled);
                    }
                  },
                ),
                _CallAction(
                  icon: _cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                  label: _cameraOn ? 'Camera On' : 'Camera Off',
                  onTap: () {
                    final videoTrack = _client.localStream?.getVideoTracks().isNotEmpty == true
                        ? _client.localStream!.getVideoTracks().first
                        : null;
                    if (videoTrack != null) {
                      videoTrack.enabled = !videoTrack.enabled;
                      setState(() => _cameraOn = videoTrack.enabled);
                    }
                  },
                ),
                _CallAction(
                  icon: Icons.flip_camera_ios_rounded,
                  label: 'Switch',
                  onTap: () async {
                    final videoTrack = _client.localStream?.getVideoTracks().isNotEmpty == true
                        ? _client.localStream!.getVideoTracks().first
                        : null;
                    if (videoTrack != null) {
                      await Helper.switchCamera(videoTrack);
                    }
                  },
                ),
                _CallAction(
                  icon: Icons.call_end_rounded,
                  label: 'End Call',
                  color: AppTheme.danger,
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

class _CallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _CallAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color ?? Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTheme.bodyFont(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
