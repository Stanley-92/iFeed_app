import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommentService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    final uid = _auth.currentUser!.uid;

    await _db.collection('posts').doc(postId).collection('comments').add({
      'userId': uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('posts').doc(postId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  Stream<QuerySnapshot> getComments(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    await _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .delete();

    await _db.collection('posts').doc(postId).update({
      'commentCount': FieldValue.increment(-1),
    });
  }
}
