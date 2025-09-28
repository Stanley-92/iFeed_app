// profile.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ph.dart';
import 'package:iconify_flutter/icons/ion.dart';
import 'package:iconify_flutter/icons/material_symbols.dart';
import 'package:iconify_flutter/icons/fa.dart';
import 'package:iconify_flutter/icons/gg.dart';
import 'package:iconify_flutter/icons/mdi.dart';
import 'package:iconify_flutter/icons/uil.dart';
import 'package:video_player/video_player.dart';
import 'package:iconify_flutter/icons/fa6_regular.dart';

import 'setting_page.dart';
import 'package:iconify_flutter/icons/teenyicons.dart';
import 'share_popup.dart';
import 'edit_page.dart' show EditProfilePage, ProfileEditResult;
import 'post_modal.dart' as model; // Post, PostMedia, MediaType
import 'suggestions_page.dart';
import 'reel_page.dart';
import 'mainfeed.dart' show MainfeedScreen, UploadPostPage;

const String _defaultAvatar = ''; //Avater

class ProfileUserScreen extends StatefulWidget {
  const ProfileUserScreen({super.key});

  @override
  State<ProfileUserScreen> createState() => _ProfileUserScreenState();
}

enum _Tab { iFeed, shuffle, media, replies }

class _ProfileUserScreenState extends State<ProfileUserScreen> {
  final List<model.Post> _posts = <model.Post>[];
  _Tab _active = _Tab.iFeed;

  // Saved profile fields
  String? _profileAvatarPath;
  String _displayName = 'sinayun_xyn'; 
  String _bio = 'Bio';





// ---------- Open Edit page (prefill + await result) ----------
  Future<void> openEditProfile(BuildContext context) async {
    final res = await Navigator.push<ProfileEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          initialName: _displayName,
          initialBio: _bio,
          initialAvatarPath: _profileAvatarPath,
          initialBirthDate: null, // set if you store it in state
        ),
      ),
    );
    if (!mounted || res == null) return;

    setState(() {
      if (res.avatarPath != null && res.avatarPath!.isNotEmpty) {
        _profileAvatarPath = res.avatarPath;
      }
      if (res.name.isNotEmpty) _displayName = res.name;
      _bio = res.bio;
      // You can also store res.birthDate / res.shareAsFirstPost if needed
    });
  }

  ImageProvider<Object> _headerAvatarImage() {
    if (_profileAvatarPath != null && _profileAvatarPath!.isNotEmpty) {
      return FileImage(File(_profileAvatarPath!));
    }
    return const NetworkImage(_defaultAvatar);
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

  
  
  // ---------- Upload (same page as Mainfeed) ----------
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



// ---------- Helpers ----------
  bool _hasMedia(model.Post p) => p.media.isNotEmpty;
  List<model.Post> _mediaOnly() => _posts.where(_hasMedia).toList();

  @override
  Widget build(BuildContext context) {
   

   
   
 // Choose content by tab
    Widget content;
    switch (_active) {
      case _Tab.iFeed:
        content = _posts.isEmpty
            ? _EmptyState(onCreate: () => _openComposer(context))
            : _ProfileMediaList(posts: _posts);
        break;
      case _Tab.shuffle:
        content = const _NothingYet(label: 'Nothing yet!');
        break;
      case _Tab.media:
        final mediaPosts = _mediaOnly();
        content = mediaPosts.isEmpty
            ? const _NothingYet(label: 'No media yet')
            : _ProfileMediaList(posts: mediaPosts);
        break;
      case _Tab.replies:
        content = const _NothingYet(label: 'No replies yet');
        break;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
           
           
 // ---------- Header ----------
            Container(
              padding: const EdgeInsets.fromLTRB(38, 16, 18, 12),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '', // iFeed Logo here
                    style: TextStyle(
                      color: Color(0xff16a34a),
                      fontWeight: FontWeight.w800,
                      fontSize: 48,
                      letterSpacing: .2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Name + (static role line if you want)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontStyle: FontStyle.normal,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                            'Software Engineer',
                              style: TextStyle(
                                fontSize: 15,
                                color: Color.fromARGB(137, 19, 16, 16),
                              ),
                            ),
                          ],
                        ),
                      ),


//Icon Action Top
                      IconButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        icon: const Iconify(Uil.list_ul, size: 24),
                        onPressed: () => openEditProfile(context),
                      ),
IconButton(
   padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
  icon: const Iconify(
    Fa6Regular.pen_to_square,
    size: 28,
  ),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SttingPage()),
    );
  },
),

                      // Avatar image (tap to edit)
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => openEditProfile(context),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundImage: _headerAvatarImage(),
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
                  _SmallStat(label: 'joined 2017'),
                ],
              ),
            ),

            
            
            // ---------- Tabs ----------
            Container(
              height: 78,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color.fromARGB(255, 216, 216, 216)),
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
            _BarIcon(icon: Gg.profile, onTap: () {/* already here */}),
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

/// Lightweight feed types mirroring mainfeed.dart for rendering
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
      final type =
          (m.type == model.MediaType.image) ? PMediaType.image : PMediaType.video;
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

  ImageProvider _avatarProvider(String avatar) {
    if (avatar.isEmpty) return const NetworkImage(_defaultAvatar);
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
             
             
             
                // Avatar image Profile
                CircleAvatar(
                  radius: 30,
                  backgroundImage: _avatarProvider(post.avatar),
                  onBackgroundImageError: (_, __) {},
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.username,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                      Text(
                        post.time,
                        style:
                            const TextStyle(color: Colors.black54, fontSize: 12),
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

          // Caption
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

          // Media (single / two / horizontal list)
          if (post.media.isNotEmpty) _ProfilePostMedia(items: post.media),

          
          
          // Actions (heart / comment / shuffle / share)
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
                  onPressed: () {
                    // hook to your Comments page if you want (same as mainfeed.dart)
                  },
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
                    post.isShared ? Ph.paper_plane_tilt_fill : Ph.paper_plane_tilt,
                    size: 24,
                    color: post.isShared ? Colors.blue : null,
                  ),
                  onPressed: () {
                    showPlaneSharePopup(context, shareLink: 'https://ifeed.app/p/${post.id}');
                  },  //Action 
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

  static const double _side = 100;
  static const double _gap = 8;
  static const double _minH = 180;
  static const double _maxScreenFraction = 0.55;

  @override
  Widget build(BuildContext context) {
    // auto aspect like mainfeed
    const baseAspect = 9 / 12;

    return LayoutBuilder(builder: (context, c) {
      final contentW = c.maxWidth - _side * 2;
      final naturalH = contentW / baseAspect;
      final maxH = MediaQuery.of(context).size.height * _maxScreenFraction;
      final h = naturalH.clamp(_minH, maxH);

      if (items.length == 1) {
        final m = items.first;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: _side),
          child: SizedBox(
            height: h,
            child: _RoundedTile(m: m, aspect: baseAspect),
          ),
        );
      }

      // handle exactly 2 items
      if (items.length == 1) {
        const aspect2 = 9 / 12;
        final perTileW = (contentW - _gap) / 2;
        final rowH = (perTileW / aspect2).clamp(_minH, maxH);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: _side),
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
          padding: const EdgeInsets.symmetric(horizontal: _side),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: _gap),
          itemBuilder: (_, i) {
            final m = items[i];
            return SizedBox(
              width: h * baseAspect,
              child: _RoundedTile(m: m, aspect: baseAspect),
            );
          },
        ),
      );
    });
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
                ? Image.network(m.path, fit: BoxFit.cover)
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
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
        decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(10)),
        child: const Iconify(Teenyicons.add_small_outline, color: Color.fromARGB(255, 112, 111, 111)),
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
