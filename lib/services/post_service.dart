// lib/services/post_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PostService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Fetch Posts
  // =========================
  Future<List<Map<String, dynamic>>> fetchPosts() async {
    final snapshot = await _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // =========================
  // Author Info
  // =========================
  Future<Map<String, dynamic>> _authorInfo() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    final doc = await _db.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};

    return {
      'authorId': user.uid,
      'authorName': (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? (data['displayName'] as String).trim()
          : (user.displayName ?? (user.email?.split('@').first ?? 'User')),
      'authorAvatar': (data['photoURL'] as String?) ?? (user.photoURL ?? ''),
      'dob': data['dob'] ?? {},
      'gender': data['gender'] ?? '',
    };
  }

  Future<Map<String, dynamic>> fetchAuthor() => _authorInfo();

  // =========================
  // Upload Images
  // =========================
  Future<List<String>> _uploadFiles(String postId, List<File> files) async {
    final uid = _auth.currentUser!.uid;

    final List<String> urls = [];

    for (int i = 0; i < files.length; i++) {
      final path = 'users/$uid/posts/$postId/$i';

      final ref = _storage.ref(path);

      final snap = await ref.putFile(files[i]);

      final url = await snap.ref.getDownloadURL();

      urls.add(url);
    }

    return urls;
  }

  
  // Create Post
  // =========================
  Future<String> createPost({
    required String caption,
    required List<File> images,
  }) async {
    final postRef = _db.collection('posts').doc();

    final mediaUrls = await _uploadFiles(postRef.id, images);

    final author = await _authorInfo();

    await postRef.set({
      'id': postRef.id,
      'caption': caption,
      'media': mediaUrls,
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      ...author,
    });

    return postRef.id;
  }

  // =========================
  // Like Post
  // =========================
  Future<void> likePost(String postId) async {
    print("POST ID = $postId");
    final uid = _auth.currentUser!.uid;

    await _db.collection('posts').doc(postId).collection('likes').doc(uid).set({
      'userId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('posts').doc(postId).update({
      'likeCount': FieldValue.increment(1),
    });
  }

  // =========================
  // Unlike Post
  // =========================
  Future<void> unlikePost(String postId) async {
    final uid = _auth.currentUser!.uid;

    await _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .delete();

    await _db.collection('posts').doc(postId).update({
      'likeCount': FieldValue.increment(-1),
    });
  }

  // =========================
  // Add Comment
  // =========================
  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    print("ADD COMMENT");
    print("Post ID: $postId");
    print("Text: $text");

    final uid = _auth.currentUser!.uid;

    await _db.collection('posts').doc(postId).collection('comments').add({
      'userId': uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    print("COMMENT SAVED");
  }
}
