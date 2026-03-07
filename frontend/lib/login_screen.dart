import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'admin_dashboard.dart';
import 'admin_ip.dart';
import 'log_session.dart';
import 'session_screen.dart';
import 'theme_settings.dart';
import 'user_dashboard.dart';
// import 'user_password_screen.dart';
import 'phone_validition_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AnimationController _motionController;
  late final Animation<double> _rotateAnimation;

  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _motionController.dispose();
    super.dispose();
  }

  // ==================== ANIMATION SETUP ====================
  void _setupAnimations() {
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _rotateAnimation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(parent: _motionController, curve: Curves.easeInOut),
    );
  }

  // ==================== LOGIN LOGIC ====================
  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await _performLoginRequest();

      if (!mounted) return;

      final body = _parseResponse(response);
      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

      final nextStep = body['next_step']?.toString();

      if (!isSuccess && nextStep == 'set_password') {
        //comented out the following lines because we are no longer proceeding to the password setup screen immediately after login. Instead, we are allowing the user to log in with Google and then prompting them to set up their password if needed. This is because the user might not have set up their password yet, but they can still log in with Google and then be prompted to set up their password if needed.

        // final backendData = body['data'] is Map<String, dynamic>
        //     ? body['data'] as Map<String, dynamic>
        //     : <String, dynamic>{};

        // final mergedData = {
        //   ...backendData,
        //   'email': _identifierController.text.trim(),
        // };
        // final data = body['data'] is Map<String, dynamic>
        //   ? body['data'] as Map<String, dynamic>
        // : <String, dynamic>{};

        _showToast(
          body['message'] ??
              'Please Use the `Continue with Google` option to log in and set up your password if needed.',
          success: false,
        );

        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            //I am changing from rather proceeding to the phone_validation_screen to rather the session_screen where user is preferred to use "continue with Google" and then proceed to the phone validation if required. This is because the user might not have set up their password yet, but they can still log in with Google and then be prompted to set up their password if needed.

            // builder: (_) => UserPasswordScreen(userProfile: data),
            builder: (_) => SessionPage(),
          ),
        );
        return;
      }

      _showToast(
        body['message'] ?? (isSuccess ? 'Login successful.' : 'Login failed.'),
        success: isSuccess,
      );

      if (!mounted || !isSuccess) return;

      await _handleLoginSuccess(body, nextStep);
    } catch (error) {
      if (!mounted) return;

      _showToast('Unable to login right now: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<http.Response> _performLoginRequest() async {
    final endpoint = Uri.parse('${AdminIp.baseUrl}/api/loginroutes/login');
    return http
        .post(
          endpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'identifier': _identifierController.text.trim(),
            'password': _passwordController.text,
          }),
        )
        .timeout(const Duration(seconds: 15));
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    final isJson = contentType.contains('application/json');

    return (response.body.isNotEmpty && isJson)
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};
  }

  Future<void> _handleLoginSuccess(
    Map<String, dynamic> body,
    String? nextStep,
  ) async {
    final role = body['role']?.toString();

    if (role != 'admin' && role != 'user') {
      await _showResultPopup(
        title: 'Login Failed',
        message: 'Unknown role returned from server.',
        success: false,
      );
      return;
    }

    final roleValue = role as String;

    final data = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    LogSession.instance.setLoginSession(role: roleValue, data: data);
    _navigateAfterLogin(roleValue, nextStep);
  }

  void _navigateAfterLogin(String role, String? nextStep) {
    final Widget destination;

    if (role == 'admin') {
      destination = const AdminDashboardPage();
    } else if (nextStep == 'validate_phone') {
      destination = PhoneValiditionScreen(
        userProfile: LogSession.instance.toMap(),
      );
    } else {
      destination = const UserDashboardPage();
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  // ==================== UI DIALOGS ====================

  void _showToast(String message, {bool success = false}) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(success ? Icons.check_circle : Icons.error, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: success ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _showResultPopup({
    required String title,
    required String message,
    required bool success,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _buildResultDialog(title, message, success),
    );
  }

  AlertDialog _buildResultDialog(String title, String message, bool success) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1C1C1C),
      title: Row(
        children: [
          Icon(
            success ? Icons.check_circle_rounded : Icons.error_rounded,
            color: success
                ? AppBrandColors.greenMid
                : AppBrandColors.redYellowStart,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: AppBrandColors.white),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(color: AppBrandColors.whiteMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }

  // ==================== NAVIGATION ====================
  void _goBackToSession() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const SessionPage()));
  }

  // ==================== UI BUILDERS ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _goBackToSession,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('Login'),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppBrandColors.blackBackgroundGradient,
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                color: const Color(0xFF121212),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAnimatedLogo(),
                        const SizedBox(height: 14),
                        _buildWelcomeText(),
                        const SizedBox(height: 20),
                        _buildIdentifierField(),
                        const SizedBox(height: 14),
                        _buildPasswordField(),
                        const SizedBox(height: 20),
                        _buildLoginButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return RotationTransition(
      turns: _rotateAnimation,
      child: const Icon(
        Icons.pedal_bike_rounded,
        size: 78,
        color: AppBrandColors.redYellowMid,
      ),
    );
  }

  Widget _buildWelcomeText() {
    return const Text(
      'Welcome Back',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppBrandColors.white,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildIdentifierField() {
    return TextFormField(
      controller: _identifierController,
      decoration: const InputDecoration(
        labelText: 'Email, Student ID or Phone',
        prefixIcon: Icon(Icons.person_outline_rounded),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Credential is required';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Password is required';
        }
        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton.icon(
      onPressed: _isSubmitting ? null : _submitLogin,
      icon: _isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppBrandColors.white,
              ),
            )
          : const Icon(Icons.login_rounded),
      label: Text(_isSubmitting ? 'Signing in...' : 'Login with Role Access'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );
  }
}
