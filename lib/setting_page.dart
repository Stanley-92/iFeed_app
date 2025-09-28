// stting_page.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/uil.dart';
import 'package:iconify_flutter/icons/ph.dart';
import 'login.dart'; // adjust path if needed


import 'package:iconify_flutter/icons/material_symbols.dart';
import 'package:colorful_iconify_flutter/icons/logos.dart';


class SttingPage extends StatefulWidget {
  const SttingPage({super.key});

  @override
  State<SttingPage> createState() => _SttingPageState();
}

class _SttingPageState extends State<SttingPage> {
  bool _notificationsOn = true;
  bool _darkMode = false;
  bool _switchBottom = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFCF7F6), // soft pinkish like screenshot
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon:  const Iconify(MaterialSymbols.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile Setting', // matches the screenshot heading
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        centerTitle: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFEFEFEF)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Row(
                    children: const [
                      Text(
                        'Seeting', // kept the same spelling as your mock
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F1F1)),



                // List body
                Expanded(
                  child: ListView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    children: [
                   _SettingTile(
  icon: const Iconify(Ph.bell_bold),
  label: 'Notification',
  labelFontSize: 16, // bigger font
  trailing: CupertinoSwitch(
    value: _notificationsOn,
    onChanged: (v) => setState(() => _notificationsOn = v),
  ),
),

                      _SettingTile(
                        icon: const Iconify(Ph.heart_bold),
                        label: 'Liked',
                         labelFontSize: 15, 
                        onTap: () {/* TODO: open Liked */},
                      ),
                      _SettingTile(
                        icon: const Iconify(Ph.lock_bold),
                        label: 'Privacy',
                         labelFontSize: 15, 
                        onTap: () {/* TODO: open Privacy */},
                      ),
                      _SettingTile(
                        icon: const Iconify(Ph.user_circle_bold),
                        label: 'Profile Account',
                         labelFontSize: 15, 
                        onTap: () {/* TODO: open Profile Account */},
                      ),
                      _SettingTile(
                        icon: const Iconify(Ph.chat_circle_text),
                        label: 'Help',
                        labelFontSize: 15, // bigger font
                        onTap: () {/* TODO: open Help */},
                      ),
                      _SettingTile(
                        icon: const Iconify(Uil.users_alt),
                        label: 'Invite Friend',
                        labelFontSize: 15,
                        onTap: () {/* TODO: invite flow */},
                      ),
                      _SettingTile(
                        icon: const Iconify(Ph.link_bold),
                        label: 'Share Profile',
                        labelFontSize: 15,
                        onTap: () {/* TODO: share profile */},
                      ),
                      _SettingTile(
                        icon: const Iconify(Logos.google_icon),
                        label: 'Link to Gmail',
                        labelFontSize: 15,
                        onTap: () {},
                      ),
                      _SettingTile(
                        icon: const Iconify(Uil.shield),
                        label: 'Security & permission',
                        labelFontSize: 15,
                        onTap: () {},
                      ),
                      _SettingTile(
                        icon: const Iconify(Uil.cog),
                        label: 'Manage User',
                        labelFontSize: 15,
                        onTap: () {},
                      ),
                      _SettingTile(
                        icon: const Iconify(Ph.globe_hemisphere_east_bold),
                        label: 'Language',
                        labelFontSize: 15,
                        onTap: () {/* TODO: language picker */},
                      ),
                      _SettingTile(
                        icon: const Iconify(Ph.moon_bold),
                        label: 'Switch Mode',
                        labelFontSize: 15,
                        trailing: CupertinoSwitch(
                          value: _darkMode,
                          onChanged: (v) => setState(() => _darkMode = v),
                        ),
                        onTap: () => setState(() => _darkMode = !_darkMode),
                      ),

                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0xFFF1F1F1)),

                      // Bottom “Switch” row
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFF1F1F1)),
                            bottom: BorderSide(color: Color(0xFFF1F1F1)),
                          ),
                        ),
                        child: _SettingTile(
                          icon: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF3FF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF5B79FF),
                                width: 2,
                              ),
                            ),
                            child: const Iconify(
                              Ph.user_bold,
                              size: 18,
                              color: Color.fromARGB(255, 18, 18, 18),
                            ),
                          ),
                          label: 'Switch',
                          labelFontSize: 15,
                          trailing: CupertinoSwitch(
                            value: _switchBottom,
                            onChanged: (v) =>
                                setState(() => _switchBottom = v),
                          ),
                          onTap: () =>
                              setState(() => _switchBottom = !_switchBottom),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Logout
                      _SettingTile(
                        icon: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 255, 255, 255),
                            borderRadius: BorderRadius.circular(38),
                            border: Border.all(
                              color:  Colors.grey,
                              width: 2,
                            ),
                          ),
                            child: const Iconify(
      MaterialSymbols.logout_rounded,
      size: 18,
      color: Color(0xFFFF4B4B),
    ),
  ),
  label: 'Logout',
  labelStyle: const TextStyle(
    color: Color.fromARGB(255, 0, 0, 0),
    fontWeight: FontWeight.w600,
  ),
  onTap: () {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) =>  LoginScreen()),
    );
  },
),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



/// Single slim row that matches the minimalist style in your mock.
class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.labelStyle,
    this.labelFontSize = 12, // default value
  });

  final Widget icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final TextStyle? labelStyle;
  final double labelFontSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            SizedBox(width: 32, child: Center(child: icon)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: labelStyle ??
                    TextStyle(
                      fontSize: labelFontSize, // use custom size
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            if (trailing != null) trailing!,
            if (trailing == null)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                //child: Iconify(Mdi.chevron_right, size: 18, color: Colors.black38),
              ),
          ],
        ),
      ),
    );
  }
}
