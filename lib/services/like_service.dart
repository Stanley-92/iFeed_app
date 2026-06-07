import 'api_client.dart';

class LikeService {
  Future<void> likePost(String postId) async {
    final r = await apiPost('/posts/$postId/like', {});
    expectJson(r);
  }

  Future<void> unlikePost(String postId) async {
    final r = await apiDelete('/posts/$postId/like');
    expectJson(r);
  }

  Future<bool> isLiked(String postId) async {
    final r = await apiGet('/posts/$postId/like');
    final body = expectJson(r);
    return body['isLiked'] as bool? ?? false;
  }
}
