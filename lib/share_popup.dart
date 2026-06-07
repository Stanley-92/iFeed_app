import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:colorful_iconify_flutter/icons/logos.dart';
import 'package:iconify_flutter/icons/line_md.dart';
import 'package:iconify_flutter/icons/uil.dart';
import 'package:iconify_flutter/icons/ph.dart';
import 'services/api_client.dart';

class ShareTarget {
  final String name;
  final String avatarUrl;
  const ShareTarget(this.name, {this.avatarUrl = ''});
}

/// Opens the share popup as a full-screen bottom sheet.
Future<void> showPlaneSharePopup(
  BuildContext context, {
  required String shareLink,
  String hint = 'Write something ...',
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShareCard(shareLink: shareLink, hint: hint),
  );
}

class _ShareCard extends StatefulWidget {
  const _ShareCard({required this.shareLink, required this.hint});
  final String shareLink;
  final String hint;

  @override
  State<_ShareCard> createState() => _ShareCardState();
}

class _ShareCardState extends State<_ShareCard> {
  List<ShareTarget> _users = [];
  bool _loadingUsers = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final r = await apiGet('/follows/following');
      final list = expectJsonList(r);
      final users = list.map((raw) {
        final d = raw as Map<String, dynamic>;
        final name = (d['displayName'] ?? d['username'] ?? '').toString();
        final avatar = (d['photoURL'] ?? d['avatarUrl'] ?? '').toString();
        return ShareTarget(name.isNotEmpty ? name : 'User', avatarUrl: avatar);
      }).toList();
      if (mounted) setState(() { _users = users; _loadingUsers = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    const borderGray = Color(0xFFE6E6E6);
    const chipGray = Color(0xFFF0F0F0);
    final screenH = MediaQuery.of(context).size.height;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom
        + MediaQuery.of(context).padding.bottom;

    return Container(
      height: screenH * 0.52,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(18, 12, 18, 20 + bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCCCCCC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Pill-shaped input
          TextField(
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(color: Colors.black45, fontSize: 14),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              filled: true,
              fillColor: chipGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: const BorderSide(color: borderGray),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Horizontal scrollable user row — fixed height
          SizedBox(
            height: 100,
            child: _loadingUsers
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _users.isEmpty
                    ? const Center(
                        child: Text('No users', style: TextStyle(color: Colors.black45)),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 18),
                        itemBuilder: (_, i) {
                          final t = _users[i];
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: borderGray, width: 1.5),
                                ),
                                child: ClipOval(
                                  child: t.avatarUrl.isEmpty
                                      ? const Center(
                                          child: Iconify(LineMd.account, size: 28, color: Color(0xFF888888)),
                                        )
                                      : Image.network(
                                          t.avatarUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Center(
                                            child: Iconify(LineMd.account, size: 28, color: Color(0xFF888888)),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 58,
                                child: Text(
                                  t.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),

          const Spacer(),
          const Divider(height: 1, color: borderGray),
          const SizedBox(height: 14),

          // Action chips pinned at bottom
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionChip(
                label: 'Copy',
                icon: const Iconify(Ph.link_bold, size: 22),
                borderGray: borderGray,
                border: Border.all(color: borderGray, width: 1.5),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: widget.shareLink));
                  _toast('Link copied');
                },
              ),
              _ActionChip(
                label: 'Story',
                icon: const Iconify(Ph.star_four, size: 22),
                borderGray: borderGray,
                border: Border.all(color: borderGray, width: 1.5),
                onTap: () => _toast('Shared to Story'),
              ),
              _ActionChip(
                label: 'Telegram',
                icon: const Iconify(Logos.telegram, size: 50),
                borderGray: Colors.transparent,
                onTap: () => _toast('Opened Telegram'),
              ),
              _ActionChip(
                label: 'Facebook',
                icon: const Iconify(Logos.facebook, size: 50),
                borderGray: Colors.transparent,
                onTap: () => _toast('Opened Facebook'),
              ),
              _ActionChip(
                label: 'iFeed',
                icon: const Iconify(Uil.comment, size: 30, color: Colors.white),
                borderGray: Colors.transparent,
                backgroundColor: const Color(0xFF22C55E),
                onTap: () => _toast('Shared to iFeed'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.borderGray,
    this.border,
    this.backgroundColor = Colors.white, // new optional param
    required this.onTap,
  });


  final Widget icon;
  final String label;
  final Color borderGray;
  final Border? border;
  final Color backgroundColor;
  final VoidCallback onTap;


  @override
  Widget build(BuildContext context) {
    final BoxBorder? resolvedBorder =
        border ?? (borderGray.opacity == 0 ? null : Border.all(color: borderGray, width: 1));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: backgroundColor, // ← use new color here
              borderRadius: BorderRadius.circular(12),
              border: resolvedBorder,
            ),
            child: Center(child: icon),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(.9)),
          ),
        ],
      ),
    );
  }
}