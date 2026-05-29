import 'package:cloud_firestore/cloud_firestore.dart';

class WebRtcSignalingService {
  final _db = FirebaseFirestore.instance;

  /// Create or update a native call room document for signaling.
  Future<void> createRoom(
    String roomId, [
    Map<String, dynamic> metadata = const {},
  ]) async {
    final ref = _db.collection('webrtc_rooms').doc(roomId);
    await ref.set({
      'roomId': roomId,
      'createdAt': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
      'offers': [],
      'answers': [],
      'candidates': [],
      'active': true,
      ...metadata,
    }, SetOptions(merge: true));
  }

  Future<void> leaveRoom(String roomId) async {
    final ref = _db.collection('webrtc_rooms').doc(roomId);
    await ref.set({
      'active': false,
      'leftAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> postOffer(String roomId, Map<String, dynamic> offer) async {
    final ref = _db.collection('webrtc_rooms').doc(roomId);
    await ref.update({
      'offers': FieldValue.arrayUnion([offer]),
    });
  }

  Future<void> postAnswer(String roomId, Map<String, dynamic> answer) async {
    final ref = _db.collection('webrtc_rooms').doc(roomId);
    await ref.update({
      'answers': FieldValue.arrayUnion([answer]),
    });
  }

  Future<void> addCandidate(String roomId, Map<String, dynamic> candidate) async {
    final ref = _db.collection('webrtc_rooms').doc(roomId);
    await ref.update({
      'candidates': FieldValue.arrayUnion([candidate]),
    });
  }
}
