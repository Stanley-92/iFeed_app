// activity_page.dart
import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/material_symbols.dart';
import 'package:iconify_flutter/icons/ion.dart';
import 'package:iconify_flutter/icons/ph.dart';
import 'package:iconify_flutter/icons/gg.dart';

import 'mainfeed.dart' show MainfeedScreen, UploadPostPage;   // Home + composer
import 'suggestions_page.dart';                               // Search
import 'reel_page.dart';                                      // Reels
import 'profile.dart';                                        // Profile page

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});
  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  final List<String> _filters = const ['All', 'Follows', 'Shuffle', 'Replies', 'iFeed'];
  String _selected = 'All';

  // ---- navigation helpers (same routes wiring as other screens) ----
  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainfeedScreen()),
      (route) => false,
    );
  }

  void _openSearch() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FollowSuggestionsPage()));
  }

  void _openComposer() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadPostPage()));
  }

  void _openReels() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReelsPage()));
  }

  void _openProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileUserScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffbf7f6),
      body: SafeArea(
        child: Column(
          children: [
            // ---------- Header ----------
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              color: Colors.white,
              width: double.infinity,
              child: const Text(
                'iFeed',
                style: TextStyle(
                  color: Color(0xff16a34a),
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                ),
              ),
            ),

            // ---------- Filters ----------
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Activity', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _filters.map((f) {
                      final selected = f == _selected;
                      return GestureDetector(
                        onTap: () => setState(() => _selected = f),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xffeef2ff) : Colors.white,
                            border: Border.all(color: const Color(0xffd1d5db)),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? const Color(0xff1f2937) : const Color(0xff374151),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // ---------- Content (empty state) ----------
            Expanded(
              child: Container(
                color: Colors.white,
                width: double.infinity,
                child: const Center(
                  child: Text(
                    'Nothing to see here yet',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // ---------- Bottom bar (EXACT like Mainfeed.dart) ----------
      bottomNavigationBar: Container(
        height: 68,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xffe5e7eb))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BarIcon(icon: MaterialSymbols.home_outline_rounded, onTap: _goHome),
            _BarIcon(icon: Ion.search, onTap: _openSearch),
            _AddButton(onTap: _openComposer),
            _BarIcon(icon: Ph.skip_forward_circle_light, onTap: _openReels),
            _BarIcon(icon: Gg.profile, onTap: _openProfile),
          ],
        ),
      ),
    );
  }
}

// ---- Reusable widgets (identical to Mainfeed) ----
class _BarIcon extends StatelessWidget {
  final String icon;
  final VoidCallback? onTap;
  const _BarIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Iconify(icon, color: const Color.fromARGB(221, 87, 86, 86), size: 30),
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF5B6BFF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}