import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'webrtc_environment.dart';

class WebRtcSocketService {
  WebRtcSocketService._();

  static final WebRtcSocketService instance = WebRtcSocketService._();

  IO.Socket? _socket;
  String _userId = '';

  final _incomingCallController = StreamController<Map<String, dynamic>>.broadcast();
  final _signalController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get incomingCalls => _incomingCallController.stream;
  Stream<Map<String, dynamic>> get signals => _signalController.stream;

  Future<void> bindUser(String userId) async {
    _userId = userId;
    final socket = await _ensureSocket();
    socket.emit('webrtc:register-user', {'userId': userId, 'uid': userId});
    socket.emit('user:register', {'uid': userId});
  }

  Future<void> unbindUser() async {
    final socket = _socket;
    if (socket != null && _userId.isNotEmpty) {
      socket.emit('webrtc:unregister-user', {'userId': _userId});
    }
    _userId = '';
  }

  Future<IO.Socket> _ensureSocket() async {
    final socket = _socket;
    if (socket != null && socket.connected) {
      return socket;
    }

    final created = IO.io(
      WebRtcEnvironment.socketBackendUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(300)
          .build(),
    );

    created.onConnect((_) {
      if (_userId.isNotEmpty) {
        created.emit('webrtc:register-user', {'userId': _userId, 'uid': _userId});
        created.emit('user:register', {'uid': _userId});
      }
    });

    void addSignal(dynamic payload) {
      if (payload is Map) {
        _signalController.add(Map<String, dynamic>.from(payload));
      }
    }

    created.on('webrtc:incoming-call', (dynamic payload) {
      if (payload is Map) {
        _incomingCallController.add(Map<String, dynamic>.from(payload));
      }
    });
    created.on('webrtc:offer', addSignal);
    created.on('webrtc:answer', addSignal);
    created.on('webrtc:ice-candidate', addSignal);
    created.on('signal', addSignal);

    created.connect();
    _socket = created;
    return created;
  }

  Future<void> joinRoom(String roomId, {String? userId}) async {
    final socket = await _ensureSocket();
    socket.emit('webrtc:join-room', {
      'roomId': roomId,
      'userId': userId ?? _userId,
    });
  }

  Future<void> leaveRoom(String roomId, {String? userId}) async {
    final socket = _socket;
    if (socket == null) return;
    socket.emit('webrtc:leave-room', {
      'roomId': roomId,
      'userId': userId ?? _userId,
    });
  }

  Future<void> emitOffer(String roomId, Map<String, dynamic> payload) async {
    final socket = await _ensureSocket();
    socket.emit('webrtc:offer', {'roomId': roomId, ...payload});
  }

  Future<void> emitAnswer(String roomId, Map<String, dynamic> payload) async {
    final socket = await _ensureSocket();
    socket.emit('webrtc:answer', {'roomId': roomId, ...payload});
  }

  Future<void> emitIceCandidate(String roomId, Map<String, dynamic> payload) async {
    final socket = await _ensureSocket();
    socket.emit('webrtc:ice-candidate', {'roomId': roomId, ...payload});
  }

  Future<void> broadcastCallStart({
    required String roomId,
    required String callId,
    required String projectId,
    required String projectTitle,
    required String senderId,
    required String senderDisplayName,
    required Set<String> invitedUserIds,
  }) async {
    final socket = await _ensureSocket();
    final targets = invitedUserIds.isEmpty ? <String>{} : invitedUserIds;

    for (final targetId in targets) {
      socket.emit('webrtc:incoming-call', {
        'roomId': roomId,
        'callId': callId,
        'callerId': senderId,
        'senderId': senderId,
        'callerName': senderDisplayName,
        'projectId': projectId,
        'projectName': projectTitle,
        'projectTitle': projectTitle,
        'targetUserId': targetId,
        'targetUids': targets.toList(),
      });
    }
  }

  Future<void> declineCall(String roomId, String callerId) async {
    final socket = await _ensureSocket();
    socket.emit('webrtc:decline', {
      'roomId': roomId,
      'callerId': callerId,
      'declinedById': FirebaseAuth.instance.currentUser?.uid ?? _userId,
    });
  }

  Future<void> hangup(String roomId, {String? targetSocketId}) async {
    final socket = await _ensureSocket();
    socket.emit('webrtc:hangup', {
      'roomId': roomId,
      if (targetSocketId != null && targetSocketId.isNotEmpty) 'targetSocketId': targetSocketId,
      'senderId': FirebaseAuth.instance.currentUser?.uid ?? _userId,
    });
  }

  Future<void> dispose() async {
    final socket = _socket;
    _socket = null;
    await unbindUser();
    socket?.dispose();
    if (!_incomingCallController.isClosed) {
      await _incomingCallController.close();
    }
    if (!_signalController.isClosed) {
      await _signalController.close();
    }
  }
}