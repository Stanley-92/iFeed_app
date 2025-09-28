// edit_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/uil.dart';
import 'package:iconify_flutter/icons/material_symbols.dart';

class ProfileEditResult {
  final String? avatarPath;     // local file path from gallery
  final String name;
  final String bio;
  final DateTime? birthDate;
  final bool shareAsFirstPost;

  const ProfileEditResult({
    required this.avatarPath,
    required this.name,
    required this.bio,
    required this.birthDate,
    required this.shareAsFirstPost,
  });
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    this.initialName = 'sinayun_xyn',
    this.initialBio = 'Life is Good alway bring you a nice\none way to heaven',
    this.initialAvatarPath,
    this.initialBirthDate,
  });

  final String initialName;
  final String initialBio;
  final String? initialAvatarPath;
  final DateTime? initialBirthDate;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;

  DateTime? _birthDate;
  bool _shareAsFirstPost = false;
  File? _pickedAvatar;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _bioCtrl = TextEditingController(text: widget.initialBio);
    _birthDate = widget.initialBirthDate;
    if (widget.initialAvatarPath != null && widget.initialAvatarPath!.isNotEmpty) {
      _pickedAvatar = File(widget.initialAvatarPath!);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img != null) setState(() => _pickedAvatar = File(img.path));
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 70, 1, 1);
    final last = DateTime(now.year - 10, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: const Color(0xFF3B5BFF)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  String get _birthDateLabel {
    if (_birthDate == null) return 'Birth date';
    return '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}';
  }

  ImageProvider<Object> _avatarImage() {
    if (_pickedAvatar != null) return FileImage(_pickedAvatar!);
    return const NetworkImage(
      'https://images.unsplash.com/photo-1520975938430-b8e3c02e6f3a?q=80&w=200&auto=format&fit=crop',
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final result = ProfileEditResult(
      avatarPath: _pickedAvatar?.path, // null if unchanged
      name: _nameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      birthDate: _birthDate,
      shareAsFirstPost: _shareAsFirstPost,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF3B5BFF);
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F6),
  appBar: AppBar(
  leading: IconButton(
    icon: const Iconify(MaterialSymbols.arrow_back_ios),
    onPressed: () => Navigator.pop(context),
  ),
  elevation: 0,
  backgroundColor: Colors.transparent,
  foregroundColor: Colors.black87,
  title: const Text('Edit'),
  centerTitle: false,
  actions: const [
    Padding(
      padding: EdgeInsets.only(right: 16),
     // child: Iconify(Uil.setting, size: 20),
    )
  ],
),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const SizedBox(height: 6),
                    const Text(
                      'Profile Photo added',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 18),

                 
                 
                 
                 
                    // Avatar + camera badge
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius:58,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: _avatarImage(),
                          ),
                          InkWell(
                            onTap: _pickAvatar,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              decoration: BoxDecoration(
                                color: primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Iconify(MaterialSymbols.android_camera_outline, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Name
                    _FormLabel('Name', fontSize: 18 ,color: Colors.black,),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: _inputDecoration(hint: 'Your name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
                    ),
                    const SizedBox(height: 14),

                    // Bio
                    _FormLabel('Bio', fontSize: 18 ,color: Colors.black,),
                    TextFormField(
                      controller: _bioCtrl,
                      maxLines: 3,
                      decoration: _inputDecoration(hint: 'Tell people about you'),
                    ),
                    const SizedBox(height: 14),

                    // Birth date
                    _FormLabel('Birth date', fontSize: 18 ,color: Colors.black,),
                    InkWell(
                      onTap: _pickBirthDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: _inputDecoration(),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _birthDateLabel,
                                style: TextStyle(
                                  color: _birthDate == null ? Colors.grey : const Color.fromARGB(221, 0, 0, 0),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const Iconify(Uil.angle_down, size: 28, color: Color.fromARGB(255, 12, 12, 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Show verify badge (static CTA)
                    _FormLabel('Show verify badge', fontSize: 18 ,color: Colors.black,),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                      //decoration: _boxDecoration(),
                      child: Row(
                        children: [
                          const SizedBox(width: 18),
                          const Expanded(
                            child: Text(
                              
                              'Open verify badge your profile will show up everywhere\n help your audience feel trust your real account.',
                              style: TextStyle(fontSize: 13, color: Colors.black87, height: 2),
                            ),
                          ),
                          const Iconify(MaterialSymbols.verified_outline, size: 28, color: Color(0xFF3B5BFF)),
                          TextButton(
                            onPressed: () {/* navigate to subscribe */},
                            child: const Text('Subscribe'),
                            
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Share to a post
                   _FormLabel('Share this photo to a post', fontSize: 18 ,color: Colors.black,),
                    Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: _boxDecoration(),
                      
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                            'Make this photo your first post so people can like and comment on it.',
                            style: TextStyle(fontSize: 13.5),
                            ),
                          ),
                          Switch.adaptive(
                            value: _shareAsFirstPost,
                            onChanged: (v) => setState(() => _shareAsFirstPost = v),
                            activeColor: Colors.white,
                            activeTrackColor: primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Next button
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        onPressed: _submit,
                        child: const Text('Next', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Change photo link
                    Center(
                      child: TextButton(
                        onPressed: _pickAvatar,
                        child: const Text('Change photo'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B5BFF)),
        ),
      );

  BoxDecoration _boxDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      );
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(
    this.text, {
    this.fontSize = 12,
    this.color = Colors.black54,
    super.key,
  });

  final String text;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 2),
      child: Text(
        text,
        style: TextStyle(fontSize: fontSize, color: color),
      ),
    );
  }
}