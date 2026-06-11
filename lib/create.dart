// lib/create.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final _formKey = GlobalKey<FormState>();

  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _dayController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedMonth;
  String? _selectedYear;
  String _selectedGender = 'Female';
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  final _svc = AuthService();

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static final List<String> _years = List.generate(
    DateTime.now().year - 1919,
    (i) => (DateTime.now().year - i).toString(),
  );

  static const List<String> _genders = ['Female', 'Male', 'Other'];

  static const Color _primaryColor = Color(0xFF4F46E5);
  static const Color _greenColor = Color(0xFF22C55E);

  // ── Auth methods (unchanged) ──────────────────────────────────────────────

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
    if (!_formKey.currentState!.validate()) return;

    final first = _firstController.text.trim();
    final last = _lastController.text.trim();
    final email = _emailController.text.trim();
    final pass = _passwordController.text;

    // Build ISO-8601 date string when all DOB parts are present
    String? dateOfBirth;
    final day = _dayController.text.trim();
    if (day.isNotEmpty && _selectedMonth != null && _selectedYear != null) {
      final monthNum = (_months.indexOf(_selectedMonth!) + 1)
          .toString()
          .padLeft(2, '0');
      dateOfBirth = '${_selectedYear!}-$monthNum-${day.padLeft(2, '0')}';
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
        dateOfBirth: dateOfBirth,
        gender: _selectedGender,
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
    _dayController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLogo(),
                const SizedBox(height: 24),
                _buildGoogleButton(),
                const SizedBox(height: 20),
                _buildDivider(),
                const SizedBox(height: 20),
                _buildSectionLabel('Name'),
                const SizedBox(height: 8),
                _buildNameRow(),
                const SizedBox(height: 16),
                _buildSectionLabel('Date of Birth'),
                const SizedBox(height: 8),
                _buildDobRow(),
                const SizedBox(height: 16),
                _buildSectionLabel('Gender'),
                const SizedBox(height: 8),
                _buildGenderRow(),
                const SizedBox(height: 16),
                _buildEmailField(),
                const SizedBox(height: 10),
                _buildPasswordField(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 3, 240, 3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Iconify(Uil.comment, size: 55, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton(
      onPressed: _loading ? null : _handleGoogle,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        side: const BorderSide(color: Color(0xFFD1D5DB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        foregroundColor: Colors.black87,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Iconify(Logos.google_icon, size: 20),
          const SizedBox(width: 10),
          Text(
            _loading ? 'Signing in…' : 'Continue with Google',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or sign up with email',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.black54,
      ),
    );
  }

  Widget _buildNameRow() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            controller: _firstController,
            hint: 'First name',
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildTextField(
            controller: _lastController,
            hint: 'Last name',
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDobRow() {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: _buildTextField(
            controller: _dayController,
            hint: 'DD',
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            textAlign: TextAlign.center,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Day';
              final d = int.tryParse(v);
              if (d == null || d < 1 || d > 31) return 'Invalid';
              return null;
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildDropdown(
            value: _selectedMonth,
            hint: 'Month',
            items: _months,
            onChanged: (v) => setState(() => _selectedMonth = v),
            validator: (v) => v == null ? 'Required' : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildDropdown(
            value: _selectedYear,
            hint: 'Year',
            items: _years,
            onChanged: (v) => setState(() => _selectedYear = v),
            validator: (v) => v == null ? 'Required' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildGenderRow() {
    return Row(
      children: _genders.map((gender) {
        final isActive = _selectedGender == gender;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedGender = gender),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(right: gender != _genders.last ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFEEF2FF) : Colors.white,
                border: Border.all(
                  color: isActive ? _primaryColor : const Color(0xFFD1D5DB),
                  width: isActive ? 1.5 : 0.5,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                gender,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isActive ? _primaryColor : Colors.black54,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmailField() {
    return _buildTextField(
      controller: _emailController,
      hint: 'Email or phone number',
      keyboardType: TextInputType.emailAddress,
      validator: (v) => (v == null || v.isEmpty) ? 'Email is required' : null,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'New password',
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
            color: Colors.grey,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primaryColor, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 0.8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.2),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Password is required';
        if (v.length < 6) return 'Minimum 6 characters';
        return null;
      },
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _loading ? null : _handleCreateEmail,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primaryColor.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Create your account',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    TextAlign textAlign = TextAlign.start,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textAlign: textAlign,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 0.8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.2),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(
        hint,
        style: const TextStyle(color: Colors.black38, fontSize: 13),
      ),
      isExpanded: true,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 18,
        color: Colors.grey,
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 0.8),
        ),
      ),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e, style: const TextStyle(fontSize: 13)),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
