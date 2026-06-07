import 'dart:io';
import 'api_client.dart';

class PostService {
  Future<List<Map<String, dynamic>>> fetchPosts() async {
    final r = await apiGet('/posts');
    final list = expectJsonList(r);
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchAuthor() async {
    final r = await apiGet('/users/me');
    return expectJson(r);
  }

  Future<String> createPost({
    required String caption,
    required List<File> files,
  }) async {
    final r = await apiMultipart(
      method: 'POST',
      path: '/posts',
      fields: {'caption': caption},
      files: files.map((f) => (field: 'media', file: f)).toList(),
    );
    final body = expectJson(r);
    return (body['id'] ?? body['_id']).toString();
  }

  Future<void> deletePost(String postId) async {
    final r = await apiDelete('/posts/$postId');
    expectJson(r);
  }
}
