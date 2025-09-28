import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveExtraProfile(
    String uid, {
    required String day,
    required String month,
    required String year,
    required String gender,
  }) async {
    await _db.collection('users').doc(uid).set({
      'dob': {'day': day, 'month': month, 'year': year},
      'gender': gender,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
