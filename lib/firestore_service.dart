// Firestore removed — profile is now saved via REST API.
Future<void> saveUserProfile({
  required String uid,
  String? displayName,
  String? email,
  required String day,
  required String month,
  required String year,
  required String gender,
}) async {
  // no-op: profile saved through /users/me API endpoint
}
