import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/project_service.dart';
import '../services/webrtc_environment.dart';
import '../theme/app_theme.dart';

class InCallScreen extends StatefulWidget {
  final String projectId;
  final String callId;

  const InCallScreen(
      {super.key, required this.projectId, required this.callId});

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final List<StreamSubscription> _subscriptions = [];

  MediaStream? _localStream;
  String? _myId;
  bool _ready = false;
  bool _audioEnabled = true;
  bool _videoEnabled = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _localRenderer.initialize();
    _myId = _auth.currentUser?.uid;
    await _loadCallPreferences();
    await _startCallFlow();
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  Future<void> _loadCallPreferences() async {
    final callDoc = await _firestore
        .collection('projects')
        .doc(widget.projectId)
        .collection('callSessions')
        .doc(widget.callId)
        .get();
    final data = callDoc.data();
    if (data == null) return;
    _audioEnabled = data['audioEnabled'] as bool? ?? true;
    _videoEnabled = data['videoEnabled'] as bool? ?? false;
  }

  Future<void> _startCallFlow() async {
    await _initLocalMedia();
    await ProjectService.instance.joinProjectCall(
      projectId: widget.projectId,
      callId: widget.callId,
    );
    _watchParticipants();
  }

  Future<void> _initLocalMedia() async {
    _localStream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
      'audio': _audioEnabled,
      'video': _videoEnabled ? <String, dynamic>{'facingMode': 'user'} : false,
    });
    _localRenderer.srcObject = _localStream;
  }

  void _watchParticipants() {
    final callRef = _firestore
        .collection('projects')
        .doc(widget.projectId)
        .collection('callSessions')
        .doc(widget.callId);

    _subscriptions.add(callRef.snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) return;
      final participants = List<String>.from(
          (data['participants'] as List? ?? []).cast<String>());
      await _syncPeerConnections(participants);
    }));
  }

  Future<void> _syncPeerConnections(List<String> participants) async {
    final me = _myId;
    if (me == null) return;

    // Mesh topology for group calls. Cap the browser mesh at 6 participants
    // so the call stays responsive in real-world web sessions.
    final visibleParticipants = participants
        .where((participantId) => participantId != me)
        .take(6)
        .toList();

    for (final participantId in visibleParticipants) {
      if (_peerConnections.containsKey(participantId)) continue;
      await _createPeerConnection(participantId);
    }
  }

  Future<RTCPeerConnection> _createPeerConnection(String remoteId) async {
    final pc =
        await createPeerConnection(WebRtcEnvironment.peerConnectionConfig);

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    final remoteRenderer = RTCVideoRenderer();
    await remoteRenderer.initialize();
    _remoteRenderers[remoteId] = remoteRenderer;

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
        if (mounted) setState(() {});
      }
    };

    final signalingDoc = _firestore
        .collection('projects')
        .doc(widget.projectId)
        .collection('callSessions')
        .doc(widget.callId)
        .collection('signaling')
        .doc(_signalDocId(remoteId));

    pc.onIceCandidate = (candidate) async {
      await signalingDoc.collection('candidates').add({
        'from': _myId,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'createdAt': Timestamp.now(),
      });
    };

    _peerConnections[remoteId] = pc;
    _wireSignaling(remoteId, pc);

    if ((_myId ?? '').compareTo(remoteId) < 0) {
      await _sendOffer(remoteId, pc);
    }

    return pc;
  }

  void _wireSignaling(String remoteId, RTCPeerConnection pc) {
    final signalingBase = _firestore
        .collection('projects')
        .doc(widget.projectId)
        .collection('callSessions')
        .doc(widget.callId)
        .collection('signaling');

    final localDoc = signalingBase.doc(_signalDocId(remoteId));
    final remoteDoc = signalingBase.doc(_signalDocId(_myId ?? '', remoteId));

    _subscriptions.add(localDoc.snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) return;
      final answer = data['answer'];
      if (answer is Map<String, dynamic>) {
        await pc.setRemoteDescription(
          RTCSessionDescription(
              answer['sdp'] as String?, answer['type'] as String?),
        );
      }
    }));

    _subscriptions.add(remoteDoc.snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) return;
      final offer = data['offer'];
      if (offer is Map<String, dynamic>) {
        final description = RTCSessionDescription(
          offer['sdp'] as String?,
          offer['type'] as String?,
        );
        await pc.setRemoteDescription(description);
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        await remoteDoc.set({
          'answer': {'type': answer.type, 'sdp': answer.sdp},
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));
      }
    }));

    _subscriptions.add(
        remoteDoc.collection('candidates').snapshots().listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null || data['from'] == _myId) continue;
        await pc.addCandidate(
          RTCIceCandidate(
            data['candidate'] as String?,
            data['sdpMid'] as String?,
            data['sdpMLineIndex'] as int?,
          ),
        );
      }
    }));

    _subscriptions.add(
        localDoc.collection('candidates').snapshots().listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null || data['from'] == _myId) continue;
        await pc.addCandidate(
          RTCIceCandidate(
            data['candidate'] as String?,
            data['sdpMid'] as String?,
            data['sdpMLineIndex'] as int?,
          ),
        );
      }
    }));
  }

  Future<void> _sendOffer(String remoteId, RTCPeerConnection pc) async {
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    final localDoc = _firestore
        .collection('projects')
        .doc(widget.projectId)
        .collection('callSessions')
        .doc(widget.callId)
        .collection('signaling')
        .doc(_signalDocId(remoteId));

    await localDoc.set({
      'from': _myId,
      'to': remoteId,
      'offer': {'type': offer.type, 'sdp': offer.sdp},
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  String _signalDocId(String remoteId, [String? localId]) {
    final me = localId ?? _myId ?? '';
    return me.compareTo(remoteId) < 0 ? '${me}_$remoteId' : '${remoteId}_$me';
  }

  Future<void> _toggleTrack(bool audio) async {
    final stream = _localStream;
    if (stream == null) return;

    final tracks = audio ? stream.getAudioTracks() : stream.getVideoTracks();
    if (tracks.isEmpty) return;
    tracks.first.enabled = !tracks.first.enabled;
    if (mounted) setState(() {});
  }

  Future<void> _leave() async {
    await ProjectService.instance.leaveProjectCall(
      projectId: widget.projectId,
      callId: widget.callId,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    for (final pc in _peerConnections.values) {
      pc.close();
    }
    for (final renderer in _remoteRenderers.values) {
      renderer.dispose();
    }
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Call'),
        backgroundColor: AppTheme.primary,
        actions: [
          IconButton(
            onPressed: _leave,
            icon: const Icon(Icons.call_end),
          ),
        ],
      ),
      body: _ready
          ? Column(
              children: [
                Expanded(
                  child: GridView.count(
                    crossAxisCount: _remoteRenderers.isEmpty ? 1 : 2,
                    padding: const EdgeInsets.all(12),
                    children: [
                      _videoTile(
                        label: 'You',
                        child: RTCVideoView(_localRenderer, mirror: true),
                      ),
                      ..._remoteRenderers.entries.map(
                        (entry) => _videoTile(
                          label: entry.key,
                          child: RTCVideoView(entry.value),
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _actionButton(
                            Icons.mic, 'Mute', () => _toggleTrack(true)),
                        _actionButton(
                            Icons.videocam, 'Video', () => _toggleTrack(false)),
                        _actionButton(Icons.call_end, 'End', _leave,
                            destructive: true),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _videoTile({required String label, required Widget child}) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onPressed,
      {bool destructive = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor:
              destructive ? const Color(0xFFDC2626) : AppTheme.primary,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
