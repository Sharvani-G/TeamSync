import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

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

  final _localStreamController = StreamController<MediaStream?>.broadcast();
  final _remoteStreamController = StreamController<MediaStream?>.broadcast();

  StreamSubscription<Map<String, dynamic>>? _signalSub;
  final Set<String> _processedCandidates = {};
  bool _remoteDescriptionSet = false;

  Stream<MediaStream?> get onLocalStream => _localStreamController.stream;
  Stream<MediaStream?> get onRemoteStream => _remoteStreamController.stream;

  Future<void> _ensureLocalStream(
      {required bool audio, required bool video}) async {
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
        'createdAt': FieldValue.serverTimestamp(),
      };
      _signal.addCandidate(roomId, payload);
      _socket.emitIceCandidate(roomId, payload);
    };

    pc.onTrack = (event) {
      if (event.streams.isEmpty) return;
      remoteStream = event.streams.first;
      _remoteStreamController.add(remoteStream);
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

    final description = RTCSessionDescription(
      offer['sdp'] as String?,
      offer['type'] as String? ?? 'offer',
    );
    await _pc!.setRemoteDescription(description);
    _remoteDescriptionSet = true;

    final answer = await _pc!
        .createAnswer({'offerToReceiveAudio': 1, 'offerToReceiveVideo': 0});
    await _pc!.setLocalDescription(answer);
    final roomId = _roomId;
    if (roomId == null) return;
    final payload = {
      'sdp': answer.sdp,
      'type': answer.type,
      'senderId': FirebaseAuth.instance.currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
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

    final description = RTCSessionDescription(
      answer['sdp'] as String?,
      answer['type'] as String? ?? 'answer',
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
  }) async {
    _roomId = roomId;
    _role = 'caller';
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
        {'offerToReceiveAudio': 1, 'offerToReceiveVideo': video ? 1 : 0});
    await _pc!.setLocalDescription(offer);
    final payload = {
      'sdp': offer.sdp,
      'type': offer.type,
      'senderId': FirebaseAuth.instance.currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _signal.postOffer(roomId, payload);
    await _socket.emitOffer(roomId, payload);
  }

  Future<void> initAsAnswerer(
    String roomId, {
    bool audio = true,
    bool video = false,
  }) async {
    _roomId = roomId;
    _role = 'answerer';
    await _signal.createRoom(roomId, {
      'active': false,
      'role': 'answerer',
      'answererId': FirebaseAuth.instance.currentUser?.uid ?? '',
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
    if (roomId != null) {
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
