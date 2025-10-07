// lib/verify.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/uil.dart';

import 'package:ifeed/profile.dart';

class VerifyScreen extends StatefulWidget {
  final String uid;
  final String email;

  /// Base URL only (no path).
  final String backendUrl;

  const VerifyScreen({
    super.key,
    required this.uid,
    required this.email,
    this.backendUrl = "https://ifeed-backend.onrender.com",
  });

  @override
  VerifyScreenState createState() => VerifyScreenState();
}

class VerifyScreenState extends State<VerifyScreen> {
  final _db = FirebaseFirestore.instance;

  // 6 boxes for 6 digits
  final List<TextEditingController> _ctls = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  bool _isBusy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    for (final c in _ctls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  String get _code => _ctls.map((c) => c.text.trim()).join();

  // ---- VERIFY (use backend) ----------------------------------------------
  Future<void> _verifyCode() async {
    final code = _code;
    if (code.length != 6 || code.contains(RegExp(r'\D'))) {
      setState(() => _error = 'Please enter the 6-digit code.');
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
      _info = null;
    });

    try {
      final uri = Uri.parse('${widget.backendUrl}/verify-otp');
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': widget.email, 'code': code}),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        // Mark verified flag for your app logic (optional but nice to have)
        await _db.collection('users').doc(widget.uid).set({
          'emailOtpVerified': true,
          'emailVerifiedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification successful!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileUserScreen()),
        );
      } else {
        String msg = 'Verification failed.';
        try {
          final j = jsonDecode(resp.body);
          if (j is Map && j['error'] != null) msg = j['error'].toString();
        } catch (_) {}
        setState(() => _error = msg);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ---- RESEND (JSON) -----------------------------------------------------
  Future<void> _resendCode() async {
    setState(() {
      _isBusy = true;
      _error = null;
      _info = null;
    });

    try {
      final uri = Uri.parse('${widget.backendUrl}/send-otp');
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'uid': widget.uid, 'email': widget.email}),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        setState(() => _info = 'A new code was sent to ${widget.email}.');
      } else {
        setState(() => _error = 'Failed to send code. Try again.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // One digit box
  Widget _otpBox(int index) {
    return SizedBox(
      width: 44,
      child: TextField(
        controller: _ctls[index],
        focusNode: _nodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        decoration: const InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.symmetric(vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFCCCEF9), width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF5670FF), width: 2),
          ),
        ),
        onChanged: (val) {
          if (val.length == 1 && index < 5) _nodes[index + 1].requestFocus();
          if (val.isEmpty && index > 0) _nodes[index - 1].requestFocus();
          setState(() {}); // refresh verify button state
        },
        onSubmitted: (_) {
          if (_code.length == 6) _verifyCode();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canVerify = _code.length == 6 && !_isBusy;

    return Scaffold(
      backgroundColor: Colors.pink[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
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
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: <Widget>[
                        const Text(
                          'Verification Code',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "We've sent a 6-digit code to ${widget.email}",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, _otpBox),
                        ),
                        const SizedBox(height: 20),

                        TextButton(
                          onPressed: _isBusy ? null : _resendCode,
                          child: const Text("Didn't get a code? Resend"),
                        ),

                        const SizedBox(height: 8),
                        if (_error != null)
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        if (_info != null)
                          Text(
                            _info!,
                            style: const TextStyle(color: Colors.green),
                          ),

                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: canVerify ? _verifyCode : null,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: _isBusy
                              ? const CircularProgressIndicator()
                              : const Text('Verify'),
                        ),
                      ],
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
}
