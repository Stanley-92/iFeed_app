// lib/services/user_profile_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyProfile {
  final String uid;
  final String displayName;
  final String? photoURL;
  final String email;

  MyProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoURL,
  });
}

Future<MyProfile> fetchMyProfile() async {
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  if (user == null) {
    throw StateError('Not signed in');
  }

  // Firestore user doc first
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  String name = user.displayName ?? '';
  String email = user.email ?? '';
  String? photo = user.photoURL;

  if (doc.exists) {
    final data = doc.data() as Map<String, dynamic>;
    final dn = (data['displayName'] as String?)?.trim();
    if (dn != null && dn.isNotEmpty) name = dn;
    email = (data['email'] as String?) ?? email;
    photo = (data['photoURL'] as String?) ?? photo;
  }

  if (name.isEmpty) name = email.isNotEmpty ? email.split('@').first : 'User';

  return MyProfile(
    uid: user.uid,
    displayName: name,
    email: email,
    photoURL: photo,
  );
}
