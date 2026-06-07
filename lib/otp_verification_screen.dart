import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/material_symbols.dart';
import 'services/api_client.dart';
import 'reset_password_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _otpCtls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpNodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _otpCtls) { c.dispose(); }
    for (final n in _otpNodes) { n.dispose(); }
    super.dispose();
  }

  String get _otp => _otpCtls.map((c) => c.text.trim()).join();

  void _verifyOtp() {
    if (_otp.length != 6) {
      setState(() => _error = 'Enter the complete 6-digit code.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(
          email: widget.email,
          code: _otp,
        ),
      ),
    );
  }

  Future<void> _resendOtp() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await apiPost('/otp/send', {'email': widget.email});
      if (!mounted) return;
      if (r.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new code has been sent.')),
        );
      } else {
        final body = expectJson(r);
        setState(() {
          _error = body['error']?.toString() ?? 'Failed to resend code';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 50),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OTP Verification',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Enter the 6-digit code sent to ${widget.email}.',
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, _otpBox),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _otp.length != 6 ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3448F0),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'Verify Code',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _loading ? null : _resendOtp,
                      child: const Text("Didn't get a code? Resend"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
