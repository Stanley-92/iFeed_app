import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LikeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // =========================
  // Like Post
  // =========================
  Future<void> likePost(String postId) async {
    print("POST ID = $postId");

    final uid = _auth.currentUser!.uid;

    final doc = await _db.collection('posts').doc(postId).get();

    print("DOC EXISTS = ${doc.exists}");

    if (!doc.exists) {
      throw Exception("Post not found: $postId");
    }

    await _db.collection('posts').doc(postId).collection('likes').doc(uid).set({
      'userId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('posts').doc(postId).update({
      'likeCount': FieldValue.increment(1),
    });

    print("LIKE SUCCESS");
  }

  // =========================
  // Unlike Post
  // =========================
  Future<void> unlikePost(String postId) async {
    final uid = _auth.currentUser!.uid;

    final doc = await _db.collection('posts').doc(postId).get();

    if (!doc.exists) {
      throw Exception("Post not found: $postId");
    }

    await _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .delete();

    await _db.collection('posts').doc(postId).update({
      'likeCount': FieldValue.increment(-1),
    });

    print("UNLIKE SUCCESS");
  }
  
  // Check if user liked post
  // =========================
  Future<bool> isLiked(String postId) async {
    final uid = _auth.currentUser!.uid;

    final doc = await _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .get();

    return doc.exists;
  }
}
