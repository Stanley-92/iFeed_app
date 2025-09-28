// post_model.dart
import 'dart:io';



/// Images vs videos
enum MediaType { image, video }

/// A single media item that can come from the network (URL)
/// or from the local device (File). Use the factories below.
class PostMedia {
  final MediaType type;
  final String? url;   // http(s) source
  final File? file;    // local source (ImagePicker, etc.)

  const PostMedia._(this.type, {this.url, this.file});

  // Network factories
  factory PostMedia.image(String url) => PostMedia._(MediaType.image, url: url);
  factory PostMedia.video(String url) => PostMedia._(MediaType.video, url: url);

  // Local factories
  factory PostMedia.imageFile(File file) => PostMedia._(MediaType.image, file: file);
  factory PostMedia.videoFile(File file) => PostMedia._(MediaType.video, file: file);

  /// True if this media is a local file
  bool get isLocal => file != null;

  /// A stable key to index controllers/caches (file path or URL)
  String get key => isLocal ? file!.path : (url ?? '');
}

/// A single comment (can nest via [replies]).
/// Also supports optional media on a comment.
class Comment {
  final String id;
  final String userName;
  final String avatar;     // URL (or leave empty if you hide avatars)
  final String time;       // eg. "now", "2h"
  final String text;
  final bool isReply;
  final List<Comment> replies;
  final List<PostMedia> media;

  // UI state (not persisted on server typically)
  bool liked;
  bool expanded;

  Comment({
    required this.id,
    required this.userName,
    required this.avatar,
    required this.time,
    required this.text,
    this.isReply = false,
    List<Comment>? replies,
    this.liked = false,
    this.expanded = true,
    this.media = const <PostMedia>[],
  }) : replies = replies ?? [];
}

/// A post with author info, caption, media, and its comments.
/// (Feed-specific counters like likes/reposts can live in UI state.)
class Post {
  final String id;
  final String authorName;
  final String authorAvatar;   // URL (can be '')
  final String timeText;       // eg. "just now"
  final String caption;
  final List<PostMedia> media;
  List<Comment> comments;

  Post({
    required this.id,
    required this.authorName,
    required this.authorAvatar,
    required this.timeText,
    required this.caption,
    required this.media,
    List<Comment>? comments,
  }) : comments = comments ?? [];
}