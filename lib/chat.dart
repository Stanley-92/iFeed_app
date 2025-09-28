import 'dart:io';

import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ph.dart';
import 'package:iconify_flutter/icons/material_symbols.dart';

import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';

/// ======================= CHAT SCREEN =======================
class Chat extends StatefulWidget {
  const Chat({
    super.key,
    required this.contactName,
    required this.avatarUrl,
  });

  final String contactName;
  final String avatarUrl;

  @override
  State<Chat> createState() => ChatState();
}

enum AttachmentAction { media, file, camera }

class ChatState extends State<Chat> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final GlobalKey _cameraKey = GlobalKey();   // anchor for popup
  final ImagePicker _picker = ImagePicker();  // media picker

  final List<ChatMessage> _messages = [];

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(
        id: UniqueKey().toString(),
        fromMe: true,
        text: text,
      ));
      _controller.clear();
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void insertAtCursor(String s) {
    final text = _controller.text;
    final sel = _controller.selection;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.end >= 0 ? sel.end : text.length;

    final newText = text.replaceRange(start, end, s);
    final newPos = start + s.length;

    setState(() {
      _controller.text = newText;
      _controller.selection =
          TextSelection.fromPosition(TextPosition(offset: newPos));
    });
  }

  // =================== anchored popup ===================
  Future<void> _openAttachmentSheet() async {
    final buttonBox =
        _cameraKey.currentContext!.findRenderObject() as RenderBox;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final btnOrigin =
        buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final left = btnOrigin.dx;
    final bottom =
        overlayBox.size.height - (btnOrigin.dy + buttonBox.size.height);

    final action = await showGeneralDialog<AttachmentAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'attachments',
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, a1, a2) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(onTap: () => Navigator.of(ctx).pop()),
            ),
            Positioned(
              left: left,
              bottom: bottom + 8,
              child: const _AnchoredPickerBox(),
            ),
          ],
        );
      },
      transitionBuilder: (ctx, anim, __, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0, .15), end: Offset.zero)
                    .animate(curved),
            child: child,
          ),
        );
      },
    );

    if (action != null) _handleAttachmentAction(action);
  }

  void _handleAttachmentAction(AttachmentAction action) {
    switch (action) {
      case AttachmentAction.media:
        _pickMedia();
        break;
      case AttachmentAction.file:
        _pickFile();
        break;
      case AttachmentAction.camera:
        _captureFromCamera();
        break;
    }
  }

  // =================== pickers ===================
  Future<void> _pickMedia() async {
    final XFile? x = await _picker.pickMedia(); // image OR video
    if (x == null) return;

    final isVideo = (x.mimeType?.startsWith('video/') ?? false) ||
        x.path.toLowerCase().endsWith('.mp4');

    setState(() {
      _messages.add(ChatMessage(
        id: UniqueKey().toString(),
        fromMe: true,
        imageFile: isVideo ? null : File(x.path),
        videoFile: isVideo ? File(x.path) : null,
      ));
    });
    _scrollToBottom();
  }

  Future<void> _captureFromCamera() async {
    final XFile? x = await _picker.pickImage(source: ImageSource.camera);
    if (x == null) return;
    setState(() {
      _messages.add(ChatMessage(
        id: UniqueKey().toString(),
        fromMe: true,
        imageFile: File(x.path),
      ));
    });
    _scrollToBottom();
  }

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true, // gives bytes on web (path may be null there)
    );
    if (result == null || result.files.isEmpty) return;

    final PlatformFile f = result.files.single;

    setState(() {
      _messages.add(ChatMessage(
        id: UniqueKey().toString(),
        fromMe: true,
        fileName: f.name,
        filePath: f.path, // null on web; fine on mobile/desktop
      ));
    });
    _scrollToBottom();
  }

  // =================== UI ===================
  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: const Color(0xfffff9f7),
      body: SafeArea(
        child: Column(
          children: [
            _Header(contactName: widget.contactName, avatarUrl: widget.avatarUrl),
            const Divider(height: 1),
            Expanded(
              child: _messages.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        return Column(
                          children: [
                            if (m.timestampLabel != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                m.timestampLabel!,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Align(
                              alignment: m.fromMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: MessageBubble(message: m),
                            ),
                            const SizedBox(height: 10),
                          ],
                        );
                      },
                    ),
            ),

            // Composer
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: bg,
              child: Row(
                children: [
                  InkWell(
                    key: _cameraKey,
                    onTap: _openAttachmentSheet, // anchored popup
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 45,
                      height: 45,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFF696969),
                        shape: BoxShape.circle,
                      ),
                      child: const Iconify(
                        Ph.camera_bold,
                        size: 25,
                        color: Color(0xFFA3A3A3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),

                  Expanded(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF466ED6)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                hintText: 'Write…',
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_horiz),
                            onPressed: () {},
                            tooltip: 'More',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),

                  InkWell(
                    onTap: _send,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF617FD0),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Iconify(
                        Ph.paper_plane_tilt_bold,
                        color: Color(0xFF303030),
                        size: 25,
                      ),
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

/// ======= Small anchored popup box (polished) =======
class _AnchoredPickerBox extends StatelessWidget {
  const _AnchoredPickerBox();

  @override
  Widget build(BuildContext context) {
    Widget item({
      required Iconify icon,
      required String label,
      required AttachmentAction value,
      bool showTopDivider = false,
    }) {
      final row = InkWell(
        onTap: () => Navigator.of(context).pop<AttachmentAction>(value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: icon),
              ),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      );

      if (!showTopDivider) return row;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Divider(height: 1, thickness: 0.7),
          ),
          row,
        ],
      );
    }

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 170,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              item(
                icon: const Iconify(Ph.image_bold, size: 20),
                label: 'Media',
                value: AttachmentAction.media,
              ),
              item(
                icon: const Iconify(
                    MaterialSymbols.file_copy_outline_rounded, size: 20),
                label: 'File',
                value: AttachmentAction.file,
                showTopDivider: true,
              ),
              item(
                icon: const Iconify(
                    MaterialSymbols.photo_camera_outline, size: 20),
                label: 'Camera',
                value: AttachmentAction.camera,
                showTopDivider: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ======================= HEADER =======================
class _Header extends StatelessWidget {
  const _Header({required this.contactName, required this.avatarUrl});

  final String contactName;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new),
            splashRadius: 20,
          ),
          CircleAvatar(radius: 30, backgroundImage: NetworkImage(avatarUrl)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Sinayun_xyn',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                SizedBox(height: 2),
                Text('Active 27m ago',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

/// ======================= MESSAGE MODELS =======================
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.fromMe,
    this.text,
    this.imageUrl,
    this.timestampLabel,
    this.imageFile,
    this.videoFile,
    this.fileName,
    this.filePath,
  });

  final String id;
  final bool fromMe;
  final String? text;
  final String? imageUrl;
  final String? timestampLabel;

  // local selections
  final File? imageFile;     // picked image
  final File? videoFile;     // picked video
  final String? fileName;    // document name
  final String? filePath;    // document path
}

/// ===== helper: pick an icon by extension =====
Icon _fileTypeIcon(String? name) {
  final n = (name ?? '').toLowerCase();
  if (n.endsWith('.pdf')) return const Icon(Icons.picture_as_pdf_rounded);
  if (n.endsWith('.doc') || n.endsWith('.docx')) return const Icon(Icons.description_rounded);
  if (n.endsWith('.xls') || n.endsWith('.xlsx')) return const Icon(Icons.grid_on_rounded);
  if (n.endsWith('.ppt') || n.endsWith('.pptx')) return const Icon(Icons.slideshow_rounded);
  if (n.endsWith('.zip') || n.endsWith('.rar')) return const Icon(Icons.archive_rounded);
  return const Icon(Icons.insert_drive_file_rounded);
}

/// ======================= BUBBLE =======================
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isMe = message.fromMe;
    final maxBubble = MediaQuery.of(context).size.width * 0.66;

    Widget content;

    if (message.imageFile != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child:
            Image.file(message.imageFile!, width: maxBubble, fit: BoxFit.cover),
      );
    } else if (message.videoFile != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubble),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF101828).withOpacity(.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.play_circle_fill, size: 28),
              SizedBox(width: 10),
              Flexible(
                child: Text('Video selected', overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      );
    } else if (message.fileName != null) {
      // ---- file bubble: tap to open with OS viewer
      Future<void> _open() async {
        final path = message.filePath;
        if (path == null || path.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot open this file on this platform.')),
          );
          return;
        }
        final res = await OpenFilex.open(path);
        if (res.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Open failed: ${res.message}')),
          );
        }
      }

      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubble),
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xffeef0f4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _fileTypeIcon(message.fileName),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message.fileName!,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.open_in_new_rounded, size: 18),
              ],
            ),
          ),
        ),
      );
    } else if (message.imageUrl != null && message.imageUrl!.isNotEmpty) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(message.imageUrl!,
            width: maxBubble, fit: BoxFit.cover),
      );
    } else {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubble),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xffeef0f4) : const Color(0xff2f88ff),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isMe ? 14 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 14),
            ),
          ),
          child: Text(
            message.text ?? '',
            style: TextStyle(
                color: isMe ? Colors.black : Colors.white, fontSize: 14),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) ...[
          const AvatarSmall(
            url:
                'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&q=60&auto=format&fit=crop',
          ),
          const SizedBox(width: 8),
        ],
        content,
        if (isMe) ...[
          const SizedBox(width: 8),
          const AvatarSmall(
            url:
                'https://images.unsplash.com/photo-1519345182560-3f2917c472ef?w=300&q=60&auto=format&fit=crop',
          ),
        ],
      ],
    );
  }
}

class AvatarSmall extends StatelessWidget {
  const AvatarSmall({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 28,
      backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=68'),
    );
  }
}

/// Simple empty state when no messages yet
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 25),
        child: Text(
          "No messages yet. Say hi ",
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ),
    );
  }
}
