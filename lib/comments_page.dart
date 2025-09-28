// comments_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/uil.dart';
import 'package:iconify_flutter/icons/ph.dart';
import 'package:video_player/video_player.dart';

/// ====== Avatar helpers (match feed behavior) ======
const String defaultAvatarAsset = 'assets/images/default_avatar.png';

ImageProvider _avatarProvider(String avatar) {
  if (avatar.isEmpty) return const AssetImage(defaultAvatarAsset);
  if (avatar.startsWith('http')) return NetworkImage(avatar);
  return AssetImage(avatar); // treat any non-http string as asset path
}

/// ───────── Public models you use from the feed ─────────
enum MediaType { image, video }

class PostMedia {
  final MediaType type;
  final String? url;   // network source
  final File? file;    // local source (picker)
  const PostMedia._(this.type, {this.url, this.file});

  // Network factories
  factory PostMedia.image(String url) => PostMedia._(MediaType.image, url: url);
  factory PostMedia.video(String url) => PostMedia._(MediaType.video, url: url);

  // Local factories
  factory PostMedia.imageFile(File file) => PostMedia._(MediaType.image, file: file);
  factory PostMedia.videoFile(File file) => PostMedia._(MediaType.video, file: file);

  bool get isLocal => file != null;
  String get key => isLocal ? file!.path : (url ?? '');
}

/// Public comment value object (used across pages)
class Comment {
  final String id;
  final String userName;
  final String avatar;
  final String time;
  final String text;
  final bool isReply;
  final List<Comment> replies;

  const Comment({
    required this.id,
    required this.userName,
    required this.avatar,
    required this.time,
    required this.text,
    this.isReply = false,
    this.replies = const [],
  });
}



/// ─────────────── CommentsPage ───────────────
class CommentsPage extends StatefulWidget {
  const CommentsPage({
    super.key,
    required this.postAuthorName,
    required this.postAuthorAvatar, // URL, asset path, or ''
    required this.postTimeText,
    required this.postText,
    required this.postMedia,
    this.initialComments = const <Comment>[],
    this.showAvatars = true,
    required this.currentUserName,
    required this.currentUserAvatar,
  });

  final String postAuthorName;
  final String postAuthorAvatar;
  final String postTimeText;
  final String postText;
  final List<PostMedia> postMedia;
  final List<Comment> initialComments;
  final bool showAvatars;
  final String currentUserName;
  final String currentUserAvatar;

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _focus = FocusNode();

  // Internal tree we mutate in the UI
  final List<_CommentNode> _comments = [];
  _CommentNode? _replyTo;

  // Header action state (like/share/repost)
  bool _headerLiked = false;
  bool _headerShared = false;
  int _headerLikes = 0;
  int _headerReposts = 0;

  String _fmt(int n) {
    if (n < 1000) return '$n';
    final v = (n / 1000).toStringAsFixed(1);
    return v.endsWith('.0') ? '${v.substring(0, v.length - 2)}K' : '${v}K';
  }

  int get _headerComments => _comments.length;

  @override
  void initState() {
    super.initState();
    _comments.addAll(widget.initialComments.map(_CommentNode.fromPublic));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  // Convert current state to the public VO and pop
  void _popWithResult() {
    final result = _comments.map((n) => n.toPublic()).toList(growable: false);
    Navigator.pop<List<Comment>>(context, result);
  }

  void _startReply(_CommentNode c) {
    setState(() => _replyTo = c);
    _input
      ..clear()
      ..text = '@${c.userName} ';
    _focus.requestFocus();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    final node = _CommentNode(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userName: widget.currentUserName,
      avatar: widget.currentUserAvatar,
      time: 'now',
      text: text,
      isReply: _replyTo != null,
    );

    setState(() {
      if (_replyTo == null) {
        _comments.add(node);
      } else {
        _replyTo!.replies.add(node);
      }
      _replyTo = null;
    });

    _input.clear();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    final authorAvatar = widget.postAuthorAvatar;
    final authorName = widget.postAuthorName;     
    final postTime = widget.postTimeText;
    final hasCaption = widget.postText.trim().isNotEmpty;
    final hasMedia = widget.postMedia.isNotEmpty;

    // Match feed spacing: caption starts ~60 from the left edge when avatar shown.
    const double feedCaptionLeft = 60.0;
    // Our container has 16px horizontal padding; add the *extra* padding inside.
    final double captionExtraLeft = widget.showAvatars ? (feedCaptionLeft - 16.0) : 0.0;

    return WillPopScope(
      onWillPop: () async {
        _popWithResult();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: AppBar(
          title: const Text('Replies'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _popWithResult, // return comments when leaving
          ),
        ),
        body: Column(
          children: [




 // ─── Post header (LEFT-aligned like feed) ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(48, 1, 16, 10),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // author
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.showAvatars) ...[
                        CircleAvatar(
                          radius: 25,
                          backgroundImage: _avatarProvider(authorAvatar),
                          onBackgroundImageError: (_, __) {},
                          backgroundColor: Colors.grey.shade200,
                        ),
                        const SizedBox(width: 18),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (authorName.isNotEmpty)
                              Text(authorName,
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w700)),
                            if (postTime.isNotEmpty)
                              Text(postTime,
                                  style: const TextStyle(
                                      fontSize: 13, color: Color.fromARGB(137, 17, 17, 17))),
                          ],
                        ),
                      ),
                    ],
                  ),

// caption
                  if (hasCaption) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.only(left: captionExtraLeft),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 560),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEAEAEA)),
                        ),
                        child: SelectableText(
                          widget.postText,
                          style: const TextStyle(fontSize: 14, height: 1.35),
                        ),
                      ),
                    ),
                  ],

// media
                  if (hasMedia) ...[
                    const SizedBox(height: 8), // reduced gap under media vs. before
                    _ReplyPostMedia(items: widget.postMedia),
                  ],

                  // ─── Actions row (same icons as feed) ───
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(48, 0, 18, 0), // match feed padding
                    child: Row(
                      children: [
                        // Like
                        IconButton(
                          icon: Iconify(
                            _headerLiked ? Ph.heart_fill : Ph.heart_bold,
                            size: 24,
                            color: _headerLiked ? Colors.red : null,
                          ),
                          onPressed: () {
                            setState(() {
                              _headerLiked = !_headerLiked;
                              _headerLiked ? _headerLikes++ : _headerLikes--;
                              if (_headerLikes < 0) _headerLikes = 0;
                            });
                          },
                        ),
                        if (_headerLikes > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            _fmt(_headerLikes),
                            style: TextStyle(
                              fontSize: 13,
                              color: _headerLiked ? Colors.red : Colors.black54,
                            ),
                          ),
                        ],



const SizedBox(width: 15),
// Comments count (only if > 0)
                        const Iconify(Uil.comment, size: 24),
                        if (_headerComments > 0) ...[
                          const SizedBox(width: 4),
                          Text(_fmt(_headerComments),
                              style: const TextStyle(fontSize: 13)),
                        ],

                        const SizedBox(width: 16),



 // Repost (shuffle)
                        IconButton(
                          icon: const Iconify(Ph.shuffle_fill, size: 25),
                          onPressed: () => setState(() => _headerReposts++),
                        ),
                        if (_headerReposts > 0) ...[
                          const SizedBox(width: 4),
                          Text(_fmt(_headerReposts),
                              style: const TextStyle(fontSize: 13)),
                        ],

                        const SizedBox(width: 15),
 // Send/Share (paper-plane) — toggle highlight only
                        IconButton(
                          icon: Iconify(
                            _headerShared ? Ph.paper_plane_tilt_fill : Ph.paper_plane_tilt,
                            size: 25,
                            color: _headerShared ? Colors.blue : null,
                          ),
                          onPressed: () => setState(() => _headerShared = !_headerShared),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),


 // ─── Comments list ───
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(28, 8, 16, 16),
                children: [
                  if (_comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        'No comments yet. Be the first to reply!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ..._comments.map(
                    (c) => _CommentTile(
                      comment: c,
                      showAvatars: widget.showAvatars,
                      onReply: _startReply,
                      onLikeToggle: () => setState(() => c.liked = !c.liked),
                      onToggleCollapse: () =>
                          setState(() => c.expanded = !c.expanded),
                    ),
                  ),
                ],
              ),
            ),



  // ─── Input bar ───
            Container(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE6E6E6))),
              ),
              child: Row(
                children: [
                  if (widget.showAvatars) ...[
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: _avatarProvider(widget.currentUserAvatar),
                      onBackgroundImageError: (_, __) {},
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: _replyTo == null ? 'Write a reply…' : 'Replying…',
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        suffixIcon: _replyTo == null
                            ? null
                            : IconButton(
                                tooltip: 'Cancel reply',
                                onPressed: () => setState(() => _replyTo = null),
                                icon: const Icon(Icons.close, size: 18),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _send, child: const Icon(Icons.send, size: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}




/// ───────── Reply post media (same rules as feed) ─────────
class _ReplyPostMedia extends StatelessWidget {
  const _ReplyPostMedia({required this.items});
  final List<PostMedia> items;

  static const double _side = 60.0;            // same as feed
  static const double _gap  = 10;
  static const double _minH = 180;
  static const double _maxScreenFraction = 0.55;

  @override
  Widget build(BuildContext context) {
    const double aspect = 9 / 12;

    return LayoutBuilder(builder: (context, c) {
      final contentW = c.maxWidth - _side * 3;
      final naturalH = contentW / aspect;
      final maxH = MediaQuery.of(context).size.height * _maxScreenFraction;
      final h = naturalH.clamp(_minH, maxH);

      if (items.length == 1) {
        final m = items.first;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: _side),
          child: SizedBox(height: h, child: _ReplyRoundedTile(m: m, aspect: aspect)),
        );
      }

      if (items.length == 1) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: _side),
          child: SizedBox(
            height: h,
            child: Row(
              children: [
                Expanded(child: _ReplyRoundedTile(m: items[0], aspect: aspect)),
                const SizedBox(width: _gap),
                Expanded(child: _ReplyRoundedTile(m: items[1], aspect: aspect)),
              ],
            ),
          ),
        );
      }

      // 3+ → horizontal carousel like feed
      return SizedBox(
        height: h,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: _side),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: _gap),
          itemBuilder: (_, i) {
            final m = items[i];
            return SizedBox(width: h * aspect, child: _ReplyRoundedTile(m: m, aspect: aspect));
          },
        ),
      );
    });
  }
}

class _ReplyRoundedTile extends StatelessWidget {
  const _ReplyRoundedTile({required this.m, required this.aspect});
  final PostMedia m;
  final double aspect;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: aspect,
        child: _ReplyFillMedia(m: m),
      ),
    );
  }
}

class _ReplyFillMedia extends StatefulWidget {
  const _ReplyFillMedia({required this.m});
  final PostMedia m;

  @override
  State<_ReplyFillMedia> createState() => _ReplyFillMediaState();
}

class _ReplyFillMediaState extends State<_ReplyFillMedia> {
  VideoPlayerController? _c;
  bool _ready = false;

  bool get _isImage => widget.m.type == MediaType.image;
  File? get _file => widget.m.file;
  String? get _url => widget.m.url;

  @override
  void initState() {
    super.initState();
    if (!_isImage) {
      if (_file != null) {
        _c = VideoPlayerController.file(_file!);
      } else if (_url != null && _url!.isNotEmpty) {
        _c = VideoPlayerController.networkUrl(Uri.parse(_url!));
      }
      _c?.setLooping(true);
      _c?.initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      });
    }
  }

  @override
  void dispose() {
    _c?.pause();
    _c?.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_c == null || !_ready) return;
    if (_c!.value.isPlaying) {
      _c!.pause();
    } else {
      _c!.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isImage) {
      if (_file != null) {
        return Image.file(_file!, fit: BoxFit.cover);
      } else {
        return Image.network(_url ?? '', fit: BoxFit.cover);
      }
    }

    if (_c == null) {
      return const ColoredBox(
        color: Colors.black12,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: _ready
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _c!.value.size.width,
                    height: _c!.value.size.height,
                    child: VideoPlayer(_c!),
                  ),
                )
              : const ColoredBox(
                  color: Colors.black12,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black26, Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              child: Center(
                child: AnimatedOpacity(
                  opacity: (_c?.value.isPlaying ?? false) ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(Icons.play_circle_fill, size: 56, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


/// ───────── Internal node + mapping helpers ─────────
class _CommentNode {
  final String id;
  final String userName;
  final String avatar;
  final String time;
  final String text;
  final bool isReply;
  final List<_CommentNode> replies;
  bool liked;
  bool expanded;

  _CommentNode({
    required this.id,
    required this.userName,
    required this.avatar,
    required this.time,
    required this.text,
    this.isReply = false,
    List<_CommentNode>? replies,
    this.liked = false,
    this.expanded = true,
  }) : replies = replies ?? [];

  factory _CommentNode.fromPublic(Comment c) => _CommentNode(
        id: c.id,
        userName: c.userName,
        avatar: c.avatar,
        time: c.time,
        text: c.text,
        isReply: c.isReply,
        replies: c.replies.map(_CommentNode.fromPublic).toList(),
      );

  Comment toPublic() => Comment(
        id: id,
        userName: userName,
        avatar: avatar,
        time: time,
        text: text,
        isReply: isReply,
        replies: replies.map((r) => r.toPublic()).toList(growable: false),
      );
}

class _CommentTile extends StatelessWidget {
  final _CommentNode comment;
  final bool showAvatars;
  final void Function(_CommentNode) onReply;
  final VoidCallback onLikeToggle;
  final VoidCallback onToggleCollapse;

  const _CommentTile({
    required this.comment,
    required this.showAvatars,
    required this.onReply,
    required this.onLikeToggle,
    required this.onToggleCollapse,
    super.key,
  });



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leftPad = comment.isReply ? 2.0 : 58.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(leftPad, 8, 8, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showAvatars) ...[
                CircleAvatar(
                  radius: 20,
                  backgroundImage: _avatarProvider(comment.avatar),
                  onBackgroundImageError: (_, __) {},
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black87),
                        children: [
                          TextSpan(
                            text: comment.userName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: '  '),
                          TextSpan(
                            text: comment.time,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(comment.text),
                    const SizedBox(height: 6),






// under every comment/reply
                    Row(
                      children: [
                        IconButton(
                          icon: Iconify(Ph.heart_bold,size: 20,
                          color: comment.liked ? Colors.red : null,
                          ),
                          onPressed: onLikeToggle,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),

                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Iconify(Uil.comment, size: 20),
                          onPressed: () => onReply(comment),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),

                        
                           IconButton(
                          icon: const Iconify(Ph.shuffle_light, size: 20),
                          onPressed: (){},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: const Iconify(Ph.paper_plane_tilt_light, size: 20),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),



          // collapse/expand for children
          if (comment.replies.isNotEmpty && !comment.expanded)
            Padding(
              padding: EdgeInsets.only(left: (showAvatars ? 24 : 0) + leftPad, top: 2),
              child: TextButton(
                onPressed: onToggleCollapse,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Show ${comment.replies.length} replies…'),
              ),
            ),

          if (comment.expanded)
            ...comment.replies.map(
              (r) => _CommentTile(
                comment: r,
                showAvatars: showAvatars,
                onReply: onReply,
                onLikeToggle: () {},
                onToggleCollapse: () {},
              ),
            ),
        ],
      ),
    );
  }
}