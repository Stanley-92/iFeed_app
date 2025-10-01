// lib/services/post_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PostService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // Build author info from Firestore 'users/{uid}' with Auth fallbacks
  Future<Map<String, dynamic>> _authorInfo() async {
    final u = _auth.currentUser;
    if (u == null) return {};

    final doc = await _db.collection('users').doc(u.uid).get();
    final data = doc.data() ?? {};

    return {
      'authorId': u.uid,
      'authorName': (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? (data['displayName'] as String).trim()
          : (u.displayName ?? (u.email?.split('@').first ?? 'User')),
      'authorAvatar': (data['photoURL'] as String?) ?? (u.photoURL ?? ''),
      'dob': data['dob'] ?? {}, // e.g. {'day':'04','month':'04','year':'2025'}
      'gender': data['gender'] ?? '',
    };
  }

  // Expose author info if your UI wants to show it
  Future<Map<String, dynamic>> fetchAuthor() => _authorInfo();

  // Upload multiple files to Storage and return their download URLs
  Future<List<String>> _uploadFiles(String postId, List<File> files) async {
    final uid = _auth.currentUser!.uid;
    final List<String> urls = [];
    for (var i = 0; i < files.length; i++) {
      final path = 'users/$uid/posts/$postId/$i';
      final ref = _storage.ref(path);
      final snap = await ref.putFile(files[i]);
      urls.add(await snap.ref.getDownloadURL());
    }
    return urls;
  }

  // Create a post document in Firestore
  Future<String> createPost({
    required String caption,
    required List<File> images, // pass only images here (keep it simple)
  }) async {
    final postRef = _db.collection('posts').doc();
    final mediaUrls = await _uploadFiles(postRef.id, images);
    final author = await _authorInfo();

    await postRef.set({
      'id': postRef.id,
      'caption': caption,
      'media': mediaUrls, // array of image URLs
      'createdAt': FieldValue.serverTimestamp(),
      ...author, // authorId, authorName, authorAvatar, dob, gender
    });

    return postRef.id;
  }
}
