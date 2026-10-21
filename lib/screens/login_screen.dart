
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // Raqeeb color palette
  static const Color militaryGreen = Color(0xFF6F8862);
  

  static const Color lightBackground = Color(0xFFF5F6F1);
  static const Color darkBackground = Color(0xFF111A1D);

  static const Color lightCard = Colors.white;
  static const Color darkCard = Color(0xFF1C2A2D);

  static const Color lightText = Color(0xFF1D3027);
  static const Color darkText = Color(0xFFF1F5ED);

  static const Color lightSecondary = Color(0xFF647568);
  static const Color darkSecondary = Color(0xFFAAB8AA);

  static const Color alertRed = Color(0xFFB83F45);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Firebase Authentication Login
  Future<void> _login() async {
    if (_isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل الدخول بنجاح'),
          backgroundColor: militaryGreen,
        ),
      );

      // Navigation will be handled in main.dart
      // using FirebaseAuth.authStateChanges().

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'البريد الإلكتروني غير صحيح';
          break;

        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          message = 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
          break;

        case 'user-disabled':
          message = 'هذا الحساب موقوف، يرجى التواصل مع المسؤول';
          break;

        case 'too-many-requests':
          message = 'محاولات كثيرة، يرجى المحاولة لاحقًا';
          break;

        case 'network-request-failed':
          message = 'تحققي من الاتصال بالإنترنت';
          break;

        default:
          message = 'تعذر تسجيل الدخول، يرجى المحاولة مرة أخرى';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: alertRed,
        ),
      );

    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى'),
          backgroundColor: alertRed,
        ),
      );

    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Shared input styling
  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
    Widget? suffixIcon,
  }) {
    final secondaryColor = isDark
        ? darkSecondary
        : lightSecondary;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: secondaryColor),
      floatingLabelStyle: const TextStyle(
        color: militaryGreen,
      ),
      prefixIcon: Icon(
        icon,
        color: militaryGreen,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? darkCard : lightCard,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark
              ? const Color(0xFF50645A)
              : const Color(0xFFBBC6B7),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: militaryGreen,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: alertRed,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: alertRed,
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final backgroundColor =
        isDark ? darkBackground : lightBackground;

    final primaryTextColor =
        isDark ? darkText : lightText;

    final secondaryTextColor =
        isDark ? darkSecondary : lightSecondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      // Raqeeb Logo
                      const Icon(
                        Icons.shield_outlined,
                        size: 85,
                        color: militaryGreen,
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'رقيب',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),

                      const SizedBox(height: 4),

                      const Text(
                        'نظام المراقبة الذكي',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: militaryGreen,
                        ),
                      ),

                      const SizedBox(height: 42),

                      // Login heading
                      Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'مرحبًا بعودتك إلى نظام رقيب',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Email field
                      TextFormField(
                        controller: _emailController,
                        keyboardType:
                            TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.email,
                        ],
                        style: TextStyle(
                          color: primaryTextColor,
                        ),
                        decoration: _inputDecoration(
                          label: 'البريد الإلكتروني',
                          icon: Icons.email_outlined,
                          isDark: isDark,
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'يرجى إدخال البريد الإلكتروني';
                          }

                          final emailPattern = RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          );

                          if (!emailPattern.hasMatch(
                            value.trim(),
                          )) {
                            return 'البريد الإلكتروني غير صحيح';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [
                          AutofillHints.password,
                        ],
                        style: TextStyle(
                          color: primaryTextColor,
                        ),
                        decoration: _inputDecoration(
                          label: 'كلمة المرور',
                          icon: Icons.lock_outline,
                          isDark: isDark,
                          suffixIcon: IconButton(
                            tooltip: _showPassword
                                ? 'إخفاء كلمة المرور'
                                : 'إظهار كلمة المرور',
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: secondaryTextColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _showPassword =
                                    !_showPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty) {
                            return 'يرجى إدخال كلمة المرور';
                          }

                          return null;
                        },
                        onFieldSubmitted: (_) {
                          if (!_isLoading) {
                            _login();
                          }
                        },
                      ),

                      const SizedBox(height: 28),

                      // Login button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: militaryGreen,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                militaryGreen.withValues(
                              alpha: 0.6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child:
                                      CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 26),

                      // Accounts are created by Admin
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: secondaryTextColor,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'للحصول على حساب، يرجى التواصل مع المسؤول',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
