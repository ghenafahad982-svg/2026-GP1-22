import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../raqeeb_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _loginUrl =
      'https://raqeebserver.onrender.com/auth/employee-login';

  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _employeeIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      // The backend must verify the employee ID and password against the
      // assigned Firebase user, then mint a short-lived Firebase custom token.
      // Never fetch or expose the user's email from a public ID-lookup endpoint.
      final response = await http.post(
        Uri.parse(_loginUrl),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'employeeId': _employeeIdController.text.trim(),
          'password': _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 404 || response.statusCode == 405) {
        throw const _LoginServerNotReady();
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const _InvalidCredentials();
      }
      if (response.statusCode == 429) {
        throw const _TooManyAttempts();
      }
      if (response.statusCode != 200) {
        throw const _LoginServerUnavailable();
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['success'] != true ||
          decoded['customToken'] is! String ||
          (decoded['customToken'] as String).isEmpty) {
        throw const _LoginServerUnavailable();
      }

      await FirebaseAuth.instance.signInWithCustomToken(
        decoded['customToken'] as String,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(context, 'تم تسجيل الدخول بنجاح', 'Signed in successfully')),
        backgroundColor: RaqeebColors.lightAccent,
      ));
      // Navigation is managed by FirebaseAuth.authStateChanges in main.dart.
    } on _LoginServerNotReady {
      _showError(tr(context,
          'تسجيل الدخول بالرقم الوظيفي لم يُفعّل على السيرفر بعد',
          'Employee ID sign-in is not enabled on the server yet'));
    } on _InvalidCredentials {
      _showError(tr(context,
          'الرقم الوظيفي أو كلمة المرور غير صحيحة',
          'Incorrect employee ID or password'));
    } on _TooManyAttempts {
      _showError(tr(context,
          'محاولات كثيرة، يرجى المحاولة لاحقًا',
          'Too many attempts. Please try again later'));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-disabled') {
        _showError(tr(context,
            'هذا الحساب موقوف، يرجى التواصل مع المسؤول',
            'This account is disabled. Contact your administrator'));
      } else {
        _showError(tr(context,
            'تعذر تسجيل الدخول، يرجى المحاولة مرة أخرى',
            'Could not sign in. Please try again'));
      }
    } catch (_) {
      _showError(tr(context,
          'تعذر الاتصال بخدمة تسجيل الدخول، يرجى المحاولة لاحقًا',
          'Could not connect to the sign-in service. Try again later'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    final dark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor:
          dark ? const Color(0xFF862B2B) : RaqeebColors.lightDanger,
    ));
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    required bool dark,
    Widget? suffix,
  }) {
    final accent = RaqeebColors.accent(dark);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: RaqeebColors.secondary(dark)),
      floatingLabelStyle: TextStyle(color: accent),
      prefixIcon: Icon(icon, color: accent),
      suffixIcon: suffix,
      filled: true,
      fillColor: RaqeebColors.card(dark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: RaqeebColors.border(dark)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: RaqeebColors.danger(dark)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: RaqeebColors.danger(dark), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = RaqeebColors.text(dark);
    final secondary = RaqeebColors.secondary(dark);
    final accent = RaqeebColors.accent(dark);

    return Scaffold(
      backgroundColor: RaqeebColors.background(dark),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/raqeeb_logo.png',
                        width: 96,
                        height: 96,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr(context, 'رقيب', 'Raqeeb'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(context, 'نظام المراقبة الذكي',
                          'Intelligent Monitoring System'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: accent),
                    ),
                    const SizedBox(height: 42),
                    Text(
                      tr(context, 'تسجيل الدخول', 'Sign In'),
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(context, 'مرحبًا بعودتك إلى نظام رقيب',
                          'Welcome back to Raqeeb'),
                      style: TextStyle(color: secondary, fontSize: 14),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _employeeIdController,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      style: TextStyle(color: primary),
                      decoration: _decoration(
                        label: tr(context, 'الرقم الوظيفي', 'Employee ID'),
                        icon: Icons.badge_outlined,
                        dark: dark,
                      ),
                      validator: (value) {
                        final id = value?.trim() ?? '';
                        if (id.isEmpty) {
                          return tr(context, 'يرجى إدخال الرقم الوظيفي',
                              'Please enter your employee ID');
                        }
                        if (!RegExp(r'^\d{1,20}$').hasMatch(id)) {
                          return tr(context, 'الرقم الوظيفي يجب أن يحتوي على أرقام فقط',
                              'Employee ID must contain digits only');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      style: TextStyle(color: primary),
                      decoration: _decoration(
                        label: tr(context, 'كلمة المرور', 'Password'),
                        icon: Icons.lock_outline,
                        dark: dark,
                        suffix: IconButton(
                          tooltip: _showPassword
                              ? tr(context, 'إخفاء كلمة المرور', 'Hide password')
                              : tr(context, 'إظهار كلمة المرور', 'Show password'),
                          icon: Icon(
                            _showPassword ? Icons.visibility_off : Icons.visibility,
                            color: secondary,
                          ),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? tr(context, 'يرجى إدخال كلمة المرور',
                              'Please enter your password')
                          : null,
                      onFieldSubmitted: (_) {
                        if (!_isLoading) _login();
                      },
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor:
                              dark ? const Color(0xFF112018) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                tr(context, 'تسجيل الدخول', 'Sign In'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: secondary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            tr(context,
                                'للحصول على حساب، يرجى التواصل مع المسؤول',
                                'To request an account, please contact your administrator'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: secondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginServerNotReady implements Exception {
  const _LoginServerNotReady();
}

class _InvalidCredentials implements Exception {
  const _InvalidCredentials();
}

class _TooManyAttempts implements Exception {
  const _TooManyAttempts();
}

class _LoginServerUnavailable implements Exception {
  const _LoginServerUnavailable();
}
