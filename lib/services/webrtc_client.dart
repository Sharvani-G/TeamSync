import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'webrtc_signaling_service.dart';

class WebRtcClient {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final WebRtcSignalingService _signal = WebRtcSignalingService();
  RTCPeerConnection? _pc;
  MediaStream? localStream;
  MediaStream? remoteStream;
  final _localStreamController = StreamController<MediaStream?>.broadcast();
  final _remoteStreamController = StreamController<MediaStream?>.broadcast();

  Stream<MediaStream?> get onLocalStream => _localStreamController.stream;
  Stream<MediaStream?> get onRemoteStream => _remoteStreamController.stream;

  final Map<String, dynamic> _processedOffers = {};
  final Map<String, dynamic> _processedAnswers = {};
  final Set<String> _processedCandidates = {};

  String? _roomId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;

  Future<void> _ensureLocalStream({bool audio = true, bool video = true}) async {
    if (localStream != null) return;
    final Map<String, dynamic> mediaConstraints = {
      'audio': audio,
      'video': video
          ? {
              'facingMode': 'user'
            }
          : false,
    };
    try {
      localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localStreamController.add(localStream);
    } catch (e) {
      debugPrint('Failed to getUserMedia: $e');
      rethrow;
    }
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ]
    };
    final pc = await createPeerConnection(config, {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ]
    });

    pc.onIceCandidate = (RTCIceCandidate? candidate) {
      if (candidate == null) return;
      try {
        _signal.addCandidate(_roomId ?? '', {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'senderId': FirebaseAuth.instance.currentUser?.uid ?? ''
        });
      } catch (e) {
        debugPrint('Failed to post ICE candidate: $e');
      }
    };

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams.first;
        _remoteStreamController.add(remoteStream);
      }
    };

    return pc;
  }

  Future<void> initAsCaller(String roomId) async {
    _roomId = roomId;
    await _ensureLocalStream();
    _pc = await _createPeerConnection();

    // Add local tracks
    if (localStream != null) {
      for (final track in localStream!.getTracks()) {
        await _pc!.addTrack(track, localStream!);
      }
    }

    // Listen to room changes for answers and candidates
    _subscribeRoom(roomId);

    // Create offer
    final offer = await _pc!.createOffer({'offerToReceiveAudio': 1, 'offerToReceiveVideo': 1});
    await _pc!.setLocalDescription(offer);

    await _signal.postOffer(roomId, {
      'sdp': offer.sdp,
      'type': offer.type,
      'senderId': FirebaseAuth.instance.currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> initAsAnswerer(String roomId) async {
    _roomId = roomId;
    await _ensureLocalStream();
    _pc = await _createPeerConnection();
    if (localStream != null) {
      for (final track in localStream!.getTracks()) {
        await _pc!.addTrack(track, localStream!);
      }
    }

    _subscribeRoom(roomId);

    // Wait for offers to arrive; will react in _processRoomSnapshot
n  }

  void _subscribeRoom(String roomId) {
    final ref = _db.collection('webrtc_rooms').doc(roomId);
    _roomSub = ref.snapshots().listen((snap) async {
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      await _processOffers(data['offers'] as List<dynamic>? ?? []);
      await _processAnswers(data['answers'] as List<dynamic>? ?? []);
      await _processCandidates(data['candidates'] as List<dynamic>? ?? []);
    });
  }

  Future<void> _processOffers(List<dynamic> offers) async {
    for (final o in offers) {
      final map = Map<String, dynamic>.from(o as Map);
      final key = map['senderId'] ?? map['sdp'] ?? '';
      if (_processedOffers.containsKey(key)) continue;
      // skip offers from self
      if ((map['senderId'] ?? '') == FirebaseAuth.instance.currentUser?.uid) continue;
      _processedOffers[key] = map;

      // If we are answerer, set remote desc and create answer
      if (_pc != null) {
        final desc = RTCSessionDescription(map['sdp'] as String?, map['type'] as String? ?? 'offer');
        await _pc!.setRemoteDescription(desc);
        final answer = await _pc!.createAnswer({'offerToReceiveAudio': 1, 'offerToReceiveVideo': 1});
        await _pc!.setLocalDescription(answer);
        await _signal.postAnswer(_roomId ?? '', {
          'sdp': answer.sdp,
          'type': answer.type,
          'senderId': FirebaseAuth.instance.currentUser?.uid ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> _processAnswers(List<dynamic> answers) async {
    for (final a in answers) {
      final map = Map<String, dynamic>.from(a as Map);
      final key = map['senderId'] ?? map['sdp'] ?? '';
      if (_processedAnswers.containsKey(key)) continue;
      // skip answers from self
      if ((map['senderId'] ?? '') == FirebaseAuth.instance.currentUser?.uid) continue;
      _processedAnswers[key] = map;

      if (_pc != null) {
        final desc = RTCSessionDescription(map['sdp'] as String?, map['type'] as String? ?? 'answer');
        await _pc!.setRemoteDescription(desc);
      }
    }
  }

  Future<void> _processCandidates(List<dynamic> candidates) async {
    for (final c in candidates) {
      final map = Map<String, dynamic>.from(c as Map);
      final id = (map['candidate'] ?? '') + (map['senderId'] ?? '');
      if (_processedCandidates.contains(id)) continue;
      _processedCandidates.add(id);
      if (map['senderId'] == FirebaseAuth.instance.currentUser?.uid) continue;

      final candidate = RTCIceCandidate(map['candidate'] as String?, map['sdpMid'] as String?, map['sdpMLineIndex'] as int?);
      try {
        await _pc?.addCandidate(candidate);
      } catch (e) {
        debugPrint('Failed to add remote candidate: $e');
      }
    }
  }

  Future<void> mute(bool on) async {
    if (localStream == null) return;
    for (final t in localStream!.getAudioTracks()) {
      t.enabled = !on;
    }
  }

  Future<void> toggleCamera() async {
    if (localStream == null) return;
    final videoTracks = localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return;
    final track = videoTracks.first;
    track.enabled = !track.enabled;
  }

  Future<void> dispose() async {
    await _roomSub?.cancel();
    await _pc?.close();
    _pc = null;
    try {
      await localStream?.dispose();
    } catch (_) {}
    try {
      await remoteStream?.dispose();
    } catch (_) {}
    localStream = null;
    remoteStream = null;
    _localStreamController.add(null);
    _remoteStreamController.add(null);
    await _localStreamController.close();
    await _remoteStreamController.close();
  }
}
