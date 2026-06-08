import 'api_client.dart';

class RepostService {
  Future<int> repost(String postId) async {
    final r = await apiPost('/reposts/$postId', {});
    final data = expectJson(r);
    return (data['repostCount'] as num?)?.toInt() ?? 0;
  }

  Future<int> undoRepost(String postId) async {
    final r = await apiDelete('/reposts/$postId');
    final data = expectJson(r);
    return (data['repostCount'] as num?)?.toInt() ?? 0;
  }

  Future<({bool isReposted, int repostCount})> getStatus(String postId) async {
    final r = await apiGet('/reposts/$postId');
    final data = expectJson(r);
    return (
      isReposted: data['isReposted'] == true,
      repostCount: (data['repostCount'] as num?)?.toInt() ?? 0,
    );
  }
}
