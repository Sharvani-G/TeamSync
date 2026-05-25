import 'package:cloud_firestore/cloud_firestore.dart';

class WebRtcSignalingService {
  final _db = FirebaseFirestore.instance;

  /// Create a room document for signaling.
  Future<void> createRoom(String roomId) async {
    final ref = _db.collection('webrtc_rooms').doc(roomId);
    await ref.set({
      'createdAt': FieldValue.serverTimestamp(),
      'offers': [],
      'answers': [],
      'candidates': [],
    });
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
