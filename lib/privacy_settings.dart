// privacy_settings.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/material_symbols.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  // Account
  bool _privateAccount = false;
  bool _approveFollowers = true;

  // Visibility
  String _whoCanSeePosts = 'Everyone';
  String _whoCanSeeStories = 'Everyone';
  String _followersListVisibility = 'Everyone';
  bool _activityStatus = true;

  // Interactions
  String _whoCanComment = 'Everyone';
  String _whoCanMention = 'Everyone';
  String _whoCanMessage = 'Followers';
  bool _allowReposts = true;

  // Discoverability
  bool _showInSearch = true;
  bool _suggestAccount = false;
  bool _syncContacts = false;

  // Data
  bool _personalizedContent = true;
  bool _shareDataWithPartners = false;

  static const _audience = ['Everyone', 'Followers', 'No one'];
  static const _bg = Color(0xFFF2F2F7);
  static const _accent = Color(0xFF6366F1);

  void _pick(String title, String current, void Function(String) onPick) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              ..._audience.map(
                (opt) => InkWell(
                  onTap: () {
                    onPick(opt);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          opt == current
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: opt == current ? _accent : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          opt,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: opt == current
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),

        children: [
          // ── ACCOUNT ─────────────────────────────
          _SectionLabel('ACCOUNT'),
          _Card(
            children: [
              _Tile(                iconColor: Colors.black54,
                label: 'Private account',
                subtitle: 'Only approved followers see your posts',
                trailing: _Switch(
                  value: _privateAccount,
                  onChanged: (v) => setState(() => _privateAccount = v),
                ),
                child: const Iconify(
                  MaterialSymbols.lock,
                  color: Colors.grey,
                  size: 18,
                ),
              ),
              _Divider(),
              _Tile(                iconColor: const Color(0xFF2196F3),
                label: 'Approve followers',
                subtitle: 'Manually approve follow requests',
                trailing: _Switch(
                  value: _approveFollowers,
                  onChanged: (v) => setState(() => _approveFollowers = v),
                ),
                child: const Iconify(
                  MaterialSymbols.person_add_outline_rounded,
                  color: Colors.grey,
                  size: 18,
                ),
              ),
            ],
          ),

          // ── VISIBILITY ──────────────────────────
          _SectionLabel('VISIBILITY'),
          _Card(
            children: [
              _Tile(                iconColor: const Color(0xFF22C55E),
                label: 'Who can see my posts',
                subtitle: 'Control post audience',
                trailing: _Chip(_whoCanSeePosts),
                onTap: () => _pick(
                  'Who can see my posts',
                  _whoCanSeePosts,
                  (v) => setState(() => _whoCanSeePosts = v),
                ),
                child: const Iconify(
                  MaterialSymbols.visibility_outline,
                  color: Color(0xFF22C55E),
                  size: 18,
                ),
              ),
              _Divider(),
              _Tile(                iconColor: const Color(0xFFBF5AF2),
                icon: Icons.auto_stories_outlined,
                label: 'Who can see my stories',
                subtitle: 'Control story audience',
                trailing: _Chip(_whoCanSeeStories),
                onTap: () => _pick(
                  'Who can see my stories',
                  _whoCanSeeStories,
                  (v) => setState(() => _whoCanSeeStories = v),
                ),
              ),
              _Divider(),
              _Tile(                iconColor: const Color(0xFFF59E0B),
                icon: Icons.group_outlined,
                label: 'Followers list visibility',
                subtitle: 'Who can see your followers',
                trailing: _Chip(_followersListVisibility),
                onTap: () => _pick(
                  'Followers list visibility',
                  _followersListVisibility,
                  (v) => setState(() => _followersListVisibility = v),
                ),
              ),
              _Divider(),
              _Tile(                iconColor: const Color(0xFF16A34A),
                icon: Icons.circle,
                label: 'Activity status',
                subtitle: 'Show when you were last active',
                trailing: _Switch(
                  value: _activityStatus,
                  onChanged: (v) => setState(() => _activityStatus = v),
                ),
              ),
            ],
          ),

          // ── INTERACTIONS ────────────────────────
          _SectionLabel('INTERACTIONS'),
          _Card(
            children: [
              _Tile(                iconColor: const Color(0xFFF97316),
                icon: Icons.comment_outlined,
                label: 'Who can comment',
                subtitle: 'On your posts',
                trailing: _Chip(_whoCanComment),
                onTap: () => _pick(
                  'Who can comment',
                  _whoCanComment,
                  (v) => setState(() => _whoCanComment = v),
                ),
              ),
              _Divider(),
              _Tile(                iconColor: const Color(0xFFEAB308),
                icon: Icons.alternate_email,
                label: 'Who can mention me',
                subtitle: 'In posts and comments',
                trailing: _Chip(_whoCanMention),
                onTap: () => _pick(
                  'Who can mention me',
                  _whoCanMention,
                  (v) => setState(() => _whoCanMention = v),
                ),
              ),
              _Divider(),
              _Tile(                iconColor: const Color(0xFF3B82F6),
                icon: Icons.mail_outline,
                label: 'Who can message me',
                subtitle: 'Direct messages',
                trailing: _Chip(_whoCanMessage),
                onTap: () => _pick(
                  'Who can message me',
                  _whoCanMessage,
                  (v) => setState(() => _whoCanMessage = v),
                ),
              ),
              _Divider(),
              _Tile(                iconColor: const Color(0xFF22C55E),
                icon: Icons.repeat,
                label: 'Allow reposts',
                subtitle: 'Let others reshare your posts',
                trailing: _Switch(
                  value: _allowReposts,
                  onChanged: (v) => setState(() => _allowReposts = v),
                ),
              ),
            ],
          ),

          // ── BLOCKING & FILTERING ────────────────
          _SectionLabel('BLOCKING & FILTERING'),
          _Card(
            children: [
              _Tile(                iconColor: const Color(0xFFEF4444),
                icon: Icons.block,
                label: 'Blocked accounts',
                subtitle: 'Manage users you\'ve blocked',
                hasArrow: true,
                onTap: () {},
              ),
              _Divider(),
              _Tile(                iconColor: const Color(0xFFF97316),
                icon: Icons.volume_off_outlined,
                label: 'Muted accounts',
                subtitle: 'Hide content without blocking',
                hasArrow: true,
                onTap: () {},
              ),
              _Divider(),
              _Tile(                iconColor: Colors.black54,
                icon: Icons.filter_alt_outlined,
                label: 'Keyword filters',
                subtitle: 'Hide posts with specific words',
                hasArrow: true,
                onTap: () {},
              ),
            ],
          ),

          // ── DISCOVERABILITY ─────────────────────
          _SectionLabel('DISCOVERABILITY'),
          _Card(
            children: [
              _Tile(                iconColor: const Color(0xFF9333EA),
                icon: Icons.search,
                label: 'Show in search results',
                subtitle: 'Let people find your profile',
                trailing: _Switch(
                  value: _showInSearch,
                  onChanged: (v) => setState(() => _showInSearch = v),
                ),
              ),
              _Divider(),
              _Tile(                iconColor: const Color(0xFF3B82F6),
                icon: Icons.person_search_outlined,
                label: 'Suggest my account',
                subtitle: 'Recommend your profile to others',
                trailing: _Switch(
                  value: _suggestAccount,
                  onChanged: (v) => setState(() => _suggestAccount = v),
                ),
              ),
              _Divider(),
              _Tile(                iconColor: const Color(0xFF22C55E),
                icon: Icons.contacts_outlined,
                label: 'Sync contacts',
                subtitle: 'Find people from your contacts',
                trailing: _Switch(
                  value: _syncContacts,
                  onChanged: (v) => setState(() => _syncContacts = v),
                ),
              ),
            ],
          ),

          // ── DATA & PERSONALIZATION ──────────────
          _SectionLabel('DATA & PERSONALIZATION'),
          _Card(
            children: [
              _Tile(                iconColor: const Color(0xFF3B82F6),
                icon: Icons.tune,
                label: 'Personalized content',
                subtitle: 'Based on your activity',
                trailing: _Switch(
                  value: _personalizedContent,
                  onChanged: (v) => setState(() => _personalizedContent = v),
                ),
              ),
              _Divider(),
              _Tile(                iconColor: Colors.black54,
                icon: Icons.share_outlined,
                label: 'Share data with partners',
                subtitle: 'Third-party data sharing',
                trailing: _Switch(
                  value: _shareDataWithPartners,
                  onChanged: (v) => setState(() => _shareDataWithPartners = v),
                ),
              ),
              _Divider(),
              _Tile(                iconColor: const Color(0xFFE11D48),
                icon: Icons.download_outlined,
                label: 'Download my data',
                subtitle: 'Export posts, comments, media',
                hasArrow: true,
                onTap: () {},
              ),
            ],
          ),

          // ── ACCOUNT ACTIONS ─────────────────────
          _SectionLabel('ACCOUNT ACTIONS'),
          _Card(
            children: [
              _Tile(                iconColor: const Color(0xFFEF4444),
                icon: Icons.pause_circle_outline,
                label: 'Deactivate account',
                subtitle: 'Temporarily disable your profile',
                hasArrow: true,
                labelColor: const Color(0xFFEF4444),
                onTap: () => _confirmAction(
                  context,
                  title: 'Deactivate account?',
                  body:
                      'Your profile will be hidden. You can reactivate anytime.',
                  confirmLabel: 'Deactivate',
                ),
              ),
              _Divider(),
              _Tile(                iconColor: const Color(0xFFEF4444),
                icon: Icons.delete_outline,
                label: 'Delete account',
                subtitle: 'Permanently remove your data',
                hasArrow: true,
                labelColor: const Color(0xFFEF4444),
                onTap: () => _confirmAction(
                  context,
                  title: 'Delete account?',
                  body:
                      'This will permanently delete your account and all data. This cannot be undone.',
                  confirmLabel: 'Delete',
                  isDestructive: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmAction(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          body,
          style: const TextStyle(color: Colors.black54, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black45),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: isDestructive ? const Color(0xFFEF4444) : _accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 7),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.black45,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.iconColor,
    this.icon,
    this.child,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.hasArrow = false,
    this.labelColor,
  }) : assert(icon != null || child != null);

  final Color iconColor;
  final IconData? icon;
  final Widget? child;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool hasArrow;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        child: Row(
          children: [
            child ?? Icon(icon!, color: iconColor, size: 22),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: labelColor ?? Colors.black87,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.black45,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (trailing != null)
              trailing!
            else if (hasArrow)
              const Icon(Icons.chevron_right, size: 18, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right, size: 14, color: Colors.black38),
        ],
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSwitch(
      value: value,
      activeTrackColor: const Color(0xFF6366F1),
      onChanged: onChanged,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 0.5,
      indent: 58,
      color: Color(0xFFEFEFEF),
    );
  }
}
