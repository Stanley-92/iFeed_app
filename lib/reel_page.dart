// reel_page.dart
import 'dart:async';
import 'dart:io'; //  for File playback (file://)
import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/material_symbols.dart';
import 'package:iconify_flutter/icons/ph.dart';
import 'package:iconify_flutter/icons/uil.dart';
import 'package:iconify_flutter/icons/teenyicons.dart';

import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// --------------------------- MODEL ---------------------------
class ReelItem {
  final String id;
  final String videoUrl; // supports https:// and file://
  final String caption;
  final String music;
  final String avatarUrl;
  final String authorName;
  final int likes;
  final int comments;
  final bool isFollowing;

  const ReelItem({
    required this.id,
    required this.videoUrl,
    required this.caption,
    required this.music,
    required this.avatarUrl,
    required this.authorName,
    this.likes = 0,
    this.comments = 0,
    this.isFollowing = false,
  });
}

/// --------------------------- PAGE ---------------------------
class ReelsPage extends StatefulWidget {
  const ReelsPage({
    super.key,
    this.items,
    this.initialIndex = 0, // 👈 new
  });

  final List<ReelItem>? items;
  final int initialIndex;

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  late final PageController _pageController;
  late final List<ReelItem> _items;

  /// We keep controllers per-page index.
  final Map<int, VideoPlayerController> _controllers = {};
  late int _currentIndex; // 👈 start at initialIndex
  bool _muted = true;
  bool _heartBurst = false;

  @override
  void initState() {
    super.initState();
    _items = widget.items ?? _demoItems;
    _currentIndex = widget.initialIndex.clamp(
      0,
      (_items.length - 1).clamp(0, _items.length),
    ); // safety
    _pageController = PageController(initialPage: _currentIndex);

    // Prepare current and preload neighbors
    _initControllerFor(_currentIndex);
    _initControllerFor(_currentIndex + 1);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      try {
        if (c.value.isInitialized) c.pause();
      } catch (_) {}
      c.dispose();
    }
    _controllers.clear();
    _pageController.dispose();
    super.dispose();
  }

  VideoPlayerController _buildControllerForUrl(String url) {
    if (url.startsWith('file://')) {
      // file://... -> File URI
      final uri = Uri.parse(url);
      return VideoPlayerController.file(File(uri.toFilePath()));
    }
    // default: network
    return VideoPlayerController.networkUrl(Uri.parse(url));
  }

  Future<void> _initControllerFor(int index) async {
    if (!mounted) return;
    if (index < 0 || index >= _items.length) return;
    if (_controllers.containsKey(index)) return;

    final item = _items[index];
    final controller = _buildControllerForUrl(item.videoUrl);

    // Insert immediately so subsequent reads see a key (even if not initialized yet)
    _controllers[index] = controller;

    try {
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        _controllers.remove(index);
        return;
      }

      controller
        ..setLooping(true)
        ..setVolume(_muted ? 0 : 1);

      // Autoplay only the current one
      if (index == _currentIndex) {
        try {
          controller.play();
        } catch (_) {}
      }

      if (mounted) setState(() {});

      // Preload next silently
      if (index + 1 < _items.length) {
        unawaited(_initControllerFor(index + 1));
      }
    } catch (_) {
      _controllers.remove(index);
      try {
        controller.dispose();
      } catch (_) {}
    }
  }

  void _playOnly(int index) {
    _controllers.forEach((i, c) {
      if (!c.value.isInitialized) return;
      try {
        if (i == index) {
          c.play();
        } else {
          c.pause();
        }
      } catch (_) {}
    });
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    final c = _controllers[_currentIndex];
    if (c != null && c.value.isInitialized) {
      try {
        c.setVolume(_muted ? 0 : 1);
      } catch (_) {}
    }
  }

  Future<void> _burstHeart() async {
    setState(() => _heartBurst = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _heartBurst = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _items.length,
            onPageChanged: (i) async {
              if (!mounted) return;
              setState(() => _currentIndex = i);

              await _initControllerFor(i); // ensure exists
              _playOnly(i); // play active
              unawaited(_initControllerFor(i + 1)); // warm next
            },
            itemBuilder: (context, index) {
              return _ReelTile(
                key: ValueKey(_items[index].id),
                item: _items[index],
                controller: _controllers[index],
                muted: _muted,
                overlayHeart: _heartBurst && index == _currentIndex,
                // Taps
                onTapVideo: () {
                  final c = _controllers[index];
                  if (c == null || !c.value.isInitialized) return;
                  try {
                    c.value.isPlaying ? c.pause() : c.play();
                  } catch (_) {}
                  if (mounted) setState(() {});
                },
                onDoubleTapVideo: _burstHeart,
                // Actions
                onComment: () {},
                onShare: () {},
              );
            },
          ),

          // Top bar: back + mute
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Iconify(
                    MaterialSymbols.arrow_back_ios,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                IconButton(
                  icon: Iconify(
                    _muted
                        ? Teenyicons.sound_off_outline
                        : Teenyicons.sound_on_outline,
                    color: Colors.white,
                  ),
                  onPressed: _toggleMute,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// --------------------------- REEL TILE ---------------------------
class _ReelTile extends StatefulWidget {
  const _ReelTile({
    super.key,
    required this.item,
    required this.controller,
    required this.muted,
    required this.overlayHeart,
    required this.onTapVideo,
    required this.onDoubleTapVideo,
    required this.onComment,
    required this.onShare,
  });

  final ReelItem item;
  final VideoPlayerController? controller;
  final bool muted;
  final bool overlayHeart;

  final VoidCallback onTapVideo;
  final VoidCallback onDoubleTapVideo;
  final VoidCallback onComment;
  final VoidCallback onShare;

  @override
  State<_ReelTile> createState() => _ReelTileState();
}

class _ReelTileState extends State<_ReelTile>
    with AutomaticKeepAliveClientMixin {
  late int _likeCount;
  late int _commentCount;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.item.likes;
    _commentCount = widget.item.comments;
  }

  @override
  bool get wantKeepAlive => true;

  void _toggleLike() {
    setState(() {
      _liked = !_liked;
      _liked ? _likeCount++ : _likeCount--;
      if (_likeCount < 0) _likeCount = 0;
    });
  }

  String _k(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final initialized = widget.controller?.value.isInitialized == true;

    return VisibilityDetector(
      key: Key('reel-${widget.item.id}'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        final visible = info.visibleFraction > 0.6;
        final c = widget.controller;
        if (c == null) return;
        if (!c.value.isInitialized) return;
        try {
          visible ? c.play() : c.pause();
        } catch (_) {}
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          GestureDetector(
            onTap: widget.onTapVideo,
            onDoubleTap: () {
              if (!_liked) _toggleLike();
              widget.onDoubleTapVideo();
            },
            child: ColoredBox(
              color: Colors.black,
              child: initialized
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: widget.controller!.value.size.width,
                        height: widget.controller!.value.size.height,
                        child: VideoPlayer(widget.controller!),
                      ),
                    )
                  : const Center(
                      child: SizedBox(
                        height: 44,
                        width: 44,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),

          // Heart burst
          if (widget.overlayHeart)
            const Center(
              child: Iconify(
                Ph.heart,
                color: Color.fromARGB(179, 179, 15, 15),
                size: 120,
              ),
            ),

          // Left-bottom meta + progress
          _BottomMeta(
            item: widget.item,
            controller: widget.controller,
            muted: widget.muted,
          ),

          // Bottom action bar
          _BottomActionBar(
            isPlaying: widget.controller?.value.isPlaying == true,
            likesLabel: _k(_likeCount),
            commentsLabel: _k(_commentCount),
            onLike: _toggleLike,
            onComment: widget.onComment,
            onTogglePlay: widget.onTapVideo,
            onRemix: () {},
            onShare: widget.onShare,
          ),
        ],
      ),
    );
  }
}

/// Bottom meta (avatar + follow + caption + music + progress)
class _BottomMeta extends StatelessWidget {
  const _BottomMeta({
    required this.item,
    required this.controller,
    required this.muted,
  });

  final ReelItem item;
  final VideoPlayerController? controller;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final initialized = controller?.value.isInitialized == true;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(item.avatarUrl),
              ),
              const SizedBox(width: 8),
              Text(
                '@${item.authorName}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Follow',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 1),
          Row(
            children: [
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  item.music,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(width: 1),
              Iconify(
                muted
                    ? MaterialSymbols.volume_off_rounded
                    : MaterialSymbols.volume_up_rounded,
                color: Colors.white70, // keep as White70 color
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (initialized)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: VideoProgressIndicator(
                controller!,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom action bar
class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.isPlaying,
    required this.likesLabel,
    required this.commentsLabel,
    required this.onLike,
    required this.onComment,
    required this.onTogglePlay,
    required this.onRemix,
    required this.onShare,
  });

  final bool isPlaying;
  final String likesLabel;
  final String commentsLabel;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onTogglePlay;
  final VoidCallback onRemix;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '1:20',
            style: TextStyle(color: Colors.white70, fontSize: 10),
          ),
          Row(
            children: [
              _chip(
                icon: Iconify(Ph.heart_bold, size: 25, color: Colors.white),
                label: likesLabel,
                onTap: onLike,
              ),
              const SizedBox(width: 14),
              _chip(
                icon: const Iconify(Uil.comment, size: 25, color: Colors.white),
                label: commentsLabel,
                onTap: onComment,
              ),
              const SizedBox(width: 14),
              _circle(
                icon: const Iconify(
                  Ph.shuffle_fill,
                  size: 25,
                  color: Colors.white,
                ),
                onTap: onRemix,
              ),
              const SizedBox(width: 14),
              _circle(
                icon: const Iconify(
                  Ph.paper_plane_tilt,
                  size: 25,
                  color: Colors.white,
                ),
                onTap: onShare,
              ),
            ],
          ),
          const Text(
            '-2:20',
            style: TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          _circle(icon: icon, onTap: onTap),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _circle({required Widget icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(padding: const EdgeInsets.all(8), child: icon),
    );
  }
}

/// Demo items (fallback)
const _demoItems = <ReelItem>[
  ReelItem(
    id: '1',
    videoUrl:
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    caption: 'Morning vibes in Phnom Penh',
    music: 'Original Audio  @sinayun',
    avatarUrl:
        'https://images.unsplash.com/photo-1502685104226-ee32379fefbe?w=200',
    authorName: 'sinayun',
    likes: 0,
    comments: 0,
  ),
  ReelItem(
    id: '2',
    videoUrl:
        'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    caption: 'Tech vlog: iFeed update',
    music: 'Track — iFeed Beats',
    avatarUrl:
        'https://images.unsplash.com/photo-1545996124-0501ebae84d5?w=200',
    authorName: 'techsquad',
    likes: 0,
    comments: 0,
  ),
];
