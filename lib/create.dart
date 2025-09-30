// lib/create.dart
import 'package:flutter/material.dart';
import 'package:colorful_iconify_flutter/icons/logos.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/uil.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:ifeed/profile.dart';
import 'verify.dart'; // keep if you still use it elsewhere

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});
  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  // Name
  final _firstController = TextEditingController();
  final _lastController = TextEditingController();

  // DOB — use valid defaults
  late String _day;
  late String _month;
  late String _year;

  // Gender
  String _gender = 'Female';

  // Contact + password
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // UI state
  bool _loading = false;
  String? _error;

  // Firebase
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // Dropdown helpers
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

  /// Ensure the Firebase user has a displayName (uses entered first/last if missing)
  Future<void> _ensureDisplayName(User user) async {
    final entered = [
      _firstController.text.trim(),
      _lastController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ').trim();

    if ((user.displayName == null || user.displayName!.trim().isEmpty) &&
        entered.isNotEmpty) {
      await user.updateDisplayName(entered);
      await user.reload();
    }
  }

  /// Upsert user profile into Firestore (accepts optional override for displayName)
  Future<void> _upsertUserDoc(User user, {String? displayName}) async {
    final fallbackEnteredName = [
      _firstController.text.trim(),
      _lastController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ').trim();

    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'displayName': (displayName != null && displayName.isNotEmpty)
          ? displayName
          : (user.displayName?.trim().isNotEmpty == true
                ? user.displayName
                : fallbackEnteredName),
      'photoURL': user.photoURL,
      'dob': {'day': _day, 'month': _month, 'year': _year},
      'gender': _gender,
      'providerIds': user.providerData.map((p) => p.providerId).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------- Google Sign-In ----------------
  Future<void> _handleGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }
      final auth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      final user = cred.user;

      if (user != null) {
        await _ensureDisplayName(user);
        await user.reload();
        final refreshed = _auth.currentUser!;
        await _upsertUserDoc(refreshed);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileUserScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ------------- Email + Password Sign Up -------------
  Future<void> _handleCreateEmail() async {
    final first = _firstController.text.trim();
    final last = _lastController.text.trim();
    final email = _emailController.text.trim();
    final pass = _passwordController.text;

    if (email.isEmpty || pass.length < 6) {
      setState(
        () => _error =
            'Please enter a valid email and a password with 6+ characters.',
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

      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );
      final user = cred.user;

      if (user != null) {
        if (displayName.isNotEmpty) {
          await user.updateDisplayName(displayName);
        }
        await user.reload();
        final refreshed = _auth.currentUser!;
        await _upsertUserDoc(refreshed, displayName: displayName);

        try {
          await refreshed.sendEmailVerification();
        } catch (_) {}

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileUserScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'This email is already in use.';
          break;
        case 'invalid-email':
          msg = 'Email address looks invalid.';
          break;
        case 'weak-password':
          msg = 'Password is too weak.';
          break;
        default:
          msg = e.message ?? e.code;
      }
      setState(() => _error = msg);
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
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: const BoxDecoration(color: Colors.white),
            child: Column(
              mainAxisSize: MainAxisSize.min,

              //Logo App
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
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
                        decoration: _boxDecoration('Email/Phone'),
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
