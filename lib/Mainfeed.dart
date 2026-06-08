// mainfeed.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/mdi.dart';
import 'package:iconify_flutter/icons/ph.dart';
import 'package:iconify_flutter/icons/material_symbols.dart';
import 'package:iconify_flutter/icons/ion.dart';
import 'package:iconify_flutter/icons/gg.dart';
import 'package:iconify_flutter/icons/teenyicons.dart';
import 'package:iconify_flutter/icons/uil.dart';
import 'package:iconify_flutter/icons/tabler.dart';
import 'package:iconify_flutter/icons/ri.dart';
import 'services/api_client.dart';
import 'services/post_service.dart';
import 'services/like_service.dart';
import 'services/repost_service.dart';
import 'services/user_profile_service.dart';
import 'profile.dart';

import 'share_popup.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'post_modal.dart' as model;
import 'activity_page.dart';
import 'suggestions_page.dart';
import 'reel_page.dart';
import 'comments_page.dart' as reply;
import 'listcontact.dart' as lc;

Offset? _tapPosition;

void main() => runApp(const MaterialApp(home: MainfeedScreen()));

///======================= STORY MODELS (multi-item) =======================
class Story {
  Story({
    required this.id,
    required this.name,
    required this.items,
    this.avatar = '',
    this.hasNew = false,
  }) : itemCount = items.length;

  final String id;
  final String name;
  final String avatar; // user profile photo URL
  final List<StoryItem> items;
  final int itemCount;
  final bool hasNew;

  bool get hasItems => itemCount > 0;
  String get summary => itemCount == 1 ? '1 story' : '$itemCount stories';

  ImageProvider? get coverImageProvider {
    if (items.isEmpty) return null;
    final first = items.first;
    if (first.isVideo) {
      if (first.thumbBytes != null) return MemoryImage(first.thumbBytes!);
      if (avatar.isNotEmpty) return NetworkImage(avatar);
      return null;
    } else {
      if (first.isLocal) {
        return first.path != null ? FileImage(File(first.path!)) : null;
      } else {
        return first.url != null ? NetworkImage(first.url!) : null;
      }
    }
  }
}

class StoryItem {
  StoryItem({
    required this.isVideo,
    required this.isLocal,
    this.path,
    this.url,
    this.thumbBytes,
    this.caption,
  });

  final bool isVideo;
  final bool isLocal;
  final String? path; // local path
  final String? url; // network url
  final Uint8List? thumbBytes;
  final String? caption;
}

/// ======================= MAIN FEED =======================
class MainfeedScreen extends StatefulWidget {
  const MainfeedScreen({super.key});
  @override
  State<MainfeedScreen> createState() => _MainfeedScreenState();
}

class _MainfeedScreenState extends State<MainfeedScreen> {
  final List<_Post> _feedPosts = [];
  final List<ReelItem> _reels = <ReelItem>[];

  final ImagePicker _storyPicker = ImagePicker();

  Story? myStory;

  // Stories loaded from Firestore
  List<Story> stories = [];

  String _feedTab = 'for_you';

  String _currentUserId = '';
  String _currentUserName = '';
  String _currentUserAvatar = '';

  @override
  void initState() {
    super.initState();
    _initWithAuth();
  }

  Future<void> _initWithAuth() async {
    final loggedIn = await isLoggedIn();
    if (!loggedIn || !mounted) return;
    final uid = await getCurrentUserId();
    final profile = await _getCurrentProfile();
    if (!mounted) return;
    setState(() {
      _currentUserId = uid ?? '';
      _currentUserName = profile.name;
      _currentUserAvatar = profile.avatar ?? '';
    });
    loadPosts();
    loadStories();
  }

  Future<void> loadPosts() async {
    try {
      final r = await apiGet('/posts?feed=$_feedTab');
      final list = expectJsonList(r);
      final posts = list.map((raw) {
        final data = raw as Map<String, dynamic>;
        final mediaRaw = (data['media'] as List?) ?? [];
        final mediaList = mediaRaw.map((m) {
          final url = (m['url'] as String?) ?? '';
          final typeStr = (m['type'] as String?) ?? 'image';
          return _FeedMedia(
            path: url,
            type: typeStr == 'video' ? MediaType.video : MediaType.image,
            isNetwork: true,
          );
        }).toList();

        return _Post(
          id: (data['_id'] ?? data['id'] ?? '').toString(),
          authorId: (data['authorId'] ?? '').toString(),
          username: (data['authorName'] ?? 'User').toString(),
          avatar: (data['authorAvatar'] ?? '').toString(),
          time: 'just now',
          caption: (data['caption'] ?? '').toString(),
          likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
          commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
          isLiked: data['isLiked'] == true,
          media: mediaList,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _feedPosts.clear();
        _feedPosts.addAll(posts);
      });
    } catch (e) {
      debugPrint('loadPosts error: $e');
    }
  }

  Future<void> loadStories() async {
    final myUid = await getCurrentUserId();
    if (myUid == null) return;
    try {
      final r = await apiGet('/stories');
      final list = expectJsonList(r);

      // Group by userId
      final Map<String, List<StoryItem>> itemsMap = {};
      final Map<String, String> nameMap = {};
      final Map<String, String> avatarMap = {};

      for (final raw in list) {
        final data = raw as Map<String, dynamic>;
        final uid = (data['userId'] ?? '').toString();
        if (uid.isEmpty) continue;

        if (!itemsMap.containsKey(uid)) {
          itemsMap[uid] = [];
          nameMap[uid] = (data['displayName'] ?? 'User').toString();
          avatarMap[uid] = (data['avatarUrl'] ?? '').toString();
        }
        itemsMap[uid]!.add(
          StoryItem(
            isVideo: data['isVideo'] == true,
            isLocal: false,
            url: data['mediaUrl']?.toString(),
            caption: data['caption']?.toString(),
          ),
        );
      }

      Story? myStoryObj;
      final List<Story> others = [];

      for (final uid in itemsMap.keys) {
        final isMe = uid == myUid;
        final s = Story(
          id: uid,
          name: isMe
              ? (_currentUserName.isNotEmpty ? _currentUserName : nameMap[uid]!)
              : nameMap[uid]!,
          avatar: isMe
              ? (_currentUserAvatar.isNotEmpty
                    ? _currentUserAvatar
                    : avatarMap[uid]!)
              : avatarMap[uid]!,
          items: itemsMap[uid]!,
          hasNew: !isMe,
        );
        if (isMe) {
          myStoryObj = s;
        } else {
          others.add(s);
        }
      }

      if (!mounted) return;
      setState(() {
        myStory = myStoryObj;
        stories = others;
      });
    } catch (e) {
      debugPrint('loadStories error: $e');
    }
  }

  Future<void> deletePost({
    required String postId,
    required List<String> mediaUrls,
  }) async {
    try {
      await PostService().deletePost(postId);
      setState(() => _feedPosts.removeWhere((p) => p.id == postId));
    } catch (e) {
      debugPrint('Delete error: $e');
    }
  }

  Future<({String name, String? avatar})> _getCurrentProfile() async {
    final profile = await fetchMyProfile();
    return (name: profile.displayName, avatar: profile.photoURL);
  }

  bool _isVideoPath(String p) {
    final s = p.toLowerCase();
    return s.endsWith('.mp4') ||
        s.endsWith('.mov') ||
        s.endsWith('.m4v') ||
        s.endsWith('.3gp') ||
        s.endsWith('.webm') ||
        s.endsWith('.mkv') ||
        s.endsWith('.avi');
  }

  void _openFilterMenu(BuildContext context) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    if (_tapPosition == null) return;

    const menuWidth = 170.0;
    final left = _tapPosition!.dx - menuWidth;
    final top = _tapPosition!.dy + 8;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        left,
        top,
        overlay.size.width - left,
        overlay.size.height - top,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      items: [
        PopupMenuItem(
          value: 'for_you',
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'For you',
                  style: TextStyle(
                    fontWeight: _feedTab == 'for_you'
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (_feedTab == 'for_you')
                const Iconify(Ph.check_bold, size: 18, color: Colors.black87),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'following',
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Following',
                  style: TextStyle(
                    fontWeight: _feedTab == 'following'
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (_feedTab == 'following')
                const Iconify(Ph.check_bold, size: 18, color: Colors.black87),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null || value == _feedTab) return;
      setState(() {
        _feedTab = value;
        _feedPosts.clear();
      });
      loadPosts();
    });
  }

  Future<void> _addStory() async {
    final myUid = await getCurrentUserId();
    if (myUid == null) return;

    final List<XFile> files = await _storyPicker.pickMultipleMedia();
    if (files.isEmpty) return;
    if (!mounted) return;

    final text = await askStoryText(context);
    if (!mounted) return;

    for (final f in files) {
      try {
        final isVid = _isVideoPath(f.path);
        await apiMultipart(
          method: 'POST',
          path: '/stories',
          fields: {
            'isVideo': isVid.toString(),
            if (text != null && text.isNotEmpty) 'caption': text,
          },
          files: [(field: 'media', file: File(f.path))],
        );
      } catch (e) {
        debugPrint('Story upload error: $e');
      }
    }

    if (!mounted) return;
    await loadStories();
  }

  Future<String?> askStoryText(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add text to your story'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Type something… (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _openStory(Story s) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StoryViewer(story: s)),
    );
  }

  // For simplicity, this adds new posts only to the local feed (no Firebase upload).
  Future<void> _handleAddPost(BuildContext context) async {
    final model.Post? newPost = await Navigator.push<model.Post>(
      context,
      MaterialPageRoute(builder: (_) => const UploadPostPage()),
    );
    if (newPost == null) return;

    final myUid = await getCurrentUserId();
    final _Post converted = _Post(
      id: newPost.id,
      authorId: myUid ?? '',
      username: newPost.authorName,
      avatar: newPost.authorAvatar,
      time: newPost.timeText,
      caption: newPost.caption,
      aspect: CardAspect.auto,
      media: newPost.media.map((m) {
        final isNetwork = !m.isLocal;
        final path = m.isLocal ? m.file!.path : (m.url ?? '');
        final type = (m.type == model.MediaType.image)
            ? MediaType.image
            : MediaType.video;
        return _FeedMedia(path: path, type: type, isNetwork: isNetwork);
      }).toList(),
      comments: <reply.Comment>[],
    );

    // Add uploaded videos to reels
    for (final m in newPost.media) {
      if (m.type == model.MediaType.video) {
        final src = m.isLocal ? 'file://${m.file!.path}' : (m.url ?? '');
        if (src.isEmpty) continue;
        _reels.insert(
          0,
          ReelItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            videoUrl: src,
            caption: newPost.caption.isEmpty ? 'New reel' : newPost.caption,
            music: 'Original Audio',
            avatarUrl: newPost.authorAvatar.isNotEmpty
                ? newPost.authorAvatar
                : '',
            authorName: newPost.authorName,
            likes: 0,
            comments: 0,
          ),
        );
      }
    }

    setState(() => _feedPosts.insert(0, converted));
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    final v = (count / 1000).toStringAsFixed(1);
    return v.endsWith('.0') ? '${v.substring(0, v.length - 2)}K' : '${v}K';
  }

  String _replyHeaderAvatar(String avatar) {
    if (avatar.isNotEmpty && avatar.startsWith('http')) return avatar;
    return '';
  }

  List<reply.PostMedia> _toReplyMedia(List<_FeedMedia> items) {
    final out = <reply.PostMedia>[];
    for (final m in items) {
      if (m.type == MediaType.image) {
        out.add(
          m.isNetwork
              ? reply.PostMedia.image(m.path)
              : reply.PostMedia.imageFile(File(m.path)),
        );
      } else {
        out.add(
          m.isNetwork
              ? reply.PostMedia.video(m.path)
              : reply.PostMedia.videoFile(File(m.path)),
        );
      }
    }
    return out;
  }

  Future<void> _openComments(_Post post) async {
    final String currentUserName = _currentUserName.isNotEmpty
        ? _currentUserName
        : 'User';
    final String currentUserAvatar = _currentUserAvatar;

    if (!mounted) return;
    final updated = await Navigator.push<List<reply.Comment>>(
      context,
      MaterialPageRoute(
        builder: (_) => reply.CommentsPage(
          postId: post.id,
          postAuthorName: post.username,
          postAuthorAvatar: _replyHeaderAvatar(post.avatar),
          postTimeText: post.time,
          postText: post.caption,
          postMedia: _toReplyMedia(post.media),

          // Use Firebase profile data
          currentUserName: currentUserName,
          currentUserAvatar: currentUserAvatar,

          initialComments: post.comments,
          showAvatars: true,
        ),
      ),
    );

    if (updated != null) {
      setState(() {
        post.comments
          ..clear()
          ..addAll(updated);
      });
    }
  }

  void _openReels() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReelsPage(items: _reels.isEmpty ? null : _reels),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // my story cover
    final my = myStory;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.8,
        titleSpacing: 16,
        title: const Text(
          '',
          style: TextStyle(
            color: Color(0xff16a34a),
            fontWeight: FontWeight.w800,
            fontSize: 35,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 270),
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTapDown: (details) => _tapPosition = details.globalPosition,
              onTap: () => _openFilterMenu(context),
              child: const Iconify(
                Ph.equals_bold,
                color: Color.fromARGB(221, 69, 69, 70),
                size: 38,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 25),
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ActivityPage()),
              ),
              child: const Iconify(
                Ph.heart_bold,
                color: Color.fromARGB(221, 100, 97, 97),
                size: 38,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const lc.ChatListScreen()),
              ),
              child: const Iconify(
                Uil.comment,
                color: Color.fromARGB(221, 89, 96, 112),
                size: 40,
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // -------------------- Stories --------------------
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Row(
                          children: [
                            const Text(
                              'Stories',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            if (stories.isNotEmpty)
                              TextButton(
                                onPressed: () => _openStory(stories.first),
                                child: const Text('Watch all'),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 130,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          scrollDirection: Axis.horizontal,
                          itemBuilder: (_, i) {
                            // Index 0 = current user's story / add-story button
                            if (i == 0) {
                              final myAvatar = _currentUserAvatar;
                              final myName = _currentUserName.isNotEmpty
                                  ? _currentUserName
                                  : 'Your story';
                              return _StoryTile(
                                story:
                                    my ??
                                    Story(
                                      id: 'me',
                                      name: myName,
                                      avatar: myAvatar,
                                      items: const [],
                                      hasNew: false,
                                    ),
                                isCurrentUser: true,
                                onTap: () =>
                                    my == null ? _addStory() : _openStory(my),
                                onPlusTap: _addStory,
                                label: my == null ? 'Add story' : my.summary,
                              );
                            }

                            // Other users' stories
                            final s = stories[i - 1];
                            final ImageProvider? imgProvider =
                                s.avatar.isNotEmpty
                                ? NetworkImage(s.avatar)
                                : s.coverImageProvider;

                            return _StoryTile(
                              story: s,
                              onTap: () => _openStory(s),
                              imageProvider: imgProvider,
                            );
                          },
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 18),
                          itemCount: stories.length + 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            if (_feedPosts.isEmpty)
              const SliverToBoxAdapter(child: _EmptyFeed()),

            // -------------------- Feed --------------------
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  if (i.isOdd) return const SizedBox(height: 30);
                  final index = i ~/ 2;
                  if (index >= _feedPosts.length) return null;
                  final post = _feedPosts[index];

                  return _PostCard(
                    post: post,
                    currentUserId: _currentUserId,
                    onOpenComments: () => _openComments(post),

                    //LIke Icon
                    onLike: () async {
                      if (!post.isLiked) {
                        setState(() {
                          post.isLiked = true;
                          post.likeCount++;
                        });
                        try {
                          await LikeService().likePost(post.id);
                        } catch (e) {
                          setState(() {
                            post.isLiked = false;
                            post.likeCount--;
                          });
                        }
                      } else {
                        setState(() {
                          post.isLiked = false;
                          post.likeCount--;
                        });
                        try {
                          await LikeService().unlikePost(post.id);
                        } catch (e) {
                          setState(() {
                            post.isLiked = true;
                            post.likeCount++;
                          });
                        }
                      }
                    },

                    onShare: () =>
                        setState(() => post.isShared = !post.isShared),
                    onRepost: () async {
                      final wasReposted = post.isReposted;
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() {
                        post.isReposted = !wasReposted;
                        wasReposted ? post.shareCount-- : post.shareCount++;
                      });
                      try {
                        final count = wasReposted
                            ? await RepostService().undoRepost(post.id)
                            : await RepostService().repost(post.id);
                        if (mounted) setState(() => post.shareCount = count);
                      } catch (e) {
                        debugPrint('Repost error: $e');
                        if (mounted) {
                          setState(() {
                            post.isReposted = wasReposted;
                            wasReposted ? post.shareCount++ : post.shareCount--;
                          });
                        }
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Repost failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    formatCount: _formatCount,
                    reels: _reels,
                    currentUserName: _currentUserName,
                    currentUserAvatar: _currentUserAvatar,
                  );
                },
                childCount: _feedPosts.isEmpty ? 0 : _feedPosts.length * 2 - 1,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),

      bottomNavigationBar: _BottomBar(
        onAdd: () => _handleAddPost(context),
        onReels: _openReels,
        onProfile: () async {
          final nav = Navigator.of(context);
          final uid = await getCurrentUserId();
          if (uid == null || !mounted) return;
          nav.push(
            MaterialPageRoute(builder: (_) => ProfileUserScreen(userId: uid)),
          );
        },
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: const Column(
        children: [
          Iconify(
            Ph.paper_plane_tilt_bold,
            size: 58,
            color: Color.fromARGB(255, 76, 77, 82),
          ),
          SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Share your first post!',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// ------------------------- Story Ring -------------------------
class StoryRing extends StatelessWidget {
  final String? imageUrl;
  final bool showPlus;
  final bool isVideo;
  final bool hasNew;
  final int badgeCount;
  final ImageProvider? _provider;
  final VoidCallback? onPlusTap;

  const StoryRing({
    Key? key,
    required String imageUrl,
    this.showPlus = false,
    this.isVideo = false,
    this.hasNew = false,
    this.badgeCount = 0,
    this.onPlusTap,
  }) : imageUrl = imageUrl,
       _provider = null,
       super(key: key);

  const StoryRing.fromProvider({
    Key? key,
    required ImageProvider? imageProvider,
    this.showPlus = false,
    this.isVideo = false,
    this.hasNew = false,
    this.badgeCount = 0,
    this.onPlusTap,
  }) : imageUrl = null,
       _provider = imageProvider,
       super(key: key);

  ImageProvider? get provider {
    if (_provider != null) return _provider;
    if (imageUrl == null) return null;
    return NetworkImage(imageUrl!);
  }

  @override
  Widget build(BuildContext context) {
    final outerGradient = showPlus || hasNew
        ? const SweepGradient(
            colors: [Color(0xffb14cff), Color(0xffff4cf0), Color(0xffb14cff)],
            stops: [0.0, 0.55, 1.0],
          )
        : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: outerGradient,
            color: outerGradient == null ? Colors.grey.shade300 : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(3),
              child: CircleAvatar(
                radius: 34,
                backgroundColor: Colors.grey.shade400,
                foregroundImage: provider,
                onForegroundImageError: provider != null ? (_, __) {} : null,
                child: provider == null
                    ? const Icon(Icons.person, color: Colors.white, size: 28)
                    : null,
              ),
            ),
          ),
        ),
        if (badgeCount > 1 && !showPlus)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                badgeCount.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (isVideo)
          const Positioned(
            bottom: 6,
            left: 6,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: Colors.black54,
              child: Iconify(Ph.play, size: 12, color: Colors.white),
            ),
          ),
        if (showPlus)
          Positioned(
            bottom: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPlusTap,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 8, 8, 8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(blurRadius: 2, color: Colors.black26),
                    ],
                  ),
                  child: const Iconify(
                    Ri.add_line,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({
    super.key,
    required this.story,
    required this.onTap,
    this.onPlusTap,
    this.isCurrentUser = false,
    this.imageProvider,
    this.label,
  });

  final Story story;
  final VoidCallback onTap;
  final VoidCallback? onPlusTap;
  final bool isCurrentUser;
  final ImageProvider? imageProvider;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final cover =
        imageProvider ??
        (story.avatar.isNotEmpty
            ? NetworkImage(story.avatar)
            : story.coverImageProvider);
    final title = story.name.isNotEmpty ? story.name : 'Story';
    final subtitle =
        label ??
        (story.itemCount > 0
            ? story.summary
            : (isCurrentUser ? 'Add your first story' : 'No stories yet'));

    return SizedBox(
      width: 84,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onTap,
            child: StoryRing.fromProvider(
              imageProvider: cover,
              badgeCount: story.itemCount,
              isVideo: story.items.isNotEmpty && story.items.first.isVideo,
              showPlus: isCurrentUser,
              hasNew: story.hasNew,
              onPlusTap: onPlusTap,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

/// ------------------------- Comments Preview -------------------------
class _CommentsPreview extends StatelessWidget {
  const _CommentsPreview({
    required this.comments,
    required this.onViewAll,
    required this.onReply,
    required this.onLikeToggle,
  });

  final List<reply.Comment> comments;
  final VoidCallback onViewAll;
  final void Function(reply.Comment) onReply;
  final void Function(reply.Comment) onLikeToggle;

  Widget _commentAvatar(String url) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey.shade300,
      foregroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      onForegroundImageError: url.isNotEmpty ? (_, __) {} : null,
      child: const Icon(Icons.person, size: 20, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) return const SizedBox.shrink();

    final toShow = comments.length > 2 ? comments.take(2).toList() : comments;

    return Padding(
      padding: const EdgeInsets.fromLTRB(88, 18, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in toShow)
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _commentAvatar(c.avatar),
                      const SizedBox(width: 18),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Colors.black87,
                              height: 2.0,
                            ),
                            children: [
                              TextSpan(
                                text: c.userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(text: '  '),
                              TextSpan(
                                text: c.time.isNotEmpty ? c.time : 'now',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const TextSpan(text: '\n'),
                              TextSpan(text: c.text),
                            ],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 1),
                  Row(
                    children: [
                      IconButton(
                        icon: const Iconify(Ph.heart_bold, size: 20),
                        padding: const EdgeInsets.fromLTRB(58, 10, 12, 5),
                        constraints: const BoxConstraints(),
                        onPressed: () => onLikeToggle(c),
                      ),
                      const SizedBox(width: 5),
                      IconButton(
                        icon: const Iconify(Uil.comment, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => onReply(c),
                      ),
                      IconButton(
                        icon: const Iconify(Ph.shuffle_bold, size: 20),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Iconify(Ph.paper_plane_tilt_bold, size: 20),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (comments.length > 2)
            GestureDetector(
              onTap: onViewAll,
              child: Text(
                'View all ${comments.length} comments',
                style: const TextStyle(fontSize: 15, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }
}

/// ------------------------- Caption with tappable links -------------------------
class CaptionText extends StatelessWidget {
  final String text;
  const CaptionText({super.key, required this.text});

  static final _urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    int last = 0;
    for (final match in _urlRegex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: const TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ),
      );
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
          height: 1.35,
        ),
        children: spans,
      ),
    );
  }
}

/// ------------------------- Post Card -------------------------
class _PostCard extends StatelessWidget {
  final _Post post;
  final String currentUserId;
  final VoidCallback onOpenComments;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback onRepost; // async tap handled by caller
  final String Function(int) formatCount;
  final List<ReelItem> reels;
  final String currentUserName;
  final String currentUserAvatar;

  const _PostCard({
    required this.post,
    required this.currentUserId,
    required this.onOpenComments,
    required this.onLike,
    required this.onShare,
    required this.onRepost,
    required this.formatCount,
    required this.reels,
    required this.currentUserName,
    required this.currentUserAvatar,
  });

  Widget _avatar(String url, double radius) {
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade300,
      child: Icon(Icons.person, size: radius, color: Colors.white),
    );
    if (url.isEmpty || !url.startsWith('http')) return fallback;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade300,
      foregroundImage: NetworkImage(url),
      onForegroundImageError: (_, __) {},
      child: Icon(Icons.person, size: radius, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(38, 10, 12, 5),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileUserScreen(userId: post.authorId),
                    ),
                  ),
                  child: _avatar(post.avatar, 25),
                ),

                const SizedBox(width: 18),

                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProfileUserScreen(userId: post.authorId),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          post.time,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (post.authorId != currentUserId)
                  _FollowButton(authorId: post.authorId),

                IconButton(
                  icon: const Iconify(Mdi.dots_horizontal, size: 24),
                  onPressed: () => _showPostMenu(context, post, currentUserId, (
                    postId,
                    mediaUrls,
                  ) async {
                    final state = context
                        .findAncestorStateOfType<_MainfeedScreenState>();

                    if (state != null) {
                      await state.deletePost(
                        postId: postId,
                        mediaUrls: mediaUrls,
                      );

                      await state.loadPosts();
                    }
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Caption
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(100, 0, 12, 18),
              child: CaptionText(text: post.caption),
            ),

          // Media
          if (post.media.isNotEmpty)
            _PostMedia(
              post: post,
              reels: reels,
              currentUserName: currentUserName,
              currentUserAvatar: currentUserAvatar,
            ),

          // Actions Icon Row like comment share
          Padding(
            padding: const EdgeInsets.fromLTRB(88, 0, 18, 0),
            child: Row(
              children: [
                IconButton(
                  icon: Iconify(
                    post.isLiked ? Ph.heart_fill : Ph.heart_bold,
                    size: 24,
                    color: post.isLiked ? Colors.red : null,
                  ),
                  onPressed: onLike,
                ),
                if (post.likeCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Text(
                      formatCount(post.likeCount),
                      style: TextStyle(
                        fontSize: 13,
                        color: post.isLiked ? Colors.red : Colors.black54,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Iconify(Uil.comment, size: 24),
                  onPressed: onOpenComments,
                ),
                if (post.commentCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0, left: 4),
                    child: Text(
                      formatCount(post.commentCount),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                IconButton(
                  icon: Iconify(
                    Ph.shuffle_fill,
                    size: 24,
                    color: post.isReposted
                        ? const Color(0xff16a34a)
                        : Colors.black54,
                  ),
                  onPressed: onRepost,
                ),
                if (post.shareCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0, left: 4),
                    child: Text(
                      formatCount(post.shareCount),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                IconButton(
                  icon: Iconify(
                    post.isShared
                        ? Ph.paper_plane_tilt_fill
                        : Ph.paper_plane_tilt,
                    size: 24,
                    color: post.isShared ? Colors.blue : null,
                  ),
                  onPressed: () {
                    onShare();
                    showPlaneSharePopup(
                      context,
                      shareLink: 'https://ifeed.app/p/${post.id}',
                    );
                  },
                ),
              ],
            ),
          ),

          // Inline comments preview
          if (post.comments.isNotEmpty)
            _CommentsPreview(
              comments: post.comments,
              onViewAll: onOpenComments,
              onReply: (c) => onOpenComments(),
              onLikeToggle: (c) {},
            ),
        ],
      ),
    );
  }
}

void _showPostMenu(
  BuildContext context,
  _Post post,
  String currentUserId,
  Future<void> Function(String, List<String>) onDelete,
) {
  final isOwner = post.authorId == currentUserId;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: false,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MenuSection(
                children: [
                  _MenuItem(
                    iconify: MaterialSymbols.download_rounded,
                    label: 'Save',
                    onTap: () => Navigator.pop(context),
                  ),
                  _MenuItem(
                    iconify: Ph.article_bold,
                    label: 'Detail',
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
              _MenuSection(
                children: [
                  _MenuItem(
                    iconify: Ph.link_bold,
                    label: 'Copy link',
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
              _MenuSection(
                children: [
                  if (!isOwner) ...[
                    _MenuItem(
                      iconify: Ph.bell_bold,
                      label: 'Mute',
                      onTap: () => Navigator.pop(context),
                    ),
                    _MenuItem(
                      iconify: Ph.prohibit_inset_bold,
                      label: 'Block',
                      danger: true,
                      onTap: () => Navigator.pop(context),
                    ),
                    _MenuItem(
                      iconify: Ph.flag_bold,
                      label: 'Report',
                      danger: true,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                  if (isOwner)
                    _MenuItem(
                      iconify: Ph.trash_simple_bold,
                      label: 'Delete',
                      danger: true,
                      onTap: () async {
                        Navigator.pop(context);
                        try {
                          await onDelete(
                            post.id,
                            post.media.map((m) => m.path).toList(),
                          );
                        } catch (e) {
                          debugPrint('Delete failed: $e');
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _MenuSection extends StatelessWidget {
  final List<_MenuItem> children;
  const _MenuSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: List.generate(children.length, (i) {
          final w = children[i];
          final color = w.danger ? const Color(0xFFEF4444) : Colors.black87;
          return Column(
            children: [
              if (i != 0)
                const Divider(
                  height: 1,
                  thickness: 0.7,
                  color: Color(0xFFE5E7EB),
                ),
              ListTile(
                leading: w.iconify != null
                    ? Iconify(w.iconify!, color: color, size: 24)
                    : Icon(w.icon, color: color),
                title: Text(
                  w.label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
                onTap: w.onTap,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _MenuItem {
  final String label;
  final bool danger;
  final VoidCallback onTap;

  final String? iconify;
  final IconData? icon;

  const _MenuItem({
    required this.label,
    required this.onTap,
    this.danger = false,
    this.iconify,
    this.icon,
  }) : assert(iconify != null || icon != null, 'Must provide iconify or icon');
}

/// ------------------------- Media helpers & layouts -------------------------
enum CardAspect { auto, vertical, horizontal, square }

double? _forcedAspectFrom(CardAspect a) {
  switch (a) {
    case CardAspect.vertical:
      return 9 / 12;
    case CardAspect.horizontal:
      return 12 / 9;
    case CardAspect.square:
      return 1 / 1;
    case CardAspect.auto:
      return null;
  }
}

class _PostMedia extends StatelessWidget {
  final _Post post;
  final List<ReelItem> reels;
  final String currentUserName;
  final String currentUserAvatar;
  const _PostMedia({
    required this.post,
    required this.reels,
    required this.currentUserName,
    required this.currentUserAvatar,
  });

  static const double _side = 100.0;
  static const double _gap = 8;
  static const double _minH = 180;
  static const double _maxScreenFraction = 0.55;

  void _openViewerPaged(BuildContext context, int startIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) =>
            _MediaViewer(items: post.media, initialIndex: startIndex),
      ),
    );
  }

  void _showVideoSheet({
    required BuildContext context,
    required _FeedMedia media,
    required VoidCallback onFullscreen,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Iconify(Ri.youtube_line, size: 24),
                title: const Text('View Reel'),
                onTap: () {
                  Navigator.pop(context);
                  // Open ReelsPage with this single item (simple & robust)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReelsPage(
                        items: [
                          ReelItem(
                            id: DateTime.now().millisecondsSinceEpoch
                                .toString(),
                            videoUrl: media.isNetwork
                                ? media.path
                                : 'file://${media.path}',
                            caption: 'Reel',
                            music: 'Original Audio',
                            avatarUrl: currentUserAvatar,
                            authorName: currentUserName,
                            likes: 0,
                            comments: 0,
                          ),
                        ],
                        initialIndex: 0,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Iconify(MaterialSymbols.fullscreen, size: 24),
                title: const Text('View Fullscreen'),
                onTap: () {
                  Navigator.pop(context);
                  onFullscreen();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final forcedAspect = _forcedAspectFrom(post.aspect);

    return LayoutBuilder(
      builder: (context, c) {
        final baseAspect = forcedAspect ?? 9 / 12;
        final contentW = c.maxWidth - _side * 2;
        final naturalH = contentW / baseAspect;
        final maxH = MediaQuery.of(context).size.height * _maxScreenFraction;
        final h = naturalH.clamp(_minH, maxH);

        if (post.media.length == 1) {
          final m = post.media.first;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: _side),
            child: SizedBox(
              height: h,
              child: _RoundedTile(
                m: m,
                aspect: baseAspect,
                onTap: () => _openViewerPaged(context, 0),
                onVideoTap: () => _showVideoSheet(
                  context: context,
                  media: m,
                  onFullscreen: () => _openViewerPaged(context, 0),
                ),
              ),
            ),
          );
        }

        // horizontal scroller (2+)
        return SizedBox(
          height: h,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: _side),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: post.media.length,
            separatorBuilder: (_, __) => const SizedBox(width: _gap),
            itemBuilder: (_, i) {
              final m = post.media[i];
              return SizedBox(
                width: h * baseAspect,
                child: _RoundedTile(
                  m: m,
                  aspect: baseAspect,
                  onTap: () => _openViewerPaged(context, i),
                  onVideoTap: () => _showVideoSheet(
                    context: context,
                    media: m,
                    onFullscreen: () => _openViewerPaged(context, i),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _RoundedTile extends StatelessWidget {
  final _FeedMedia m;
  final double aspect;
  final VoidCallback? onTap; // open fullscreen viewer
  final VoidCallback? onVideoTap; // open popup for video

  const _RoundedTile({
    required this.m,
    required this.aspect,
    this.onTap,
    this.onVideoTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: Colors.black12,
        child: InkWell(
          onTap: () {
            if (m.type == MediaType.video) {
              if (onVideoTap != null) onVideoTap!();
            } else {
              if (onTap != null) onTap!();
            }
          },
          child: AspectRatio(
            aspectRatio: aspect,
            child: (m.type == MediaType.image)
                ? (m.isNetwork
                      ? Image.network(
                          m.path,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('BROKEN IMAGE: ${m.path}');
                            return const SizedBox.shrink();
                          },
                        )
                      : Image.file(
                          File(m.path),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox.shrink();
                          },
                        ))
                : _CoverVideo(path: m.path, isNetwork: m.isNetwork),
          ),
        ),
      ),
    );
  }
}

class FillMedia extends StatelessWidget {
  final _FeedMedia m;
  const FillMedia({required this.m});
  @override
  Widget build(BuildContext context) {
    if (m.type == MediaType.image) {
      return m.isNetwork
          ? Image.network(
              m.path,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print('BROKEN IMAGE: ${m.path}');
                return const Center(
                  child: Icon(Icons.broken_image, size: 60, color: Colors.grey),
                );
              },
            )
          : Image.file(File(m.path), fit: BoxFit.contain);
    }
    return _CoverVideo(path: m.path, isNetwork: m.isNetwork);
  }
}

class _CoverVideo extends StatefulWidget {
  final String path;
  final bool isNetwork;
  const _CoverVideo({required this.path, required this.isNetwork});
  @override
  State<_CoverVideo> createState() => _CoverVideoState();
}

class _CoverVideoState extends State<_CoverVideo> {
  VideoPlayerController? _c;
  bool _ready = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _c = widget.isNetwork
        ? VideoPlayerController.networkUrl(Uri.parse(widget.path))
        : VideoPlayerController.file(File(widget.path));
    _c!.setLooping(true);
    _c!.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _c?.pause();
    _c?.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_ready) return;
    setState(() {
      _playing = !_playing;
      _playing ? _c!.play() : _c!.pause();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
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
                  opacity: _playing ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: const Iconify(
                    MaterialSymbols.play_circle,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ======================= FULLSCREEN PAGED VIEWER =======================
class _MediaViewer extends StatefulWidget {
  final List<_FeedMedia> items;
  final int initialIndex;
  const _MediaViewer({required this.items, required this.initialIndex});
  @override
  State<_MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<_MediaViewer> {
  late final PageController _pc;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pc = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pc,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: widget.items.length,
              itemBuilder: (_, i) => _ViewerPage(item: widget.items[i]),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Iconify(MaterialSymbols.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_index + 1}/${widget.items.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerPage extends StatelessWidget {
  final _FeedMedia item;
  const _ViewerPage({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.type == MediaType.image) {
      return Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: item.isNetwork
              ? Image.network(
                  item.path,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print('BROKEN VIEWER IMAGE: ${item.path}');
                    return const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 80,
                        color: Colors.white,
                      ),
                    );
                  },
                )
              : Image.file(File(item.path), fit: BoxFit.contain),
        ),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: 14 / 9,
        child: _CoverVideo(path: item.path, isNetwork: item.isNetwork),
      ),
    );
  }
}

/// ======================= BOTTOM BAR =======================
class _BottomBar extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onReels;
  final VoidCallback onProfile;

  const _BottomBar({
    required this.onAdd,
    required this.onReels,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color.fromARGB(255, 255, 255, 255)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const _BarIcon(icon: MaterialSymbols.home_outline_rounded),
          _BarIcon(
            icon: Ion.search,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FollowSuggestionsPage(),
                ),
              );
            },
          ),
          _AddButton(onTap: onAdd),
          _BarIcon(icon: Ri.youtube_line, onTap: onReels),
          _BarIcon(icon: Gg.profile, onTap: onProfile),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Iconify(
          Teenyicons.add_small_outline,
          color: Color.fromARGB(255, 112, 111, 111),
        ),
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  final String icon;
  final VoidCallback? onTap;
  const _BarIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Iconify(
        icon,
        color: const Color.fromARGB(221, 87, 86, 86),
        size: 30,
      ),
    );
  }
}

/// ======================= UPLOAD PAGE =======================
class UploadPostPage extends StatefulWidget {
  const UploadPostPage({super.key});
  @override
  State<UploadPostPage> createState() => _UploadPostPageState();
}

class _UploadPostPageState extends State<UploadPostPage> {
  final _picker = ImagePicker();
  final _text = TextEditingController();
  final List<PickedMedia> _media = [];
  String? _location;

  bool get _canPost => _text.text.trim().isNotEmpty || _media.isNotEmpty;

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x != null)
      setState(() => _media.add(PickedMedia(File(x.path), MediaType.image)));
  }

  Future<void> _pickMultipleMedia() async {
    final files = await _picker.pickMultipleMedia();
    if (files.isEmpty) return;

    bool isVideoPath(String p) {
      final s = p.toLowerCase();
      return s.endsWith('.mp4') ||
          s.endsWith('.mov') ||
          s.endsWith('.m4v') ||
          s.endsWith('.3gp') ||
          s.endsWith('.webm') ||
          s.endsWith('.mkv') ||
          s.endsWith('.avi');
    }

    setState(() {
      for (final x in files) {
        final type = isVideoPath(x.path) ? MediaType.video : MediaType.image;
        _media.add(PickedMedia(File(x.path), type));
      }
    });
  }

  Future<({String name, String? avatar})> _getCurrentProfile() async {
    final profile = await fetchMyProfile();
    return (name: profile.displayName, avatar: profile.photoURL);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFEFEFEF))),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.black54, fontSize: 15),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'New Post',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _canPost
                            ? Colors.blue
                            : Colors.grey.shade300,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        shape: const StadiumBorder(),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _canPost
                          ? () async {
                              final nav = Navigator.of(context);
                              final allFiles = _media
                                  .map((m) => m.file)
                                  .toList();

                              final postId = await PostService().createPost(
                                caption: _text.text.trim(),
                                files: allFiles,
                              );

                              final me = await _getCurrentProfile();

                              final List<model.PostMedia> normalized = _media
                                  .map<model.PostMedia>((pm) {
                                    return pm.type == MediaType.video
                                        ? model.PostMedia.videoFile(pm.file)
                                        : model.PostMedia.imageFile(pm.file);
                                  })
                                  .toList();

                              final result = model.Post(
                                id: postId,
                                authorName: me.name,
                                authorAvatar: me.avatar ?? '',
                                timeText: 'just now',
                                caption: _text.text.trim(),
                                media: normalized,
                                comments: const [],
                              );

                              if (!mounted) return;
                              nav.pop(result);
                            }
                          : null,
                      child: const Text('Post'),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body (scrollable) ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current user row
                    FutureBuilder<({String name, String? avatar})>(
                      future: _getCurrentProfile(),
                      builder: (context, snap) {
                        final name = snap.data?.name ?? '';
                        final avatar = snap.data?.avatar ?? '';
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey.shade200,
                              foregroundImage: avatar.isNotEmpty
                                  ? NetworkImage(avatar)
                                  : null,
                              onForegroundImageError: avatar.isNotEmpty
                                  ? (_, __) {}
                                  : null,
                              child: const Icon(Icons.person, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Multiline text field (wraps)
                    TextField(
                      controller: _text,
                      onChanged: (_) => setState(() {}),
                      maxLines: null,
                      minLines: 4,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: 'Write something ...',
                        hintStyle: TextStyle(color: Colors.black38),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),

                    if (_location != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.black45,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _location!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (_media.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _PreviewWrap(
                        media: _media,
                        onRemove: (i) => setState(() => _media.removeAt(i)),
                      ),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Action bar ──
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEFEFEF))),
                color: Colors.white,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Media',
                    onPressed: _pickMultipleMedia,
                    icon: const Iconify(Tabler.photo_plus, color: Colors.blue),
                  ),
                  IconButton(
                    tooltip: 'Camera',
                    onPressed: _pickImage,
                    icon: const Iconify(Ph.camera),
                  ),
                  IconButton(
                    tooltip: 'Location',
                    onPressed: () => setState(
                      () => _location = _location == null ? 'Phnom Penh' : null,
                    ),
                    icon: const Iconify(
                      MaterialSymbols.add_location_alt,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ======================= UPLOAD-SCOPE MODELS =======================
enum MediaType { image, video }

class PickedMedia {
  final File file;
  final MediaType type;
  PickedMedia(this.file, this.type);
}

/// ======================= FEED TYPES =======================
class _FeedMedia {
  final String path; // file path or URL
  final MediaType type;
  final bool isNetwork;
  _FeedMedia({required this.path, required this.type, required this.isNetwork});
}

class _Post {
  final String id;
  final String authorId;
  final String username;
  final String avatar; // url or asset; empty -> default asset
  final String time;
  final String caption;
  final List<_FeedMedia> media;
  final CardAspect aspect;

  int likeCount;
  int commentCount;
  int shareCount; // reposts
  bool isLiked;
  bool isShared;
  bool isReposted;

  List<reply.Comment> comments;

  _Post({
    required this.id,
    required this.authorId,
    required this.username,
    required this.avatar,
    required this.time,
    required this.caption,
    required this.media,
    this.aspect = CardAspect.auto,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.isLiked = false,
    this.isShared = false,
    this.isReposted = false,
    List<reply.Comment>? comments,
  }) : comments = comments ?? <reply.Comment>[];
}

final _names = ["tyda-one", "kunthear_kh", "back_tow", "dara.kh", "raa.kh"];

/// ======================= MEDIA PREVIEW WRAP (in upload page) =======================
class _PreviewWrap extends StatelessWidget {
  final List<PickedMedia> media;
  final void Function(int index) onRemove;
  const _PreviewWrap({required this.media, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 10.0;
        final maxW = c.maxWidth;
        final itemW = media.length == 1 ? maxW : (maxW - gap) / 2;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(media.length, (i) {
            final m = media[i];
            final aspect = m.type == MediaType.image ? 9 / 16 : 4 / 5;
            return Stack(
              children: [
                SizedBox(
                  width: itemW,
                  child: AspectRatio(
                    aspectRatio: aspect,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: m.type == MediaType.image
                          ? Image.file(m.file, fit: BoxFit.cover)
                          : const ColoredBox(color: Colors.black12),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: InkWell(
                    onTap: () => onRemove(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 211, 211, 211),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: const Iconify(
                        MaterialSymbols.close,
                        color: Color.fromARGB(255, 71, 71, 71),
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        );
      },
    );
  }
}

/// ======================= STORY VIEWER (multi-item) =======================
class StoryViewer extends StatefulWidget {
  const StoryViewer({super.key, required this.story});
  final Story story;

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  late final PageController _pc;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pc = PageController();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.story.items;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pc,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _StorySlide(item: items[i]),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black,
                      Color(0xCC000000),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.2, 1.0],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Iconify(
                            MaterialSymbols.close,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_index + 1}/${items.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          foregroundImage: widget.story.avatar.isNotEmpty
                              ? NetworkImage(widget.story.avatar)
                              : null,
                          child: widget.story.avatar.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.story.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.story.summary,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(items.length, (i) {
                        final active = i == _index;
                        return Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: active ? Colors.white : Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorySlide extends StatefulWidget {
  const _StorySlide({required this.item});
  final StoryItem item;

  @override
  State<_StorySlide> createState() => _StorySlideState();
}

class _StorySlideState extends State<_StorySlide> {
  VideoPlayerController? _vc;
  bool _ready = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    if (it.isVideo) {
      _vc = it.isLocal
          ? VideoPlayerController.file(File(it.path!))
          : VideoPlayerController.networkUrl(Uri.parse(it.url!));
      _vc!.setLooping(true);
      _vc!.initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _vc!.play();
        _playing = true;
      });
    }
  }

  @override
  void dispose() {
    _vc?.pause();
    _vc?.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_ready || _vc == null) return;
    setState(() {
      _playing = !_playing;
      _playing ? _vc!.play() : _vc!.pause();
    });
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;

    Widget content;
    if (it.isVideo) {
      content = _ready
          ? FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _vc!.value.size.width,
                height: _vc!.value.size.height,
                child: VideoPlayer(_vc!),
              ),
            )
          : const Center(child: CircularProgressIndicator(strokeWidth: 2));
    } else {
      if (it.isLocal && it.path != null) {
        content = Image(
          image: FileImage(File(it.path!)),
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
        );
      } else if (!it.isLocal && it.url != null) {
        content = CachedNetworkImage(
          imageUrl: it.url!,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          placeholder: (_, __) =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorWidget: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white54),
          ),
        );
      } else {
        content = const SizedBox.shrink();
      }
    }

    return Stack(
      children: [
        Positioned.fill(child: content),
        if (it.isVideo)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggle,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _playing ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: const Iconify(
                      MaterialSymbols.play_circle,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (it.caption != null && it.caption!.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 28,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                it.caption!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black38)],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// ======================= FOLLOW BUTTON =======================
class _FollowButton extends StatefulWidget {
  const _FollowButton({required this.authorId});
  final String authorId;

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _isFollowing = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkFollowing();
  }

  Future<void> _checkFollowing() async {
    try {
      final r = await apiGet('/follows/${widget.authorId}');
      final data = expectJson(r);
      if (!mounted) return;
      setState(() {
        _isFollowing = data['isFollowing'] == true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    final prev = _isFollowing;
    setState(() => _isFollowing = !prev);
    try {
      if (!prev) {
        await apiPost('/follows/${widget.authorId}', {});
      } else {
        await apiDelete('/follows/${widget.authorId}');
      }
    } catch (_) {
      if (mounted) setState(() => _isFollowing = prev);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(width: 80, height: 30);

    final following = _isFollowing;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextButton(
          onPressed: _toggle,
          style: TextButton.styleFrom(
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            following ? 'Following' : 'Follow',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
