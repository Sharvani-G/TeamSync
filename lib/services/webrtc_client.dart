import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'webrtc_environment.dart';
import 'webrtc_signaling_service.dart';
import 'webrtc_socket_service.dart';

class WebRtcClient {
  // Mesh sessions are intentionally capped at 6 participants to keep
  // browser CPU and memory usage predictable during group calls.
  static const int maxGroupParticipants = 6;

  WebRtcClient({WebRtcSignalingService? signalingService})
      : _signal = signalingService ?? WebRtcSignalingService();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final WebRtcSignalingService _signal;
  final WebRtcSocketService _socket = WebRtcSocketService.instance;

  RTCPeerConnection? _pc;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? _roomId;
  String? _role;
  String? _projectId;

  final _localStreamController = StreamController<MediaStream?>.broadcast();
  final _remoteStreamController = StreamController<MediaStream?>.broadcast();

  StreamSubscription<Map<String, dynamic>>? _signalSub;
  final Set<String> _processedCandidates = {};
  bool _remoteDescriptionSet = false;

  Stream<MediaStream?> get onLocalStream => _localStreamController.stream;
  Stream<MediaStream?> get onRemoteStream => _remoteStreamController.stream;

  Future<bool> _requestMediaPermissions({required bool video}) async {
    final statuses = await [
      Permission.microphone,
      if (video) Permission.camera,
    ].request();

    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    final camGranted = !video || (statuses[Permission.camera]?.isGranted ?? false);

    if (!micGranted) {
      debugPrint('[PERMISSIONS] Microphone permission denied');
    }
    if (video && !camGranted) {
      debugPrint('[PERMISSIONS] Camera permission denied');
    }

    return micGranted && camGranted;
  }

  Future<void> _ensureLocalStream(
      {required bool audio, required bool video}) async {
    final micStatus = await Permission.microphone.status;
    debugPrint('[PERMISSIONS] Mic status: $micStatus');

    final granted = await _requestMediaPermissions(video: video);
    if (!granted) {
      throw Exception(
        'Microphone/camera permission denied. Please enable permissions '
        'in your phone settings to use calls.'
      );
    }

    if (localStream != null) return;
    final constraints = <String, dynamic>{
      'audio': audio,
      'video': video
          ? <String, dynamic>{
              'facingMode': 'user',
            }
          : false,
    };
    localStream = await navigator.mediaDevices.getUserMedia(constraints);
    debugPrint('[STREAM] tracks: ${localStream?.getTracks().map((t) => t.kind).toList()}');
    _localStreamController.add(localStream);
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final pc =
        await createPeerConnection(WebRtcEnvironment.peerConnectionConfig);

    pc.onIceCandidate = (candidate) {
      final roomId = _roomId;
      if (roomId == null || candidate.candidate == null) return;
      final payload = {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'senderId': FirebaseAuth.instance.currentUser?.uid ?? '',
        'createdAt': DateTime.now().toIso8601String(),
      };
      _signal.addCandidate(roomId, payload);
      _socket.emitIceCandidate(roomId, payload);
    };

    pc.onTrack = (event) {
      if (event.streams.isEmpty) return;
      debugPrint('[REMOTE TRACK] kind=${event.track.kind} streams=${event.streams.length}');
      debugPrint('[REMOTE] tracks: ${event.streams.first.getTracks().map((t) => t.kind).toList()}');
      remoteStream = event.streams.first;
      _remoteStreamController.add(remoteStream);
    };

    pc.onIceConnectionState = (state) {
      debugPrint('ICE Connection State Changed: $state');
    };

    return pc;
  }

  void _bindSignals() {
    _signalSub?.cancel();
    _signalSub = _socket.signals.listen((payload) async {
      final roomId = _roomId;
      if (roomId == null || payload['roomId']?.toString() != roomId) return;

      final senderId = payload['senderId']?.toString() ??
          payload['fromUserId']?.toString() ??
          '';
      if (senderId.isNotEmpty &&
          senderId == FirebaseAuth.instance.currentUser?.uid) {
        return;
      }

      switch (payload['type']?.toString()) {
        case 'offer':
          await _handleOffer(payload);
          break;
        case 'answer':
          await _handleAnswer(payload);
          break;
        case 'ice-candidate':
          await _handleCandidate(payload);
          break;
        case 'hangup':
          await dispose();
          break;
      }
    });
  }

  Future<void> _primeRoomState(String roomId) async {
    final doc = await _db.collection('webrtc_rooms').doc(roomId).get();
    if (!doc.exists) return;
    final data = doc.data() ?? <String, dynamic>{};
    for (final offerEntry
        in List<dynamic>.from(data['offers'] as List? ?? const [])) {
      await _handleOffer(Map<String, dynamic>.from(offerEntry as Map));
    }
    for (final answerEntry
        in List<dynamic>.from(data['answers'] as List? ?? const [])) {
      await _handleAnswer(Map<String, dynamic>.from(answerEntry as Map));
    }
    for (final candidateEntry
        in List<dynamic>.from(data['candidates'] as List? ?? const [])) {
      await _handleCandidate(Map<String, dynamic>.from(candidateEntry as Map));
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> offer) async {
    final senderId =
        offer['senderId']?.toString() ?? offer['fromUserId']?.toString() ?? '';
    if (senderId.isNotEmpty &&
        senderId == FirebaseAuth.instance.currentUser?.uid) {
      return;
    }
    if (_pc == null || _remoteDescriptionSet) return;

    // Handle both flat {sdp, type} and nested {offer: {sdp, type}}
    final sdpData = offer.containsKey('sdp')
        ? offer
        : (offer['offer'] as Map<dynamic, dynamic>? ?? offer).cast<String, dynamic>();
    final sdpString = sdpData['sdp'] as String?;
    final sdpType = sdpData['type'] as String? ?? 'offer';

    if (sdpString == null || sdpString.isEmpty) {
      debugPrint('[WebRTC] _handleOffer: SDP is null or empty, aborting');
      return;
    }

    if (sdpData.containsKey('projectId')) {
      _projectId = sdpData['projectId'] as String?;
    } else if (offer.containsKey('projectId')) {
      _projectId = offer['projectId'] as String?;
    }

    final description = RTCSessionDescription(sdpString, sdpType);
    await _pc!.setRemoteDescription(description);
    _remoteDescriptionSet = true;

    final answer = await _pc!
        .createAnswer({'offerToReceiveAudio': 1, 'offerToReceiveVideo': 1});
    await _pc!.setLocalDescription(answer);
    final roomId = _roomId;
    if (roomId == null) return;
    final payload = {
      'sdp': answer.sdp,
      'type': answer.type,
      'senderId': FirebaseAuth.instance.currentUser?.uid ?? '',
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _signal.postAnswer(roomId, payload);
    await _socket.emitAnswer(roomId, payload);
  }

  Future<void> _handleAnswer(Map<String, dynamic> answer) async {
    final senderId = answer['senderId']?.toString() ??
        answer['fromUserId']?.toString() ??
        '';
    if (senderId.isNotEmpty &&
        senderId == FirebaseAuth.instance.currentUser?.uid) {
      return;
    }
    if (_pc == null || _remoteDescriptionSet) return;

    final answerData = answer.containsKey('sdp')
        ? answer
        : (answer['answer'] as Map<dynamic, dynamic>? ?? answer).cast<String, dynamic>();
    final sdpString = answerData['sdp'] as String?;
    if (sdpString == null || sdpString.isEmpty) {
      debugPrint('[WebRTC] _handleAnswer: SDP null/empty, aborting');
      return;
    }
    final description = RTCSessionDescription(
      sdpString,
      answerData['type'] as String? ?? 'answer',
    );
    await _pc!.setRemoteDescription(description);
    _remoteDescriptionSet = true;
  }

  Future<void> _handleCandidate(Map<String, dynamic> candidate) async {
    final key =
        '${candidate['candidate'] ?? ''}_${candidate['senderId'] ?? candidate['fromUserId'] ?? ''}';
    if (_processedCandidates.contains(key)) return;
    _processedCandidates.add(key);

    final senderId = candidate['senderId']?.toString() ??
        candidate['fromUserId']?.toString() ??
        '';
    if (senderId.isNotEmpty &&
        senderId == FirebaseAuth.instance.currentUser?.uid) {
      return;
    }
    if (_pc == null) return;

    try {
      await _pc!.addCandidate(
        RTCIceCandidate(
          candidate['candidate'] as String?,
          candidate['sdpMid'] as String?,
          candidate['sdpMLineIndex'] as int?,
        ),
      );
    } catch (error) {
      debugPrint('Failed to add remote candidate: $error');
    }
  }

  Future<void> initAsCaller(
    String roomId, {
    bool audio = true,
    bool video = false,
    required List<String> targetUserIds,
    required String projectId,
    required String projectTitle,
  }) async {
    _roomId = roomId;
    _role = 'caller';
    _projectId = projectId;
    await _signal.createRoom(roomId, {
      'active': true,
      'role': 'caller',
      'callerId': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
    await _socket.bindUser(FirebaseAuth.instance.currentUser?.uid ?? '');
    await _socket.joinRoom(roomId);
    _bindSignals();
    await _ensureLocalStream(audio: audio, video: video);
    _pc = await _createPeerConnection();

    if (localStream != null) {
      for (final track in localStream!.getTracks()) {
        await _pc!.addTrack(track, localStream!);
      }
    }

    final offer = await _pc!.createOffer(
        {'offerToReceiveAudio': 1, 'offerToReceiveVideo': 1});
    await _pc!.setLocalDescription(offer);

    final currentUser = FirebaseAuth.instance.currentUser;
    final payload = {
      'sdp': offer.sdp,
      'type': offer.type,
      'senderId': currentUser?.uid ?? '',
      'callerId': currentUser?.uid ?? '',
      'callerName': currentUser?.displayName ?? 'Someone',
      'createdAt': DateTime.now().toIso8601String(),
      'targetUids': targetUserIds, // pass in from caller, exclude self
      'projectId': projectId,
      'projectName': projectTitle,
      'roomId': roomId,
    };
    await _signal.postOffer(roomId, payload);
    await _socket.emitOffer(roomId, payload);
  }

  Future<void> initAsAnswerer(
    String roomId, {
    bool audio = true,
    bool video = false,
    String? projectId,
  }) async {
    _roomId = roomId;
    _role = 'answerer';
    _projectId = projectId;
    await _signal.createRoom(roomId, {
      'active': false,
      'role': 'answerer',
      'answererId': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
    await _socket.bindUser(FirebaseAuth.instance.currentUser?.uid ?? '');
    _bindSignals();
    await _ensureLocalStream(audio: audio, video: video);
    _pc = await _createPeerConnection();

    if (localStream != null) {
      for (final track in localStream!.getTracks()) {
        await _pc!.addTrack(track, localStream!);
      }
    }

    // Join the signaling room FIRST so ICE candidates and answers 
    // can flow back to the caller
    await _socket.joinRoom(roomId);
    await Future.delayed(const Duration(milliseconds: 300));

    await _primeRoomState(roomId);
  }

  Future<void> mute(bool on) async {
    final stream = localStream;
    if (stream == null) return;
    for (final track in stream.getAudioTracks()) {
      track.enabled = !on;
    }
  }

  Future<void> toggleCamera() async {
    final stream = localStream;
    if (stream == null) return;
    for (final track in stream.getVideoTracks()) {
      track.enabled = !track.enabled;
    }
  }

  Future<void> hangup() async {
    final roomId = _roomId;
    final projectId = _projectId;
    if (roomId != null) {
      if (projectId != null) {
        await _db
            .collection('projects')
            .doc(projectId)
            .collection('callSessions')
            .doc(roomId)
            .update({'status': 'ended'}).catchError((_) {});
      }
      await _socket.hangup(roomId);
      await _socket.leaveRoom(roomId);
      await _signal.leaveRoom(roomId).catchError((_) {});
    }
  }

  Future<void> dispose() async {
    await _signalSub?.cancel();
    _signalSub = null;
    await hangup();
    await _pc?.close();
    _pc = null;
    _roomId = null;
    _role = null;
    _remoteDescriptionSet = false;
    try {
      await localStream?.dispose();
    } catch (_) {}
    try {
      await remoteStream?.dispose();
    } catch (_) {}
    localStream = null;
    remoteStream = null;
    if (!_localStreamController.isClosed) {
      await _localStreamController.close();
    }
    if (!_remoteStreamController.isClosed) {
      await _remoteStreamController.close();
    }
  }
}
