import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ion.dart';
import 'package:iconify_flutter/icons/ph.dart';
import 'package:iconify_flutter/icons/material_symbols.dart';
import 'chat.dart'; // <-- ensure path is correct

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

  final List<Contact> _all = List.generate(
    20,
    (i) => Contact(
      username: 'sinayun_syn #$i',
      avatarUrl: 'https://i.pravatar.cc/150?img=${(i % 70) + 1}',
      lastActiveAgo: Duration(minutes: (i + 1) * 3),
    ),
  );

  String get _query => _search.text.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final filtered =
        _all.where((c) => c.username.toLowerCase().contains(_query)).toList();

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
                    icon:
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 26),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Chat',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('New chat')),
                      );
                    },
                   
                   
                   
                    // FIX: valid Ion icon name for iconify_flutter

                    icon: const Iconify(MaterialSymbols.add_circle_outline_rounded, size: 26),
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
                    prefixIcon:
                        const Icon(Icons.search, size: 25, color: Colors.grey),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
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
                      borderSide:
                          const BorderSide(color: Color(0xFFCBD5FF), width: 1.4),
                    ),
                  ),
                ),
              ),
            ),

            // List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(38, 6, 8, 8),
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 2, color: Colors.grey.shade200),
                itemBuilder: (context, i) {
                  final c = filtered[i];
                  return InkWell(
                    onTap: () {
                      // OPEN CHAT with selected contact
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
                          horizontal: 8, vertical: 10),
                      child: Row(
                        children: [
                          // Avatar (normal size)
                          CircleAvatar(
                            radius: 22,
                            backgroundImage: NetworkImage(c.avatarUrl),
                            onBackgroundImageError: (_, __) {},
                          ),
                          const SizedBox(width: 12),
                          // Name + (you can add last message later)
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
                          const SizedBox(width: 5),
                          Text(
                            _agoText(c.lastActiveAgo),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
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

      // Bottom bar (static demo)
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Iconify(Ph.chat_circle, size: 26),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Iconify(Ph.heart, size: 26),
            label: 'Likes',
          ),
          BottomNavigationBarItem(
            icon: Iconify(Ion.menu_sharp, size: 26),
            label: 'Menu',
          ),
        ],
      ),
    );
  }

  String _agoText(Duration d) {
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

class Contact {
  final String username;
  final String avatarUrl;
  final Duration lastActiveAgo;
  Contact({
    required this.username,
    required this.avatarUrl,
    required this.lastActiveAgo,
  });
}
