import 'package:cloud_firestore/cloud_firestore.dart';

class CallService {
  final _db = FirebaseFirestore.instance;

  Future<DocumentReference> createCallSession(Map<String, dynamic> payload) async {
    final ref = await _db.collection('call_sessions').add({
      ...payload,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref;
  }

  Future<void> endCall(String sessionId) async {
    await _db.collection('call_sessions').doc(sessionId).update({
      'endedAt': FieldValue.serverTimestamp(),
      'active': false,
    });
  }
}
