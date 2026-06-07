import 'dart:io';
import 'api_client.dart';

class MyProfile {
  final String id;
  final String displayName;
  final String? photoURL;
  final String email;
  final String bio;

  MyProfile({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoURL,
    this.bio = '',
  });

  factory MyProfile.fromJson(Map<String, dynamic> j) => MyProfile(
        id: j['id']?.toString() ?? '',
        displayName: j['displayName'] as String? ?? '',
        email: j['email'] as String? ?? '',
        photoURL: j['photoURL'] as String?,
        bio: j['bio'] as String? ?? '',
      );
}

Future<MyProfile> fetchMyProfile() async {
  final r = await apiGet('/users/me');
  return MyProfile.fromJson(expectJson(r));
}

Future<MyProfile> fetchUserProfile(String userId) async {
  final r = await apiGet('/users/$userId');
  return MyProfile.fromJson(expectJson(r));
}

Future<MyProfile> updateProfile({
  String? displayName,
  String? bio,
  File? photo,
}) async {
  final r = await apiMultipart(
    method: 'PUT',
    path: '/users/me',
    fields: {
      if (displayName != null) 'displayName': displayName,
      if (bio != null) 'bio': bio,
    },
    files: photo != null ? [(field: 'photo', file: photo)] : [],
  );
  return MyProfile.fromJson(expectJson(r));
}
