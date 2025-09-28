import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: FollowSuggestionsPage()));

class FollowSuggestionsPage extends StatefulWidget {
  const FollowSuggestionsPage({super.key});

  @override
  State<FollowSuggestionsPage> createState() => _FollowSuggestionsPageState();
}

class _FollowSuggestionsPageState extends State<FollowSuggestionsPage> {
  final TextEditingController _search = TextEditingController();

  final List<_Suggestion> _all = const [
    _Suggestion(
      username: 'sinayun_xyn',
      bio: 'Makeup Artist and Blogger @huda.',
      followers: 700,
      avatarUrl:
          'https://i.pravatar.cc/100?img=5', // swap with your asset if you want
    ),
    _Suggestion(
      username: 'sinayun_xyn',
      bio: 'Makeup Artist and Blogger @huda.',
      followers: 700,
      avatarUrl: 'https://i.pravatar.cc/100?img=15',
    ),
    _Suggestion(
      username: 'sinayun_xyn',
      bio: 'Makeup Artist and Blogger @huda.',
      followers: 700,
      avatarUrl: 'https://i.pravatar.cc/100?img=25',
    ),
  ];

  final Set<int> _following = {}; // store indices of following

  String get _query => _search.text.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final filtered = _all
        .asMap()
        .entries
        .where((e) =>
            _query.isEmpty ||
            e.value.username.toLowerCase().contains(_query) ||
            e.value.bio.toLowerCase().contains(_query))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          
          color: Colors.black87,
          onPressed: () {
          Navigator.pop(context); // ⬅️ goes back to Main
          },
          
        ),
        title: const Text(
          'Suggested',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide:
                        const BorderSide(color: Color(0xFFBEC7FF), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide:
                        const BorderSide(color: Color(0xFF7886FF), width: 1.5),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FF),
                ),
              ),
            ),

            // Section title
            const Padding(
              padding: EdgeInsets.fromLTRB(28, 6, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Follow suggestions',
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),

            const Divider(height: 1),

            // List
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final idx = filtered[i].key;
                  final s = filtered[i].value;
                  final isFollowing = _following.contains(idx);

                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Avatar(url: s.avatarUrl),
                        const SizedBox(width: 15),
                        // texts
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.username,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                s.bio,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                '${s.followers} followers',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color.fromARGB(255, 43, 42, 42),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        // Follow button
                        _FollowButton(
                          isFollowing: isFollowing,
                          onTap: () {
                            setState(() {
                              if (isFollowing) {
                                _following.remove(idx);
                              } else {
                                _following.add(idx);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Suggestion {
  final String username;
  final String bio;
  final int followers;
  final String avatarUrl;

  const _Suggestion({
    required this.username,
    required this.bio,
    required this.followers,
    required this.avatarUrl,
  });
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 25,
      backgroundColor: const Color(0xFFE9ECFF),
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, __) {},
      child: url.isEmpty ? const Icon(Icons.person) : null,
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.isFollowing, required this.onTap});
  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isFollowing ? Colors.grey.shade200 : Colors.black87;
    final fg = isFollowing ? Colors.black87 : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: ShapeDecoration(
          color: bg,
          shape: const StadiumBorder(),
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}