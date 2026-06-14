import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ph.dart';
import 'package:iconify_flutter/icons/material_symbols.dart';

import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

/// ======================= CHAT SCREEN =======================
class Chat extends StatefulWidget {
  const Chat({super.key, required this.contactName, required this.avatarUrl});

  final String contactName;
  final String avatarUrl;

  @override
  State<Chat> createState() => ChatState();
}

enum AttachmentAction { media, file, camera }

class ChatState extends State<Chat> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final GlobalKey _cameraKey = GlobalKey(); // anchor for popup
  final ImagePicker _picker = ImagePicker(); // media picker
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isLocked = false;
  bool _hasText = false;
  DateTime? _recordStart;
  Timer? _recordTimer;
  int _recordSeconds = 0;
  double _micDragOffset = 0;
  double _lockProgress = 0;
  bool _micCancelled = false;
  bool _showEmojiPicker = false;
  final FocusNode _textFocusNode = FocusNode();

  String get _recordTimeLabel {
    final m = _recordSeconds ~/ 60;
    final s = _recordSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  DateTime? _lastTimestamp;

  String? _makeTimestampLabel() {
    final now = DateTime.now();
    if (_lastTimestamp == null) {
      _lastTimestamp = now;
      return _formatTimestamp(now);
    }
    final sameDay =
        now.year == _lastTimestamp!.year &&
        now.month == _lastTimestamp!.month &&
        now.day == _lastTimestamp!.day;
    if (!sameDay || now.difference(_lastTimestamp!).inMinutes >= 5) {
      _lastTimestamp = now;
      return _formatTimestamp(now);
    }
    return null;
  }

  static String _formatTimestamp(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(t.year, t.month, t.day);
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final min = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour < 12 ? 'AM' : 'PM';
    final time = '$h:$min $ampm';
    if (day == today) return 'Today, $time';
    if (day == yesterday) return 'Yesterday, $time';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[t.weekday - 1]}, ${months[t.month - 1]} ${t.day}, $time';
  }




  final List<ChatMessage> _messages = [];
  ChatMessage? _replyingTo;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _textFocusNode.addListener(() {
      if (_textFocusNode.hasFocus && _showEmojiPicker) {
        setState(() => _showEmojiPicker = false);
      }
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final reply = _replyingTo;
    setState(() {
      _messages.add(
        ChatMessage(
          id: UniqueKey().toString(),
          fromMe: true,
          text: text,
          avatarUrl: 'currentUserAvatar',
          replyTo: reply,
          timestampLabel: _makeTimestampLabel(),
        ),
      );
      _controller.clear();
      _replyingTo = null;
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
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: newPos),
      );
    });
  }

  // =================== Anchored popup ===================
  Future<void> _openAttachmentSheet() async {
    final buttonBox =
        _cameraKey.currentContext!.findRenderObject() as RenderBox;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final btnOrigin = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
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
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .15),
              end: Offset.zero,
            ).animate(curved),
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

  Future<void> _startRecording() async {
    if (_isRecording) return;
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) return;

    _micDragOffset = 0;
    _micCancelled = false;

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: path,
    );

    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _recordStart = DateTime.now();
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  void _lockRecording() {
    if (!_isRecording || _isLocked) return;
    setState(() {
      _isLocked = true;
      _lockProgress = 0;
      _micDragOffset = 0;
    });
  }

  Future<void> _pauseRecording() async {
    if (!_isRecording || _isPaused) return;
    await _audioRecorder.pause();
    _recordTimer?.cancel();
    _recordTimer = null;
    if (mounted) setState(() => _isPaused = true);
  }

  Future<void> _resumeRecording() async {
    if (!_isRecording || !_isPaused) return;
    await _audioRecorder.resume();
    if (!mounted) return;
    setState(() => _isPaused = false);
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    _recordTimer = null;

    final filePath = await _audioRecorder.stop();
    final secs = _recordStart != null
        ? DateTime.now().difference(_recordStart!).inSeconds
        : _recordSeconds;

    setState(() {
      _isRecording = false;
      _isPaused = false;
      _isLocked = false;
      _lockProgress = 0;
      _recordStart = null;
      _recordSeconds = 0;
      _micDragOffset = 0;
      _micCancelled = false;
    });

    if (secs > 0 && filePath != null) {
      final reply = _replyingTo;
      setState(() {
        _replyingTo = null;
        _messages.add(
          ChatMessage(
            id: UniqueKey().toString(),
            fromMe: true,
            avatarUrl: 'currentUserAvatar',
            isVoiceMessage: true,
            voiceDurationSecs: secs,
            voicePath: filePath,
            replyTo: reply,
            timestampLabel: _makeTimestampLabel(),
          ),
        );
      });
      _scrollToBottom();
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    await _audioRecorder.cancel();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _isLocked = false;
      _lockProgress = 0;
      _recordStart = null;
      _recordSeconds = 0;
      _micDragOffset = 0;
      _micCancelled = false;
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _controller.dispose();
    _scroll.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      _textFocusNode.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  // =================== Pickers ===================
  Future<void> _pickMedia() async {
    final List<XFile> xs = await _picker.pickMultiImage(
      imageQuality: 90,
      limit: 9,
    );
    if (xs.isEmpty) return;
    final files = xs.map((x) => File(x.path)).toList();
    final reply = _replyingTo;
    setState(() {
      _replyingTo = null;
      _messages.add(
        ChatMessage(
          id: UniqueKey().toString(),
          fromMe: true,
          imageFiles: files,
          avatarUrl: 'currentUserAvatar',
          replyTo: reply,
          timestampLabel: _makeTimestampLabel(),
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _captureFromCamera() async {
    final XFile? x = await _picker.pickImage(source: ImageSource.camera);
    if (x == null) return;
    final reply = _replyingTo;
    setState(() {
      _replyingTo = null;
      _messages.add(
        ChatMessage(
          id: UniqueKey().toString(),
          fromMe: true,
          imageFile: File(x.path),
          avatarUrl: 'currentUserAvatar',
          replyTo: reply,
          timestampLabel: _makeTimestampLabel(),
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final PlatformFile f = result.files.single;
    final reply = _replyingTo;
    setState(() {
      _replyingTo = null;
      _messages.add(
        ChatMessage(
          id: UniqueKey().toString(),
          fromMe: true,
          fileName: f.name,
          avatarUrl: 'currentUserAvatar',
          filePath: f.path,
          replyTo: reply,
          timestampLabel: _makeTimestampLabel(),
        ),
      );
    });
    _scrollToBottom();
  }

  // =================== UI ===================
  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return PopScope(
      canPop: !_showEmojiPicker,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showEmojiPicker) {
          setState(() => _showEmojiPicker = false);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xfffff9f7),
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                contactName: widget.contactName,
                avatarUrl: widget.avatarUrl,
              ),
              const Divider(height: 1),
              Expanded(
                child: _messages.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Align(
                                alignment: m.fromMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: MessageBubble(
                                  message: m,
                                  onDelete: () => setState(
                                    () => _messages.removeWhere(
                                      (msg) => msg.id == m.id,
                                    ),
                                  ),
                                  onReply: () =>
                                      setState(() => _replyingTo = m),
                                  onSave:
                                      (m.imageFiles != null && m.imageFiles!.isNotEmpty) ||
                                          m.imageFile != null ||
                                          m.imageUrl != null ||
                                          m.videoFile != null
                                      ? () async {
                                          try {
                                            if (m.imageFiles != null &&
                                                m.imageFiles!.isNotEmpty) {
                                              for (final f in m.imageFiles!) {
                                                await Gal.putImage(f.path);
                                              }
                                            } else if (m.videoFile != null) {
                                              await Gal.putVideo(
                                                m.videoFile!.path,
                                              );
                                            } else if (m.imageFile != null) {
                                              await Gal.putImage(
                                                m.imageFile!.path,
                                              );
                                            } else if (m.imageUrl != null) {
                                              final resp = await http.get(
                                                Uri.parse(m.imageUrl!),
                                              );
                                              final tmp =
                                                  await getTemporaryDirectory();
                                              final f = File(
                                                '${tmp.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                              );
                                              await f.writeAsBytes(
                                                resp.bodyBytes,
                                              );
                                              await Gal.putImage(f.path);
                                            }
                                            if (context.mounted) {
                                              final n =
                                                  m.imageFiles?.length ?? 1;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    n > 1
                                                        ? 'Saved $n photos to gallery'
                                                        : 'Saved to gallery',
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Save failed: $e',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      : null,
                                  onCopy: m.text != null
                                      ? () {
                                          Clipboard.setData(
                                            ClipboardData(text: m.text!),
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Copied'),
                                            ),
                                          );
                                        }
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          );
                        },
                      ),
              ),

              // Reply preview bar
              if (_replyingTo != null)
                _ReplyBar(
                  message: _replyingTo!,
                  onCancel: () => setState(() => _replyingTo = null),
                ),

              // Composer
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                color: bg,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _isLocked
                      // ── Locked recording row ──────────────────────────────
                      ? Row(
                          key: const ValueKey('locked'),
                          children: [
                            // 🗑 Trash — cancel recording
                            GestureDetector(
                              onTap: _cancelRecording,
                              child: Container(
                                width: 45,
                                height: 45,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.red.shade400,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Recording bar with pause/resume
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5B5FEF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    _isPaused
                                        ? Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFCDD0FF),
                                              shape: BoxShape.circle,
                                            ),
                                          )
                                        : _PulsingDot(),
                                    const SizedBox(width: 8),
                                    Text(
                                      _recordTimeLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (!_isPaused) _WaveformBars(),
                                    if (_isPaused)
                                      const Text(
                                        'Paused',
                                        style: TextStyle(
                                          color: Color(0xFFCDD0FF),
                                          fontSize: 12,
                                        ),
                                      ),
                                    const Spacer(),
                                    // ⏸ / ▶ toggle
                                    GestureDetector(
                                      onTap: _isPaused
                                          ? _resumeRecording
                                          : _pauseRecording,
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: const BoxDecoration(
                                          color: Color(0x33FFFFFF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _isPaused
                                              ? Icons.play_arrow_rounded
                                              : Icons.pause_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // ➤ Send
                            GestureDetector(
                              onTap: _stopAndSendRecording,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 25,
                                ),
                              ),
                            ),
                          ],
                        )
                      // ── Normal / unlocked recording row ───────────────────
                      : Row(
                          key: const ValueKey('normal'),
                          children: [
                            InkWell(
                              key: _cameraKey,
                              onTap: _isRecording ? null : _openAttachmentSheet,
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
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _isRecording
                                    ? _RecordingInline(
                                        key: const ValueKey('rec'),
                                        seconds: _recordSeconds,
                                        onCancel: _cancelRecording,
                                        micDragOffset: _micDragOffset,
                                        lockProgress: _lockProgress,
                                      )
                                    : Container(
                                        key: const ValueKey('input'),
                                        padding: const EdgeInsets.only(
                                          left: 14,
                                          right: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF2F2F3),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFF466ED6),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _controller,
                                                focusNode: _textFocusNode,
                                                minLines: 1,
                                                maxLines: 5,
                                                decoration:
                                                    const InputDecoration(
                                                      hintText: 'Write…',
                                                      border: InputBorder.none,
                                                    ),
                                                onSubmitted: (_) => _send(),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: _pickMedia,
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                ),
                                                child: Iconify(
                                                  Ph.image_bold,
                                                  size: 22,
                                                  color: Color(0xFF9CA3AF),
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: _toggleEmojiPicker,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                    ),
                                                child: Iconify(
                                                  _showEmojiPicker
                                                      ? Ph.keyboard_bold
                                                      : Ph.smiley_bold,
                                                  size: 22,
                                                  color: _showEmojiPicker
                                                      ? const Color(0xFF617FD0)
                                                      : const Color(0xFF9CA3AF),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Right button: mic / send
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(scale: anim, child: child),
                              child: _hasText
                                  ? InkWell(
                                      key: const ValueKey('send-text'),
                                      onTap: _send,
                                      borderRadius: BorderRadius.circular(24),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF617FD0),
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        child: const Iconify(
                                          Ph.paper_plane_tilt_bold,
                                          color: Color(0xFF303030),
                                          size: 25,
                                        ),
                                      ),
                                    )
                                  : Listener(
                                      key: const ValueKey('mic'),
                                      onPointerDown: (_) => _startRecording(),
                                      onPointerMove: (e) {
                                        if (_micCancelled ||
                                            _isLocked ||
                                            !_isRecording) {
                                          return;
                                        }
                                        // slide left → cancel
                                        if (e.delta.dx < 0) {
                                          setState(
                                            () => _micDragOffset += e.delta.dx
                                                .abs(),
                                          );
                                          if (_micDragOffset >= 120) {
                                            _micCancelled = true;
                                            _cancelRecording();
                                          }
                                        }
                                        // slide up → lock
                                        if (e.delta.dy < 0) {
                                          setState(
                                            () => _lockProgress += e.delta.dy
                                                .abs(),
                                          );
                                          if (_lockProgress >= 80) {
                                            _lockRecording();
                                          }
                                        }
                                      },
                                      onPointerUp: (_) {
                                        if (!_micCancelled && !_isLocked) {
                                          _stopAndSendRecording();
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: _isRecording
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF617FD0),
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        child: const Iconify(
                                          Ph.microphone_bold,
                                          color: Colors.white,
                                          size: 25,
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                ),
              ),

              // ── Emoji picker panel ──────────────────────────────────────
              Offstage(
                offstage: !_showEmojiPicker,
                child: EmojiPicker(
                  textEditingController: _controller,
                  config: Config(
                    height: 280,
                    checkPlatformCompatibility: true,
                    emojiViewConfig: EmojiViewConfig(
                      emojiSizeMax: 28 * (Platform.isIOS ? 1.2 : 1.0),
                      backgroundColor: Colors.white,
                    ),
                    categoryViewConfig: const CategoryViewConfig(
                      initCategory: Category.RECENT,
                      backgroundColor: Colors.white,
                    ),
                    bottomActionBarConfig: const BottomActionBarConfig(
                      enabled: true,
                      backgroundColor: Colors.white,
                      buttonIconColor: Color(0xFF617FD0),
                    ),
                    searchViewConfig: const SearchViewConfig(
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ), // closes PopScope child Scaffold
    ); // closes PopScope
  }
}

/// ======= Voice recording inline — shown while holding mic (unlocked) =======
class _RecordingInline extends StatelessWidget {
  const _RecordingInline({
    super.key,
    required this.seconds,
    required this.onCancel,
    this.micDragOffset = 0,
    this.lockProgress = 0,
  });

  final int seconds;
  final VoidCallback onCancel;
  final double micDragOffset;
  final double lockProgress;

  static const double _cancelThreshold = 120.0;
  static const double _lockThreshold = 80.0;

  String get _timeLabel {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cancelProg = (micDragOffset / _cancelThreshold).clamp(0.0, 1.0);
    final lockProg = (lockProgress / _lockThreshold).clamp(0.0, 1.0);
    // When dragging left, shift the bar leftward
    final shiftX = -micDragOffset * 0.3;

    return Transform.translate(
      offset: Offset(shiftX, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF5B5FEF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            _PulsingDot(),
            const SizedBox(width: 8),
            Text(
              _timeLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(width: 8),
            _WaveformBars(),
            const Spacer(),
            // ↑ Lock hint — visible until threshold reached
            if (lockProg < 0.9)
              Opacity(
                opacity: (1.0 - lockProg).clamp(0.0, 1.0),
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: Color(0xFFCDD0FF),
                        size: 16,
                      ),
                      Text(
                        'Lock',
                        style: TextStyle(
                          color: Color(0xFFCDD0FF),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // ← Cancel hint — visible until threshold reached
            if (cancelProg < 0.9)
              Opacity(
                opacity: (1.0 - cancelProg).clamp(0.0, 1.0),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chevron_left_rounded,
                      color: Color(0xFFCDD0FF),
                      size: 16,
                    ),
                    Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFFCDD0FF), fontSize: 11),
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

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _WaveformBars extends StatefulWidget {
  @override
  State<_WaveformBars> createState() => _WaveformBarsState();
}

class _WaveformBarsState extends State<_WaveformBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value * 2 * 3.14159;
        final heights = [
          8.0 + 8 * (0.5 + 0.5 * math.sin(t)),
          8.0 + 8 * (0.5 + 0.5 * math.sin(t + 1.0)),
          8.0 + 8 * (0.5 + 0.5 * math.sin(t + 2.0)),
          8.0 + 8 * (0.5 + 0.5 * math.sin(t + 0.5)),
          8.0 + 8 * (0.5 + 0.5 * math.sin(t + 1.5)),
        ];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(5, (i) {
            return Container(
              width: 3,
              height: heights[i],
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
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
                  MaterialSymbols.file_copy_outline_rounded,
                  size: 20,
                ),
                label: 'File',
                value: AttachmentAction.file,
                showTopDivider: true,
              ),
              item(
                icon: const Iconify(
                  MaterialSymbols.photo_camera_outline,
                  size: 20,
                ),
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
          CircleAvatar(
            radius: 30,
            backgroundImage:
                (avatarUrl.startsWith('http://') ||
                    avatarUrl.startsWith('https://'))
                ? NetworkImage(avatarUrl)
                : null,
            child:
                (avatarUrl.startsWith('http://') ||
                    avatarUrl.startsWith('https://'))
                ? null
                : const Icon(Icons.person),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contactName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Active 27m ago',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
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
    required this.avatarUrl,
    required this.fromMe,
    this.text,
    this.imageUrl,
    this.timestampLabel,
    this.imageFile,
    this.imageFiles,
    this.videoFile,
    this.fileName,
    this.filePath,
    this.isVoiceMessage = false,
    this.voiceDurationSecs = 0,
    this.voicePath,
    this.replyTo,
  });

  final String id;
  final String? avatarUrl;
  final bool fromMe;
  final String? text;
  final String? imageUrl;
  final String? timestampLabel;

  // local selections
  final File? imageFile;
  final List<File>? imageFiles; // multi-image grid
  final File? videoFile;
  final String? fileName;
  final String? filePath;

  // voice message
  final bool isVoiceMessage;
  final int voiceDurationSecs;
  final String? voicePath;

  // reply
  final ChatMessage? replyTo;
}

/// ===== Helper: pick an icon by extension =====
Icon _fileTypeIcon(String? name) {
  final n = (name ?? '').toLowerCase();
  if (n.endsWith('.pdf')) return const Icon(Icons.picture_as_pdf_rounded);
  if (n.endsWith('.doc') || n.endsWith('.docx')) {
    return const Icon(Icons.description_rounded);
  }
  if (n.endsWith('.xls') || n.endsWith('.xlsx')) {
    return const Icon(Icons.grid_on_rounded);
  }
  if (n.endsWith('.ppt') || n.endsWith('.pptx')) {
    return const Icon(Icons.slideshow_rounded);
  }
  if (n.endsWith('.zip') || n.endsWith('.rar')) {
    return const Icon(Icons.archive_rounded);
  }
  return const Icon(Icons.insert_drive_file_rounded);
}

/// ======================= BUBBLE =======================
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.onDelete,
    this.onReply,
    this.onSave,
    this.onCopy,
  });

  final ChatMessage message;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final VoidCallback? onSave;
  final VoidCallback? onCopy;

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.reply_rounded,
                  color: Color(0xFF617FD0),
                ),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(ctx);
                  onReply?.call();
                },
              ),
              if (onCopy != null)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onCopy!();
                  },
                ),
              if (onSave != null)
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Save to gallery'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onSave!();
                  },
                ),
              if (onDelete != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete!();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = message.fromMe;
    final maxBubble = MediaQuery.of(context).size.width * 0.66;

    Widget content;

    if (message.isVoiceMessage) {
      content = _VoiceMessageBubble(
        durationSecs: message.voiceDurationSecs,
        voicePath: message.voicePath,
      );
    } else if (message.imageFiles != null && message.imageFiles!.isNotEmpty) {
      content = _ImageGrid(
        files: message.imageFiles!,
        maxWidth: maxBubble,
        messageId: message.id,
        onDelete: onDelete,
      );
    } else if (message.imageFile != null) {
      content = GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FullScreenImageViewer(
              file: message.imageFile,
              heroTag: message.id,
              onDelete: onDelete,
            ),
          ),
        ),
        child: Hero(
          tag: message.id,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              message.imageFile!,
              width: maxBubble,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    } else if (message.videoFile != null) {
      content = GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _VideoPlayerScreen(
              file: message.videoFile!,
              onDelete: onDelete,
            ),
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubble),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              alignment: Alignment.center,
              children: [
                _VideoThumb(file: message.videoFile!, width: maxBubble),
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.black87,
                    size: 34,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (message.fileName != null) {
      // ---- file bubble: tap to open with OS viewer
      Future<void> open() async {
        final path = message.filePath;
        if (path == null || path.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot open this file on this platform.'),
            ),
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
          onTap: open,
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
      content = GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FullScreenImageViewer(
              url: message.imageUrl,
              heroTag: message.id,
              onDelete: onDelete,
            ),
          ),
        ),
        child: Hero(
          tag: message.id,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              message.imageUrl!,
              width: maxBubble,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    } else {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubble),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              color: isMe ? Colors.black : Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    // Wrap content with reply quote on top if this is a reply
    Widget bubble = message.replyTo != null
        ? Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReplyQuote(original: message.replyTo!, isMe: isMe),
              const SizedBox(height: 4),
              content,
            ],
          )
        : content;

    // Long-press to show action menu
    bubble = GestureDetector(
      onLongPress: () => _showActions(context),
      child: bubble,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) ...[
          const AvatarSmall(url: 'currentUserAvatar'),
          const SizedBox(width: 8),
        ],
        bubble,
        if (isMe) ...[
          const SizedBox(width: 8),
          const AvatarSmall(url: 'currentUserAvatar'),
        ],
      ],
    );
  }
}

/// ======= small avatar for messages (can be extended to show status) =======
class AvatarSmall extends StatelessWidget {
  const AvatarSmall({super.key, required this.url});

  final String url;

  bool get _isValidUrl =>
      url.startsWith('http://') || url.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 28,
      backgroundImage: _isValidUrl ? NetworkImage(url) : null,
      child: _isValidUrl ? null : const Icon(Icons.person),
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

/// ======================= VOICE MESSAGE BUBBLE =======================
class _VoiceMessageBubble extends StatefulWidget {
  const _VoiceMessageBubble({required this.durationSecs, this.voicePath});
  final int durationSecs;
  final String? voicePath;

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  int _elapsed = 0; // seconds played

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _elapsed = pos.inSeconds);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _elapsed = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (widget.voicePath == null) {
      // demo bubble (no real file)
      setState(() => _isPlaying = !_isPlaying);
      return;
    }
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.play(DeviceFileSource(widget.voicePath!));
      setState(() => _isPlaying = true);
    }
  }

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.durationSecs;
    final progress = total > 0 ? (_elapsed / total).clamp(0.0, 1.0) : 0.0;
    final label = _isPlaying ? _fmt(_elapsed) : _fmt(total);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: const Color(0xFF7C3AED),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            height: 32,
            child: CustomPaint(painter: _WaveformPainter(progress: progress)),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;

  static const _heights = [
    0.35,
    0.65,
    0.90,
    0.50,
    1.00,
    0.70,
    0.40,
    0.80,
    0.55,
    0.30,
    0.75,
    0.45,
    0.95,
    0.60,
    0.35,
    0.85,
    0.50,
    0.70,
    0.40,
    0.65,
  ];

  const _WaveformPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const count = 20;
    const gap = 2.0;
    final barW = (size.width - (count - 1) * gap) / count;

    for (int i = 0; i < count; i++) {
      final played = (i / count) < progress;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: played ? 1.0 : 0.45)
        ..style = PaintingStyle.fill;

      final barH = _heights[i] * size.height;
      final x = i * (barW + gap);
      final y = (size.height - barH) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barW, barH),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.progress != progress;
}

/// ======================= FULL-SCREEN IMAGE VIEWER =======================
class _FullScreenImageViewer extends StatefulWidget {
  const _FullScreenImageViewer({
    this.file,
    this.url,
    required this.heroTag,
    this.onDelete,
  });

  final File? file;
  final String? url;
  final String heroTag;
  final VoidCallback? onDelete;

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (widget.file != null) {
        await Gal.putImage(widget.file!.path);
      } else if (widget.url != null) {
        final resp = await http.get(Uri.parse(widget.url!));
        final tmp = await getTemporaryDirectory();
        final tmpFile = File(
          '${tmp.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await tmpFile.writeAsBytes(resp.bodyBytes);
        await Gal.putImage(tmpFile.path);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved to gallery')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This will remove the message from the chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        Navigator.pop(context);
        widget.onDelete?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider provider = widget.file != null
        ? FileImage(widget.file!) as ImageProvider
        : NetworkImage(widget.url!);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: widget.heroTag,
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5.0,
            child: Image(image: provider, fit: BoxFit.contain),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionBtn(
                icon: _saving
                    ? Icons.hourglass_top_rounded
                    : Icons.download_rounded,
                label: 'Save',
                onTap: _saving ? null : _save,
              ),
              if (widget.onDelete != null)
                _ActionBtn(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: Colors.red.shade300,
                  onTap: _confirmDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ======================= VIDEO PLAYER SCREEN =======================
class _VideoPlayerScreen extends StatefulWidget {
  const _VideoPlayerScreen({required this.file, this.onDelete});
  final File file;
  final VoidCallback? onDelete;

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _ctrl;
  bool _ready = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _ready = true);
          _ctrl.play();
        }
      });
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Gal.putVideo(widget.file.path);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved to gallery')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This will remove the message from the chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        Navigator.pop(context);
        widget.onDelete?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _ready
            ? AspectRatio(
                aspectRatio: _ctrl.value.aspectRatio,
                child: VideoPlayer(_ctrl),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_ready) ...[
                VideoProgressIndicator(
                  _ctrl,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white30,
                    backgroundColor: Colors.white12,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _fmt(_ctrl.value.position),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        _ctrl.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: () =>
                          _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play(),
                    ),
                    const Spacer(),
                    Text(
                      _fmt(_ctrl.value.duration),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 6),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionBtn(
                    icon: _saving
                        ? Icons.hourglass_top_rounded
                        : Icons.download_rounded,
                    label: 'Save',
                    onTap: _saving ? null : _save,
                  ),
                  if (widget.onDelete != null)
                    _ActionBtn(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      color: Colors.red.shade300,
                      onTap: _confirmDelete,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared bottom-bar action button used by both viewer screens.
class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 26),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: c, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ======================= REPLY BAR (above composer) =======================
class _ReplyBar extends StatelessWidget {
  const _ReplyBar({required this.message, required this.onCancel});

  final ChatMessage message;
  final VoidCallback onCancel;

  String get _preview {
    if (message.text != null) return message.text!;
    if (message.isVoiceMessage) return '🎤 Voice message';
    if (message.imageFiles != null && message.imageFiles!.isNotEmpty) {
      final n = message.imageFiles!.length;
      return n == 1 ? '📷 Photo' : '📷 $n Photos';
    }
    if (message.imageFile != null || message.imageUrl != null) {
      return '📷 Photo';
    }
    if (message.videoFile != null) return '🎥 Video';
    if (message.fileName != null) return '📎 ${message.fileName}';
    return 'Message';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4FF),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
          left: const BorderSide(color: Color(0xFF617FD0), width: 3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, size: 18, color: Color(0xFF617FD0)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.fromMe ? 'You' : 'Them',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF617FD0),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
            onPressed: onCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ======================= REPLY QUOTE (inside bubble) =======================
class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({required this.original, required this.isMe});

  final ChatMessage original;
  final bool isMe;

  String get _preview {
    if (original.text != null) return original.text!;
    if (original.isVoiceMessage) return '🎤 Voice message';
    if (original.imageFiles != null && original.imageFiles!.isNotEmpty) {
      final n = original.imageFiles!.length;
      return n == 1 ? '📷 Photo' : '📷 $n Photos';
    }
    if (original.imageFile != null || original.imageUrl != null) {
      return '📷 Photo';
    }
    if (original.videoFile != null) return '🎥 Video';
    if (original.fileName != null) return '📎 ${original.fileName}';
    return 'Message';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.black.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isMe ? const Color(0xFF617FD0) : Colors.white,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            original.fromMe ? 'You' : 'Them',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isMe ? const Color(0xFF617FD0) : Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMe ? Colors.black54 : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================= VIDEO THUMBNAIL =======================
class _VideoThumb extends StatefulWidget {
  const _VideoThumb({required this.file, required this.width});
  final File file;
  final double width;

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final bytes = await VideoThumbnail.thumbnailData(
      video: widget.file.path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: widget.width.round(),
      quality: 75,
    );
    if (mounted && bytes != null) setState(() => _thumb = bytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_thumb != null) {
      return Image.memory(
        _thumb!,
        width: widget.width,
        height: 180,
        fit: BoxFit.cover,
      );
    }
    return Container(
      width: widget.width,
      height: 180,
      color: Colors.black87,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white54,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

// ======================= IMAGE GRID =======================
class _ImageGrid extends StatelessWidget {
  const _ImageGrid({
    required this.files,
    required this.maxWidth,
    required this.messageId,
    this.onDelete,
  });

  final List<File> files;
  final double maxWidth;
  final String messageId;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    const gap = 3.0;
    final half = (maxWidth - gap) / 2;
    final count = files.length;

    void open(int index) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _MultiImageViewer(
            files: files,
            initialIndex: index,
            messageId: messageId,
            onDelete: onDelete,
          ),
        ),
      );
    }

    Widget cell(int index, double w, double h, {bool overflow = false}) {
      final extra = files.length - 4;
      return GestureDetector(
        onTap: () => open(index),
        child: SizedBox(
          width: w,
          height: h,
          child: Hero(
            tag: '${messageId}_$index',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(files[index], fit: BoxFit.cover),
                  if (overflow && extra > 0)
                    ColoredBox(
                      color: Colors.black54,
                      child: Center(
                        child: Text(
                          '+$extra',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── 1 image ──────────────────────────────────────────────
    if (count == 1) {
      return GestureDetector(
        onTap: () => open(0),
        child: Hero(
          tag: '${messageId}_0',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              files[0],
              width: maxWidth,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    // ── 2 images ─────────────────────────────────────────────
    if (count == 2) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            cell(0, half, half),
            const SizedBox(width: gap),
            cell(1, half, half),
          ],
        ),
      );
    }

    // ── 3 images ─────────────────────────────────────────────
    if (count == 3) {
      final bigH = half + gap + half * 0.55;
      final smallH = (bigH - gap) / 2;
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cell(0, half, bigH),
            const SizedBox(width: gap),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                cell(1, half, smallH),
                const SizedBox(height: gap),
                cell(2, half, smallH),
              ],
            ),
          ],
        ),
      );
    }

    // ── 4+ images — 2×2, last cell shows overflow badge ──────
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              cell(0, half, half),
              const SizedBox(width: gap),
              cell(1, half, half),
            ],
          ),
          const SizedBox(height: gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              cell(2, half, half),
              const SizedBox(width: gap),
              cell(3, half, half, overflow: count > 4),
            ],
          ),
        ],
      ),
    );
  }
}

// ======================= MULTI-IMAGE VIEWER =======================
class _MultiImageViewer extends StatefulWidget {
  const _MultiImageViewer({
    required this.files,
    required this.initialIndex,
    required this.messageId,
    this.onDelete,
  });

  final List<File> files;
  final int initialIndex;
  final String messageId;
  final VoidCallback? onDelete;

  @override
  State<_MultiImageViewer> createState() => _MultiImageViewerState();
}

class _MultiImageViewerState extends State<_MultiImageViewer> {
  late final PageController _page;
  late int _current;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _page = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    try {
      for (final f in widget.files) {
        await Gal.putImage(f.path);
      }
      if (mounted) {
        final n = widget.files.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              n == 1 ? 'Saved to gallery' : 'Saved $n photos to gallery',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This will remove the message from the chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        Navigator.pop(context);
        widget.onDelete?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_current + 1} / ${widget.files.length}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _page,
        itemCount: widget.files.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => Center(
          child: Hero(
            tag: '${widget.messageId}_$i',
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5.0,
              child: Image.file(widget.files[i], fit: BoxFit.contain),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionBtn(
                icon: _saving
                    ? Icons.hourglass_top_rounded
                    : Icons.download_rounded,
                label: widget.files.length == 1 ? 'Save' : 'Save all',
                onTap: _saving ? null : _saveAll,
              ),
              if (widget.onDelete != null)
                _ActionBtn(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: Colors.red.shade300,
                  onTap: _confirmDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
