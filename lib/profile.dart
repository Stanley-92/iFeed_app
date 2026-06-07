// lib/profile.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_client.dart';
import 'services/user_profile_service.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ph.dart';
import 'package:iconify_flutter/icons/ion.dart';
import 'package:iconify_flutter/icons/material_symbols.dart';
import 'package:iconify_flutter/icons/fa.dart';
import 'package:iconify_flutter/icons/gg.dart';
import 'package:iconify_flutter/icons/mdi.dart';
import 'package:iconify_flutter/icons/uil.dart';
import 'package:iconify_flutter/icons/fa6_regular.dart';
import 'package:iconify_flutter/icons/teenyicons.dart';
import 'package:video_player/video_player.dart';

import 'setting_page.dart';
import 'share_popup.dart';
import 'edit_page.dart' show EditProfilePage, ProfileEditResult;
import 'post_modal.dart' as model; // Post, PostMedia, MediaType
import 'suggestions_page.dart';
import 'reel_page.dart';
import 'mainfeed.dart' show MainfeedScreen, UploadPostPage;

// Leave empty string for now; we won't create NetworkImage('') with it.
const String _defaultAvatar = '';

enum _Tab { iFeed, shuffle, media, replies }

class ProfileUserScreen extends StatefulWidget {
  final String userId;

  const ProfileUserScreen({super.key, required this.userId});

  @override
  State<ProfileUserScreen> createState() => _ProfileUserScreenState();
}

class _ProfileUserScreenState extends State<ProfileUserScreen> {
  final List<model.Post> _posts = <model.Post>[];
  final List<_UserReply> _replies = [];
  _Tab _active = _Tab.iFeed;
  bool _loading = false;
  bool _loadingReplies = false;

  // Local editable profile pieces (used for Edit page preview)
  String? _profileAvatarPath;
  String _displayNameFallback = '';
  String _bio = 'Bio';
  String? _currentUserId;

  String get _cacheKey => 'profile_posts_${widget.userId}';

  @override
  void initState() {
    super.initState();
    getCurrentUserId().then((id) {
      if (mounted) setState(() => _currentUserId = id);
    });
    _fetchUserPosts();
    _fetchUserReplies();
  }

  Future<void> _fetchUserReplies() async {
    if (mounted) setState(() => _loadingReplies = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('profile_replies_${widget.userId}');
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        final cached = list
            .map((d) => _UserReply.fromMap(d as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() => _replies..clear()..addAll(cached));
        }
      }
    } catch (e) {
      debugPrint('loadReplies error: $e');
    } finally {
      if (mounted) setState(() => _loadingReplies = false);
    }
  }

  model.Post _postFromMap(Map<String, dynamic> data) {
    final mediaRaw = (data['media'] as List?) ?? [];
    final media = mediaRaw.map<model.PostMedia>((m) {
      final url = (m['url'] as String?) ?? '';
      final typeStr = (m['type'] as String?) ?? 'image';
      return typeStr == 'video'
          ? model.PostMedia.video(url)
          : model.PostMedia.image(url);
    }).toList();
    return model.Post(
      id: (data['_id'] ?? data['id'] ?? '').toString(),
      authorId: (data['authorId'] ?? data['userId'] ?? '').toString(),
      authorName: (data['authorName'] ?? 'User').toString(),
      authorAvatar: (data['authorAvatar'] ?? '').toString(),
      timeText: 'just now',
      caption: (data['caption'] ?? '').toString(),
      media: media,
    );
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || !mounted) return;
      final list = jsonDecode(raw) as List;
      final cached = list.map<model.Post>((d) => _postFromMap(d as Map<String, dynamic>)).toList();
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _posts..clear()..addAll(cached);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveCache(List<model.Post> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = posts.map((p) => {
        '_id': p.id,
        'authorId': p.authorId,
        'authorName': p.authorName,
        'authorAvatar': p.authorAvatar,
        'caption': p.caption,
        'media': p.media.map((m) => {
          'url': m.url ?? '',
          'type': m.type == model.MediaType.video ? 'video' : 'image',
        }).toList(),
      }).toList();
      await prefs.setString(_cacheKey, jsonEncode(json));
    } catch (_) {}
  }

  Future<void> _fetchUserPosts() async {
    if (mounted) setState(() => _loading = true);

    // Show cached posts immediately while fetching
    await _loadCache();

    try {
      final r = await apiGet('/posts?userId=${widget.userId}');
      final list = expectJsonList(r);
      final serverPosts = list.map<model.Post>((raw) =>
          _postFromMap(raw as Map<String, dynamic>)).toList();

      await _saveCache(serverPosts);

      if (!mounted) return;
      setState(() {
        _loading = false;
        final serverIds = serverPosts.map((p) => p.id).toSet();
        final localOnly = _posts.where((p) => !serverIds.contains(p.id)).toList();
        _posts
          ..clear()
          ..addAll(localOnly)
          ..addAll(serverPosts);
      });
    } catch (e) {
      debugPrint('fetchUserPosts error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  ImageProvider? _headerAvatarImage(String? photoUrl) {
    if (_profileAvatarPath != null && _profileAvatarPath!.isNotEmpty) {
      return FileImage(File(_profileAvatarPath!));
    }

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    }

    return null;
  }

  Future<void> openEditProfile(
    BuildContext context, {
    required String currentName,
  }) async {
    // Capture before any await
    final messenger = ScaffoldMessenger.of(context);

    final res = await Navigator.push<ProfileEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          initialName: currentName,
          initialBio: _bio,
          initialAvatarPath: _profileAvatarPath,
          initialBirthDate: null,
        ),
      ),
    );

    if (!mounted || res == null) return;

    try {
      await updateProfile(
        displayName: res.name.isNotEmpty ? res.name : null,
        bio: res.bio.isNotEmpty ? res.bio : null,
        photo: (res.avatarPath != null && res.avatarPath!.isNotEmpty)
            ? File(res.avatarPath!)
            : null,
      );

      setState(() {
        if (res.avatarPath != null && res.avatarPath!.isNotEmpty) {
          _profileAvatarPath = res.avatarPath;
        }
        if (res.name.isNotEmpty) _displayNameFallback = res.name;
        _bio = res.bio;
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
  }

  // ---------- Nav ----------
  void _goHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainfeedScreen()),
      (route) => false,
    );
  }

  void _openSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FollowSuggestionsPage()),
    );
  }

  void _openReels(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReelsPage()),
    );
  }

  Future<void> _openComposer(BuildContext context) async {
    final model.Post? newPost = await Navigator.push<model.Post>(
      context,
      MaterialPageRoute(builder: (_) => const UploadPostPage()),
    );
    if (newPost != null) {
      setState(() {
        _posts.insert(0, newPost);
        _active = newPost.media.isNotEmpty ? _Tab.media : _Tab.iFeed;
      });
    }
  }

  bool _hasMedia(model.Post p) => p.media.isNotEmpty;

  List<model.Post> _mediaOnly() => _posts.where((p) {
        if (!_hasMedia(p)) return false;
        // Keep locally-created posts (authorId not yet set) or posts matching this profile
        return p.authorId.isEmpty || p.authorId == widget.userId;
      }).toList();

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isOwnProfile = _currentUserId == widget.userId;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: apiGet('/users/${widget.userId}').then(expectJson),
          builder: (context, snap) {
            String name = '';
            String email = '';
            String? photoURL;

            if (snap.hasData) {
              final data = snap.data!;
              final n = (data['displayName'] as String?)?.trim();
              if (n != null && n.isNotEmpty) name = n;
              email = (data['email'] as String?) ?? '';
              photoURL = data['photoURL'] as String?;
              final bio = (data['bio'] as String?) ?? '';
              if (bio.isNotEmpty && _bio == 'Bio') _bio = bio;
            }

            // If still blank, use editable fallback (e.g., after Edit page)
            if (name.trim().isEmpty && _displayNameFallback.trim().isNotEmpty) {
              name = _displayNameFallback.trim();
            }

            // ---------- Choose content by tab ----------
            Widget content;
            switch (_active) {
              case _Tab.iFeed:
                if (_loading && _posts.isEmpty) {
                  content = const Center(child: CircularProgressIndicator());
                } else {
                  content = _posts.isEmpty
                      ? _EmptyState(onCreate: () => _openComposer(context))
                      : _ProfileMediaList(posts: _posts);
                }
                break;
              case _Tab.shuffle:
                content = const _NothingYet(label: 'Nothing yet!');
                break;
              case _Tab.media:
                final mediaPosts = _mediaOnly();
                if (_loading && mediaPosts.isEmpty) {
                  content = const Center(child: CircularProgressIndicator());
                } else {
                  content = mediaPosts.isEmpty
                      ? _EmptyState(onCreate: () => _openComposer(context))
                      : _ProfileMediaList(posts: mediaPosts);
                }
                break;
              case _Tab.replies:
                if (_loadingReplies && _replies.isEmpty) {
                  content = const Center(child: CircularProgressIndicator());
                } else if (_replies.isEmpty) {
                  content = const _NothingYet(label: 'No replies yet');
                } else {
                  content = ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: _replies.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _ReplyCard(reply: _replies[i]),
                  );
                }
                break;
            }

            return Column(
              children: [
                // ---------- Header ----------
                Container(
                  padding: const EdgeInsets.fromLTRB(38, 16, 18, 12),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Name + subtitle
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.isEmpty ? '—' : name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontStyle: FontStyle.normal,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email.isEmpty ? '—' : email,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color.fromARGB(137, 19, 16, 16),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Edit button (own profile only)
                          if (isOwnProfile) ...[
                            IconButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              icon: const Iconify(Uil.list_ul, size: 24),
                              onPressed: () =>
                                  openEditProfile(context, currentName: name),
                            ),
                            IconButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              icon: const Iconify(
                                Fa6Regular.pen_to_square,
                                size: 28,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SttingPage(),
                                  ),
                                );
                              },
                            ),
                          ],

                          // Avatar
                          Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () =>
                                  openEditProfile(context, currentName: name),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundImage: _headerAvatarImage(photoURL),
                                backgroundColor: const Color(
                                  0xFFE5E7EB,
                                ), // gray fallback
                                child:
                                    (photoURL == null || photoURL.isEmpty) &&
                                        name.isNotEmpty
                                    ? Text(
                                        name.trim().isNotEmpty
                                            ? name.trim()[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black54,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_bio.isNotEmpty)
                        Text(
                          _bio,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color.fromARGB(240, 0, 0, 0),
                          ),
                        ),

                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          _SmallStat(label: '11k Follower'),
                          SizedBox(width: 18),
                        ],
                      ),
                      const SizedBox(height: 10),

                    ],
                  ),
                ),

                // ---------- Tabs ----------
                Container(
                  height: 78,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: Color.fromARGB(255, 216, 216, 216),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _TabText(
                        'iFeed',
                        isActive: _active == _Tab.iFeed,
                        onTap: () => setState(() => _active = _Tab.iFeed),
                      ),
                      _TabText(
                        'Shuffle',
                        isActive: _active == _Tab.shuffle,
                        onTap: () => setState(() => _active = _Tab.shuffle),
                      ),
                      _TabText(
                        'Media',
                        isActive: _active == _Tab.media,
                        onTap: () => setState(() => _active = _Tab.media),
                      ),
                      _TabText(
                        'Replies',
                        isActive: _active == _Tab.replies,
                        onTap: () => setState(() => _active = _Tab.replies),
                      ),
                    ],
                  ),
                ),

                // ---------- Content ----------
                Expanded(
                  child: Container(
                    color: Colors.white,
                    width: double.infinity,
                    child: content,
                  ),
                ),
              ],
            );
          },
        ),
      ),

      // ---------- Bottom Bar ----------
      bottomNavigationBar: Container(
        height: 68,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xffe5e7eb))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BarIcon(
              icon: MaterialSymbols.home_outline_rounded,
              onTap: () => _goHome(context),
            ),
            _BarIcon(icon: Ion.search, onTap: () => _openSearch(context)),
            _AddButton(onTap: () => _openComposer(context)),
            _BarIcon(
              icon: Ph.play_circle_bold,
              onTap: () => _openReels(context),
            ),
            _BarIcon(
              icon: Gg.profile,
              onTap: () {
                /* already here */
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= Shuffle / Replies placeholder =======================
class _NothingYet extends StatelessWidget {
  const _NothingYet({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label, style: const TextStyle(color: Colors.black54)),
    );
  }
}

// ======================= Media/iFeed: Full post cards =======================
class _ProfileMediaList extends StatelessWidget {
  const _ProfileMediaList({required this.posts});
  final List<model.Post> posts;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (_, i) => ProfilePostCard.fromModel(posts[i]),
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemCount: posts.length,
    );
  }
}

enum PMediaType { image, video }

class ProfileFeedMedia {
  final String path; // file path or URL
  final PMediaType type;
  final bool isNetwork;
  ProfileFeedMedia({
    required this.path,
    required this.type,
    required this.isNetwork,
  });
}

class ProfilePost {
  final String id;
  final String username;
  final String avatar; // url
  final String time;
  final String caption;
  final List<ProfileFeedMedia> media;

  int likeCount;
  int commentCount;
  int shareCount;
  bool isLiked;
  bool isShared;

  ProfilePost({
    required this.id,
    required this.username,
    required this.avatar,
    required this.time,
    required this.caption,
    required this.media,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.isLiked = false,
    this.isShared = false,
  });
}

class ProfilePostCard extends StatefulWidget {
  const ProfilePostCard({super.key, required this.post});
  final ProfilePost post;

  factory ProfilePostCard.fromModel(model.Post p) {
    final media = p.media.map((m) {
      final isNetwork = !m.isLocal;
      final path = m.isLocal ? (m.file?.path ?? '') : (m.url ?? '');
      final type = (m.type == model.MediaType.image)
          ? PMediaType.image
          : PMediaType.video;
      return ProfileFeedMedia(path: path, type: type, isNetwork: isNetwork);
    }).toList();

    return ProfilePostCard(
      post: ProfilePost(
        id: p.id,
        username: p.authorName,
        avatar: (p.authorAvatar.isNotEmpty ? p.authorAvatar : _defaultAvatar),
        time: p.timeText,
        caption: p.caption,
        media: media,
      ),
    );
  }

  @override
  State<ProfilePostCard> createState() => ProfilePostCardState();
}

class ProfilePostCardState extends State<ProfilePostCard> {
  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    final v = (count / 1000).toStringAsFixed(1);
    return v.endsWith('.0') ? '${v.substring(0, v.length - 2)}K' : '${v}K';
  }

  ImageProvider? _avatarProvider(String avatar) {
    if (avatar.isEmpty) return null;
    return NetworkImage(avatar);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(38, 10, 12, 5),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: _avatarProvider(post.avatar),
                  backgroundColor: const Color(0xFFE5E7EB),
                ),
                const SizedBox(width: 18),
                Expanded(
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
                IconButton(
                  icon: const Iconify(Mdi.dots_horizontal, size: 24),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.white,
                      builder: (_) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Iconify(Uil.file_download),
                              title: const Text('Save'),
                              onTap: () => Navigator.pop(context),
                            ),
                            ListTile(
                              leading: const Iconify(Ph.link),
                              title: const Text('Copy link'),
                              onTap: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(100, 0, 12, 18),
              child: Text(
                post.caption,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.35,
                ),
              ),
            ),

          if (post.media.isNotEmpty) _ProfilePostMedia(items: post.media),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(88, 0, 18, 8),
            child: Row(
              children: [
                IconButton(
                  icon: Iconify(
                    post.isLiked ? Ph.heart_fill : Ph.heart_bold,
                    size: 24,
                    color: post.isLiked ? Colors.red : null,
                  ),
                  onPressed: () => setState(() {
                    post.isLiked = !post.isLiked;
                    post.isLiked ? post.likeCount++ : post.likeCount--;
                  }),
                ),
                if (post.likeCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Text(
                      _formatCount(post.likeCount),
                      style: TextStyle(
                        fontSize: 13,
                        color: post.isLiked ? Colors.red : Colors.black54,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Iconify(Uil.comment, size: 24),
                  onPressed: () {},
                ),
                if (post.commentCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0, left: 4),
                    child: Text(
                      _formatCount(post.commentCount),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                IconButton(
                  icon: const Iconify(Ph.shuffle_fill, size: 24),
                  onPressed: () => setState(() => post.shareCount++),
                ),
                if (post.shareCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0, left: 4),
                    child: Text(
                      _formatCount(post.shareCount),
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
                    showPlaneSharePopup(
                      context,
                      shareLink: 'https://ifeed.app/p/${post.id}',
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ProfilePostMedia extends StatelessWidget {
  const _ProfilePostMedia({required this.items});
  final List<ProfileFeedMedia> items;

  static const double _paddingLeft = 96;
  static const double _paddingRight = 12;
  static const double _gap = 6;
  static const double _minH = 220;
  static const double _maxScreenFraction = 0.65;

  @override
  Widget build(BuildContext context) {
    const baseAspect = 4 / 5;

    return LayoutBuilder(
      builder: (context, c) {
        final contentW = c.maxWidth - _paddingLeft - _paddingRight;
        final naturalH = contentW / baseAspect;
        final maxH = MediaQuery.of(context).size.height * _maxScreenFraction;
        final h = naturalH.clamp(_minH, maxH);

        if (items.length == 1) {
          return Padding(
            padding: const EdgeInsets.only(
              left: _paddingLeft,
              right: _paddingRight,
            ),
            child: SizedBox(
              height: h,
              child: _RoundedTile(m: items.first, aspect: baseAspect),
            ),
          );
        }

        if (items.length == 2) {
          const aspect2 = 4 / 5;
          final perTileW = (contentW - _gap) / 2;
          final rowH = (perTileW / aspect2).clamp(_minH, maxH);

          return Padding(
            padding: const EdgeInsets.only(
              left: _paddingLeft,
              right: _paddingRight,
            ),
            child: SizedBox(
              height: rowH,
              child: Row(
                children: [
                  Expanded(child: _RoundedTile(m: items[0], aspect: aspect2)),
                  const SizedBox(width: _gap),
                  Expanded(child: _RoundedTile(m: items[1], aspect: aspect2)),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          height: h,
          child: ListView.separated(
            padding: const EdgeInsets.only(
              left: _paddingLeft,
              right: _paddingRight,
            ),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: _gap),
            itemBuilder: (_, i) => SizedBox(
              width: h * baseAspect,
              child: _RoundedTile(m: items[i], aspect: baseAspect),
            ),
          ),
        );
      },
    );
  }
}

class _RoundedTile extends StatelessWidget {
  final ProfileFeedMedia m;
  final double aspect;
  const _RoundedTile({required this.m, required this.aspect});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: aspect,
        child: m.type == PMediaType.image
            ? (m.isNetwork
                  ? Image.network(
                      m.path,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('PROFILE BROKEN IMAGE: ${m.path}');
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    )
                  : Image.file(File(m.path), fit: BoxFit.cover))
            : _CoverVideo(path: m.path, isNetwork: m.isNetwork),
      ),
    );
  }
}

/// Small inline video (tap to play/pause)

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
                    Ph.play_bold,
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

// ======================= Bar icon =======================
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

class _SmallStat extends StatelessWidget {
  final String label;
  const _SmallStat({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 11.5, color: Colors.black54),
    );
  }
}

class _TabText extends StatelessWidget {
  final String text;
  final bool isActive;
  final VoidCallback? onTap;
  const _TabText(this.text, {this.isActive = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = isActive ? Colors.black : Colors.black87;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: c,
            ),
          ),
          const SizedBox(height: 3),
          if (isActive)
            Container(
              width: 25,
              height: 3,
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 36, 64, 223),
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 128,
          height: 92,
          decoration: BoxDecoration(
            color: const Color(0xffe8edff),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Center(
            child: Iconify(Fa.envelope, size: 58, color: Color(0xff3d5afe)),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          "Now you're all up here !",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 28),
        ),
        const SizedBox(height: 28),
        const Text(
          'Start new conversation by creating a post',
          style: TextStyle(fontSize: 15, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xff3d5afe),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(15)),
            ),
          ),
          onPressed: onCreate,
          child: const Text('Create post'),
        ),
      ],
    );
  }
}

// ======================= User Reply model =======================
class _UserReply {
  final String id;
  final String postId;
  final String postAuthorName;
  final String postAuthorAvatar;
  final String text;
  final String time;
  final int likeCount;

  const _UserReply({
    required this.id,
    required this.postId,
    required this.postAuthorName,
    required this.postAuthorAvatar,
    required this.text,
    required this.time,
    this.likeCount = 0,
  });

  factory _UserReply.fromMap(Map<String, dynamic> d) => _UserReply(
        id: (d['_id'] ?? d['id'] ?? '').toString(),
        postId: (d['postId'] ?? '').toString(),
        postAuthorName: (d['postAuthorName'] ?? d['replyTo'] ?? 'someone').toString(),
        postAuthorAvatar: (d['postAuthorAvatar'] ?? '').toString(),
        text: (d['text'] ?? d['content'] ?? '').toString(),
        time: (d['createdAt'] ?? d['time'] ?? 'just now').toString(),
        likeCount: (d['likeCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        '_id': id,
        'postId': postId,
        'postAuthorName': postAuthorName,
        'postAuthorAvatar': postAuthorAvatar,
        'text': text,
        'time': time,
        'likeCount': likeCount,
      };
}

// ======================= Reply card =======================
class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.reply});
  final _UserReply reply;

  ImageProvider? _avatarProvider(String url) {
    if (url.isEmpty) return null;
    if (url.startsWith('http')) return NetworkImage(url);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(38, 12, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: _avatarProvider(reply.postAuthorAvatar),
            backgroundColor: const Color(0xFFE5E7EB),
            child: reply.postAuthorAvatar.isEmpty
                ? Text(
                    reply.postAuthorName.isNotEmpty
                        ? reply.postAuthorName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Replying to" header
                Row(
                  children: [
                    Text(
                      reply.postAuthorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      reply.time,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Replying to @${reply.postAuthorName}',
                  style: const TextStyle(
                    color: Color(0xff3d5afe),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                // Reply text
                Text(
                  reply.text,
                  style: const TextStyle(fontSize: 15, height: 1.35),
                ),
                const SizedBox(height: 8),
                // Like count
                if (reply.likeCount > 0)
                  Row(
                    children: [
                      const Icon(Icons.favorite_border, size: 16, color: Colors.black45),
                      const SizedBox(width: 4),
                      Text(
                        '${reply.likeCount}',
                        style: const TextStyle(fontSize: 13, color: Colors.black45),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
