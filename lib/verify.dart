// lib/verify.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'package:ifeed/profile.dart';

class VerifyScreen extends StatefulWidget {
  final String uid;
  final String email;
  final String backendUrl; // e.g. https://ifeed-backend.onrender.com

  const VerifyScreen({
    super.key,
    required this.uid,
    required this.email,
    this.backendUrl = "https://YOUR_BACKEND_DOMAIN", // CHANGE THIS
  });

  @override
  VerifyScreenState createState() => VerifyScreenState();
}

class VerifyScreenState extends State<VerifyScreen> {
  final _db = FirebaseFirestore.instance;

  // 6-digit OTP
  final List<TextEditingController> _ctls = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    for (final c in _ctls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  String get _code => _ctls.map((c) => c.text.trim()).join();

  Future<void> _verifyCode() async {
    final code = _code;
    if (code.length != 6 || code.contains(RegExp(r'\D'))) {
      setState(() => _error = 'Please enter the 6-digit code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
      _info = null;
    });

    try {
      final snap = await _db.collection('email_otps').doc(widget.uid).get();
      if (!snap.exists) {
        setState(() => _error = 'Code not found. Tap Resend.');
        return;
      }

      final data = snap.data()!;
      final serverCode = data['code'] as String; // hash in production
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();

      if (DateTime.now().isAfter(expiresAt)) {
        setState(() => _error = 'Code expired. Tap Resend.');
        return;
      }
      if (code != serverCode) {
        setState(() => _error = 'Incorrect code. Try again.');
        return;
      }

      // Mark verified for app logic
      await _db.collection('users').doc(widget.uid).set({
        'emailOtpVerified': true,
        'emailVerifiedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Verification Successful!')));

      // Go to profile
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileUserScreen()),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isVerifying = true;
      _error = null;
      _info = null;
    });

    try {
      final uri = Uri.parse('${widget.backendUrl}/send-otp');
      final resp = await http.post(
        uri,
        body: {'uid': widget.uid, 'email': widget.email},
      );
      if (resp.statusCode == 200) {
        setState(() => _info = 'A new code was sent to ${widget.email}.');
      } else {
        setState(() => _error = 'Failed to send code. Try again.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // UI helper: one box
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
          // allow quick typing forward & backspace to previous
          if (val.length == 1 && index < 5) {
            _nodes[index + 1].requestFocus();
          }
          if (val.isEmpty && index > 0) {
            _nodes[index - 1].requestFocus();
          }
          setState(() {}); // enable/disable Verify button
        },
        onSubmitted: (_) {
          if (_code.length == 6) _verifyCode();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canVerify = _code.length == 6;

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
                Text(
                  'iFeed',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                const SizedBox(height: 40),
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
                          children: List.generate(6, (i) => _otpBox(i)),
                        ),
                        const SizedBox(height: 20),

                        // Resend
                        TextButton(
                          onPressed: _isVerifying ? null : _resendCode,
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
                        // Verify
                        ElevatedButton(
                          onPressed: (!_isVerifying && canVerify)
                              ? _verifyCode
                              : null,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: _isVerifying
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
