import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/painting.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> signOutAndClearSession() async {
    await _auth.signOut();
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();
  }
}
