// auth_service.dart
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

final _auth = FirebaseAuth.instance;
final _db   = FirebaseFirestore.instance;

/// Create a Firestore user profile if it doesn't exist.
Future<void> _ensureUserDoc(User user) async {
  final doc = _db.collection('users').doc(user.uid);
  final snap = await doc.get();
  if (!snap.exists) {
    await doc.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'phoneNumber': user.phoneNumber,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'providerIds': user.providerData.map((p) => p.providerId).toList(),
    });
  } else {
    await doc.update({'updatedAt': FieldValue.serverTimestamp()});
  }
}

/// Google Sign-In (works on Android/iOS; uses popup on Web)
Future<User?> signInWithGoogle() async {
  if (kIsWeb) {
    // Web: use popup
    final provider = GoogleAuthProvider();
    final cred = await _auth.signInWithPopup(provider);
    final user = cred.user;
    if (user != null) await _ensureUserDoc(user);
    return user;
  } else {
    // Mobile: GoogleSignIn -> Firebase
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // user cancelled
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
    final cred = await _auth.signInWithCredential(credential);
    final user = cred.user;
    if (user != null) await _ensureUserDoc(user);
    return user;
  }
}

/// Email/password create + optional email verification
Future<User?> createAccountWithEmail({
  required String email,
  required String password,
  String? displayName,
}) async {
  final cred = await _auth.createUserWithEmailAndPassword(
    email: email.trim(), password: password);
  final user = cred.user;
  if (user != null) {
    if (displayName != null && displayName.isNotEmpty) {
      await user.updateDisplayName(displayName);
    }
    await _ensureUserDoc(user);
    // Send email verification (optional)
    try { await user.sendEmailVerification(); } catch (_) {}
  }
  return user;
}
