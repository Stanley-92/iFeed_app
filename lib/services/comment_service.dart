import 'api_client.dart';

class CommentService {
  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final r = await apiGet('/posts/$postId/comments');
    final list = expectJsonList(r);
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addComment({
    required String postId,
    required String text,
  }) async {
    final r = await apiPost('/posts/$postId/comments', {'text': text});
    return expectJson(r);
  }

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final r = await apiDelete('/posts/$postId/comments/$commentId');
    expectJson(r);
  }
}
