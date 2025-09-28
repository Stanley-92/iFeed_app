import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:colorful_iconify_flutter/icons/logos.dart';
import 'package:iconify_flutter/icons/line_md.dart';
import 'package:iconify_flutter/icons/uil.dart';
import 'package:iconify_flutter/icons/ph.dart';

class ShareTarget {
  final String name;
  final String avatarUrl;
  const ShareTarget(this.name, {this.avatarUrl = ''});
}

/// Opens the share popup with slide-up-from-bottom animation.
Future<void> showPlaneSharePopup(
  BuildContext context, {
  required String shareLink,
  List<ShareTarget>? targets,
  String hint = 'Write something ...',
}) async {
  final people = targets ?? List.generate(9, (i) => ShareTarget('user_${i + 1}'));

  await showGeneralDialog(
    context: context,
    barrierLabel: 'share',
    barrierDismissible: true,
    barrierColor: Colors.transparent, // keep feed visible
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, __, ___) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      final slide = Tween<Offset>(
        begin: const Offset(0, 1.0), // start off-screen bottom
        end: Offset.zero,            // end centered
      ).animate(curved);

      final scale = Tween<double>(begin: 0.98, end: 1.0).animate(curved);

      final card = _ShareCard(
        shareLink: shareLink,
        hint: hint,
        targets: people,
      );

      return SafeArea(
        child: Padding(
          // keep visible if keyboard opens
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Align(
            alignment: Alignment.center,
            child: SlideTransition(
              position: slide,
              child: FadeTransition(
                opacity: curved,
                child: ScaleTransition(scale: scale, child: card),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.shareLink,
    required this.hint,
    required this.targets,
  });

  final String shareLink;
  final String hint;
  final List<ShareTarget> targets;

  @override
  Widget build(BuildContext context) {
    // Colors to match the mock
    const borderGray = Color(0xFFE6E6E6);
    const chipGray = Color(0xFFF4F4F4);
    final textDim = Colors.black;

    return Material(
      color: Colors.white,
      elevation: 10,                 // a touch higher since barrier is transparent
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Send to anyone !',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color.fromARGB(255, 97, 96, 96),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Inner rounded panel
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color.fromARGB(255, 255, 255, 255), width: 2),
                ),
                padding: const EdgeInsets.fromLTRB(58, 2, 28, 5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Slim input
                    SizedBox(
                      height: 45,
                      child: TextField(
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: hint,
                          hintStyle: const TextStyle(color: Colors.black),
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          filled: true,
                          fillColor: chipGray,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: borderGray),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: borderGray),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: borderGray),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),

                    // 3x3 avatar grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: targets.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: .88,
                      ),
                      itemBuilder: (_, i) {
                        final t = targets[i];

                        final avatar = Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: borderGray , width: 2), // border user 
                        
                          ),
                          child: ClipOval(
                            child: t.avatarUrl.isEmpty
                                ? const Center(
                                    child: Iconify(
                                      LineMd.account,
                                      size: 26,
                                      color: Color.fromARGB(137, 3, 3, 3),
                                    ),
                                  )
                                : Image.network(t.avatarUrl, fit: BoxFit.cover),
                          ),
                        );

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            avatar,
                            const SizedBox(height: 8),
                            Text(
                              t.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: textDim),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: borderGray,),
              
                    const SizedBox(height: 10),

                    // Quick actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ActionChip(
                          label: 'Copy',
                          icon: const Iconify(Ph.link_bold, size: 22),
                          borderGray: borderGray,
                          border: Border.all(color: borderGray, width: 2),
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: shareLink));
                            _toast(context, 'Link copied');
                          },
                        ),
                        _ActionChip(
                          label: 'Story',
                          icon: const Iconify(Ph.star_four, size: 22),
                          borderGray: borderGray,
                          border: Border.all(color: borderGray, width: 2), // custom 2px
                          onTap: () => _toast(context, 'Shared to Story'),
                        ),
                        _ActionChip(
                          label: 'Telegram',
                          icon: const Iconify(Logos.telegram, size: 55),
                          borderGray: Colors.transparent, // no border
                          onTap: () => _toast(context, 'Opened Telegram'),
                        ),
                        _ActionChip(
                          label: 'Facebook',
                          icon: const Iconify(Logos.facebook, size: 55),
                          borderGray: Colors.transparent, // no border
                          onTap: () => _toast(context, 'Opened Facebook'),
                        ),
                       _ActionChip(
  label: 'iFeed',
  icon: const Iconify(Uil.comment, size: 38, color: Colors.white), // white icon
  borderGray: Colors.transparent,
  border: Border.all(color: const Color.fromARGB(255, 36, 231, 19), width: 2),
  backgroundColor: const Color.fromARGB(255, 36, 231, 19), // green fill
  onTap: () => _toast(context, 'Shared to iFeed'),
),

                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _toast(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
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