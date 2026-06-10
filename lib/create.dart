// lib/create.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:colorful_iconify_flutter/icons/logos.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/uil.dart';

import 'package:http/http.dart' as http;
import 'services/auth_service.dart';
import 'services/api_client.dart';

import 'package:ifeed/profile.dart';
import 'verify.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});
  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  static final String _backendUrl = kBaseUrl;

  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late String _day;
  late String _month;
  late String _year;
  String _gender = 'Female';
  bool _loading = false;
  String? _error;

  final _svc = AuthService();

  List<String> get _days =>
      List.generate(31, (i) => (i + 1).toString().padLeft(2, '0'));
  List<String> get _months =>
      List.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));
  List<String> get _years {
    final y = DateTime.now().year;
    return List.generate(100, (i) => (y - i).toString());
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = now.day.toString().padLeft(2, '0');
    _month = now.month.toString().padLeft(2, '0');
    _year = now.year.toString();
  }

  InputDecoration _boxDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Color(0xFFCCCEF9), width: 2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Color(0xFF5670FF), width: 2),
    ),
  );

  Widget _dobBox({required Widget child, double width = 112}) =>
      SizedBox(width: width, height: 40, child: child);

  Future<bool> _sendOtpToEmail({required String email}) async {
    try {
      final uri = Uri.parse('$_backendUrl/otp/send');
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) return true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send code: ${resp.statusCode}')),
        );
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send code: $e')));
      }
      return false;
    }
  }

  Future<void> _goToVerify({required String uid, required String email}) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VerifyScreen(uid: uid, email: email, backendUrl: _backendUrl),
      ),
    );
  }

  Future<void> _handleGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _svc.loginWithGoogle();
      final userId = await getCurrentUserId();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ProfileUserScreen(userId: userId ?? user['id'].toString()),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleCreateEmail() async {
    final first = _firstController.text.trim();
    final last = _lastController.text.trim();
    final email = _emailController.text.trim();
    final pass = _passwordController.text;

    if (email.isEmpty || pass.length < 6) {
      setState(
        () => _error = 'Please enter a valid email and password (6+ chars).',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final displayName = [
        first,
        last,
      ].where((s) => s.isNotEmpty).join(' ').trim();
      final user = await _svc.register(
        email: email,
        password: pass,
        displayName: displayName.isNotEmpty ? displayName : null,
      );
      final userId = await getCurrentUserId();

      await _sendOtpToEmail(email: email);
      if (!mounted) return;

      await _goToVerify(uid: user['id'].toString(), email: email);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ProfileUserScreen(userId: userId ?? user['id'].toString()),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _firstController.dispose();
    _lastController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: const BoxDecoration(color: Colors.white),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color.fromARGB(255, 36, 231, 19),
                    border: Border.all(
                      color: const Color.fromARGB(255, 36, 231, 19),
                      width: 2,
                    ),
                  ),
                  child: const Iconify(
                    Uil.comment,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),

                // Google button
                OutlinedButton.icon(
                  onPressed: _loading ? null : _handleGoogle,
                  icon: const Iconify(Logos.google_icon, size: 20),
                  label: Text(
                    _loading ? 'Signing in…' : 'Continue With Google',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2C2C2C),
                    side: const BorderSide(color: Color(0xFFCCD3FF)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    backgroundColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 48),

                // Inner form card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCDCDCD)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      const Text(
                        'Name',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _firstController,
                              decoration: _boxDecoration('First name'),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: TextField(
                              controller: _lastController,
                              decoration: _boxDecoration('Last name'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // DOB
                      const Text(
                        'Date of Birth',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _dobBox(
                            child: DropdownButtonFormField<String>(
                              value: _days.contains(_day) ? _day : null,
                              items: _days
                                  .map(
                                    (d) => DropdownMenuItem(
                                      value: d,
                                      child: Text(d),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _day = v ?? _day),
                              decoration: _boxDecoration('DD'),
                            ),
                          ),
                          const SizedBox(width: 20),
                          _dobBox(
                            child: DropdownButtonFormField<String>(
                              value: _months.contains(_month) ? _month : null,
                              items: _months
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _month = v ?? _month),
                              decoration: _boxDecoration('MM'),
                            ),
                          ),
                          const SizedBox(width: 20),
                          _dobBox(
                            child: DropdownButtonFormField<String>(
                              value: _years.contains(_year) ? _year : null,
                              items: _years
                                  .map(
                                    (y) => DropdownMenuItem(
                                      value: y,
                                      child: Text(y),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _year = v ?? _year),
                              decoration: _boxDecoration('YYYY'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Gender
                      const Text(
                        'Gender',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Wrap(
                        spacing: 28,
                        children: [
                          ChoiceChip(
                            label: const Text('Female'),
                            selected: _gender == 'Female',
                            onSelected: (_) =>
                                setState(() => _gender = 'Female'),
                          ),
                          ChoiceChip(
                            label: const Text('Male'),
                            selected: _gender == 'Male',
                            onSelected: (_) => setState(() => _gender = 'Male'),
                          ),
                          ChoiceChip(
                            label: const Text('Other'),
                            selected: _gender == 'Other',
                            onSelected: (_) =>
                                setState(() => _gender = 'Other'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Email
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _boxDecoration('Email'),
                      ),
                      const SizedBox(height: 12),

                      // Password
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: _boxDecoration('New password'),
                      ),
                      const SizedBox(height: 16),

                      // Create button
                      Center(
                        child: OutlinedButton(
                          onPressed: _loading ? null : _handleCreateEmail,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2E49FF)),
                          ),
                          child: Text(
                            _loading ? 'Creating…' : 'Create Your Account',
                          ),
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
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
