import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/material_symbols.dart';
import 'package:iconify_flutter/icons/ic.dart';
import 'services/api_client.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Step 1: email entry; Step 2: OTP + new password
  int _step = 1;

  final _emailCtl = TextEditingController();
  final List<TextEditingController> _otpCtls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpNodes = List.generate(6, (_) => FocusNode());
  final _passCtl = TextEditingController();
  final _confirmCtl = TextEditingController();

  bool _loading = false;
  bool _obscurePass = true;
  String? _error;

  @override
  void dispose() {
    _emailCtl.dispose();
    for (final c in _otpCtls) { c.dispose(); }
    for (final n in _otpNodes) { n.dispose(); }
    _passCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  String get _otp => _otpCtls.map((c) => c.text.trim()).join();

  Future<void> _sendOtp() async {
    final email = _emailCtl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final r = await apiPost('/otp/send', {'email': email});
      if (r.statusCode == 200) {
        setState(() { _step = 2; _loading = false; });
      } else {
        final body = expectJson(r);
        setState(() { _error = body['error']?.toString() ?? 'Failed to send code'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _resetPassword() async {
    final code = _otp;
    final pass = _passCtl.text;
    final confirm = _confirmCtl.text;

    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final r = await apiPost('/auth/reset-password', {
        'email': _emailCtl.text.trim(),
        'code': code,
        'newPassword': pass,
      });
      if (r.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset! Please log in.')),
        );
        Navigator.pop(context);
      } else {
        final body = expectJson(r);
        setState(() => _error = body['error']?.toString() ?? 'Reset failed');
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _field(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
      );

  Widget _otpBox(int i) => SizedBox(
        width: 44,
        child: TextField(
          controller: _otpCtls[i],
          focusNode: _otpNodes[i],
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
            if (val.length == 1 && i < 5) _otpNodes[i + 1].requestFocus();
            if (val.isEmpty && i > 0) _otpNodes[i - 1].requestFocus();
            setState(() {});
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 253, 255),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Iconify(MaterialSymbols.arrow_back_ios, size: 24),
          onPressed: () {
            if (_step == 2) {
              setState(() { _step = 1; _error = null; });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 50),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _step == 1 ? _buildStep1() : _buildStep2(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Forgot Password',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 16),
          const Text(
            'Enter your email address and we\'ll send you a verification code.',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 30),
          TextField(
            controller: _emailCtl,
            keyboardType: TextInputType.emailAddress,
            decoration: _field('Email Address').copyWith(
              hintText: 'example@gmail.com',
              prefixIcon: const Padding(
                padding: EdgeInsets.all(12),
                child: Iconify(Ic.baseline_email, size: 24),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14)),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3448F0),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                _loading ? 'Sending…' : 'Send Code',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );

  Widget _buildStep2() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reset Password',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 16),
          Text(
            'Enter the 6-digit code sent to ${_emailCtl.text.trim()} and your new password.',
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, _otpBox),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _passCtl,
            obscureText: _obscurePass,
            decoration: _field('New Password').copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmCtl,
            obscureText: true,
            decoration: _field('Confirm Password'),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14)),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_loading || _otp.length != 6) ? null : _resetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3448F0),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                _loading ? 'Resetting…' : 'Reset Password',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _loading ? null : _sendOtp,
              child: const Text("Didn't get a code? Resend"),
            ),
          ),
        ],
      );
}
