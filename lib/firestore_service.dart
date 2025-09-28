import 'package:cloud_firestore/cloud_firestore.dart';

final _db = FirebaseFirestore.instance;

/// Create/merge the user profile in Firestore.
Future<void> saveUserProfile({
  required String uid,
  String? displayName,
  String? email,
  required String day,
  required String month,
  required String year,
  required String gender,
}) {
  return _db.collection('users').doc(uid).set({
    'uid'        : uid,
    'email'      : email,
    'displayName': displayName,
    'dob'        : {'day': day, 'month': month, 'year': year},
    'gender'     : gender,
    'updatedAt'  : FieldValue.serverTimestamp(),
    'createdAt'  : FieldValue.serverTimestamp(), // only set first time
  }, SetOptions(merge: true));
}
