import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../raqeeb_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(), password: _passwordController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(context, 'تم تسجيل الدخول بنجاح', 'Signed in successfully')),
        backgroundColor: RaqeebColors.lightAccent,
      ));
      // Navigation is still managed by FirebaseAuth.authStateChanges in main.dart.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'invalid-email':
          message = tr(context, 'البريد الإلكتروني غير صحيح', 'Invalid email address');
          break;
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          message = tr(context, 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
              'Incorrect email or password');
          break;
        case 'user-disabled':
          message = tr(context, 'هذا الحساب موقوف، يرجى التواصل مع المسؤول',
              'This account is disabled. Contact your administrator');
          break;
        case 'too-many-requests':
          message = tr(context, 'محاولات كثيرة، يرجى المحاولة لاحقًا',
              'Too many attempts. Please try again later');
          break;
        case 'network-request-failed':
          message = tr(context, 'تحقق من الاتصال بالإنترنت', 'Check your internet connection');
          break;
        default:
          message = tr(context, 'تعذر تسجيل الدخول، يرجى المحاولة مرة أخرى',
              'Could not sign in. Please try again');
      }
      _showError(message);
    } catch (_) {
      if (mounted) _showError(tr(context, 'حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى',
          'Unexpected error. Please try again'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message), backgroundColor: dark ? const Color(0xFF862B2B) : RaqeebColors.lightDanger));
  }

  InputDecoration _decoration({required String label,
      required IconData icon, required bool dark, Widget? suffix}) {
    final accent = RaqeebColors.accent(dark);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: RaqeebColors.secondary(dark)),
      floatingLabelStyle: TextStyle(color: accent),
      prefixIcon: Icon(icon, color: accent), suffixIcon: suffix,
      filled: true, fillColor: RaqeebColors.card(dark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: RaqeebColors.border(dark))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: RaqeebColors.danger(dark))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: RaqeebColors.danger(dark), width: 2)),
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
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
          child: Form(key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Icon(Icons.shield_outlined, size: 85, color: accent),
              const SizedBox(height: 12),
              Text(tr(context, 'رقيب', 'Raqeeb'), textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: primary)),
              const SizedBox(height: 4),
              Text(tr(context, 'نظام المراقبة الذكي', 'Intelligent Monitoring System'),
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: accent)),
              const SizedBox(height: 42),
              Text(tr(context, 'تسجيل الدخول', 'Sign In'),
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: primary)),
              const SizedBox(height: 8),
              Text(tr(context, 'مرحبًا بعودتك إلى نظام رقيب', 'Welcome back to Raqeeb'),
                  style: TextStyle(color: secondary, fontSize: 14)),
              const SizedBox(height: 28),
              TextFormField(
                controller: _emailController, keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr, textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                style: TextStyle(color: primary),
                decoration: _decoration(label: tr(context, 'البريد الإلكتروني', 'Email Address'),
                    icon: Icons.email_outlined, dark: dark),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return tr(context, 'يرجى إدخال البريد الإلكتروني', 'Please enter your email');
                  }
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
                    return tr(context, 'البريد الإلكتروني غير صحيح', 'Invalid email address');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _passwordController,
                obscureText: !_showPassword, textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                style: TextStyle(color: primary),
                decoration: _decoration(
                  label: tr(context, 'كلمة المرور', 'Password'),
                  icon: Icons.lock_outline, dark: dark,
                  suffix: IconButton(
                    tooltip: _showPassword
                        ? tr(context, 'إخفاء كلمة المرور', 'Hide password')
                        : tr(context, 'إظهار كلمة المرور', 'Show password'),
                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility,
                        color: secondary),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? tr(context, 'يرجى إدخال كلمة المرور', 'Please enter your password')
                    : null,
                onFieldSubmitted: (_) { if (!_isLoading) _login(); },
              ),
              const SizedBox(height: 28),
              SizedBox(height: 52, child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: dark ? const Color(0xFF112018) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(tr(context, 'تسجيل الدخول', 'Sign In'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              )),
              const SizedBox(height: 26),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.info_outline, size: 18, color: secondary),
                const SizedBox(width: 8),
                Flexible(child: Text(tr(context,
                    'للحصول على حساب، يرجى التواصل مع المسؤول',
                    'To request an account, please contact your administrator'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: secondary))),
              ]),
            ]),
          ),
        ),
      ))),
    );
  }
}
