import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ion.dart';
import 'package:iconify_flutter/icons/material_symbols.dart';
import 'package:iconify_flutter/icons/ri.dart';
import 'package:iconify_flutter/icons/gg.dart';
import 'package:iconify_flutter/icons/teenyicons.dart';
import 'chat.dart';
import 'services/api_client.dart';
import 'reel_page.dart';
import 'profile.dart';
import 'suggestions_page.dart';

class ChatListApp extends StatelessWidget {
  const ChatListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chat List',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFFF9F7F6),
      ),
      home: const ChatListScreen(),
    );
  }
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _search = TextEditingController();

  List<Contact> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    try {
      final r = await apiGet('/follows/following');
      final list = expectJsonList(r);
      final contacts = list.map((raw) {
        final d = raw as Map<String, dynamic>;
        return Contact(
          userId: (d['id'] ?? '').toString(),
          username: (d['displayName'] ?? 'User').toString(),
          avatarUrl: (d['photoURL'] ?? '').toString(),
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _all = contacts;
        _loading = false;
      });
    } catch (e) {
      debugPrint('loadFollowing error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _query => _search.text.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final filtered = _all
        .where((c) => c.username.toLowerCase().contains(_query))
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Chat',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('New chat')));
                    },

                    // FIX: valid Ion icon name for iconify_flutter
                    icon: const Iconify(
                      MaterialSymbols.add_circle_outline_rounded,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(38, 10, 16, 16),
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 25,
                      color: Colors.grey,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFCBD5FF),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 56,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _query.isEmpty
                                ? 'Follow someone to start chatting'
                                : 'No contacts match "$_query"',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(38, 6, 8, 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 2, color: Colors.grey.shade200),
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Chat(
                                  contactName: c.username,
                                  avatarUrl: c.avatarUrl,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.grey.shade300,
                                  foregroundImage: c.avatarUrl.isNotEmpty
                                      ? NetworkImage(c.avatarUrl)
                                      : null,
                                  onForegroundImageError: c.avatarUrl.isNotEmpty
                                      ? (_, __) {}
                                      : null,
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    c.username,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: Container(
        height: 68,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Iconify(
                MaterialSymbols.home_outline_rounded,
                color: Color.fromARGB(221, 87, 86, 86),
                size: 30,
              ),
            ),
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FollowSuggestionsPage(),
                ),
              ),
              icon: const Iconify(
                Ion.search,
                color: Color.fromARGB(221, 87, 86, 86),
                size: 30,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
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
            ),
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReelsPage()),
              ),
              icon: const Iconify(
                Ri.youtube_line,
                color: Color.fromARGB(221, 87, 86, 86),
                size: 30,
              ),
            ),
            IconButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                final uid = await getCurrentUserId();
                if (uid == null || !mounted) return;
                nav.push(
                  MaterialPageRoute(
                    builder: (_) => ProfileUserScreen(userId: uid),
                  ),
                );
              },
              icon: const Iconify(
                Gg.profile,
                color: Color.fromARGB(221, 87, 86, 86),
                size: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Contact {
  final String userId;
  final String username;
  final String avatarUrl;
  Contact({
    required this.userId,
    required this.username,
    required this.avatarUrl,
  });
}
