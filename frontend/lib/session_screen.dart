import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'admin_ip.dart';
import 'log_session.dart';
import 'Users/phone_validition_screen.dart';
import 'theme_settings.dart';
import 'Users/signup_screen.dart';
import 'login_screen.dart';
import 'Users/user_dashboard_screen.dart';
import 'Users/user_password_screen.dart';

//This file serves as the entry point for user authentication. It provides 3 options: signing up, logging in, and continuing with Google.

class SessionPage extends StatefulWidget {
  const SessionPage({super.key});

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  // ============ STATE VARIABLES ============
  bool _isGoogleLoading = false;

  // ============ AUTHENTICATION METHODS ============
  /// Handle Google Sign-In flow (Firebase + Backend)
  Future<void> _continueWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final authResult = await _authenticateWithGoogle();
      final firebaseUser = authResult.user;

      if (firebaseUser == null) {
        throw Exception('Google sign-in did not return a valid user.');
      }

      final email = _getValidEmail(firebaseUser);
      final payload = _buildGooglePayload(firebaseUser, email);

      await _sendAuthenticationToBackend(payload);
    } catch (error) {
      _showErrorSnackBar('Google sign-in failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  // ============ FIREBASE AUTHENTICATION ============
  /// Get Firebase UserCredential via platform-specific method
  Future<UserCredential> _authenticateWithGoogle() async {
    if (kIsWeb) {
      return await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    } else {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    }
  }

  // ============ DATA PREPARATION ============
  /// Extract and validate email from Firebase user
  String _getValidEmail(User firebaseUser) {
    final email = (firebaseUser.email ?? '').trim().toLowerCase();
    if (email.isEmpty) {
      throw Exception('Google account has no email.');
    }
    return email;
  }

  /// Build authentication payload for backend
  Map<String, dynamic> _buildGooglePayload(User firebaseUser, String email) {
    final studentId = email.split('@').first;
    return {
      'student_id': studentId,
      'full_name': firebaseUser.displayName ?? 'Google User',
      'email': email,
      'password': firebaseUser.uid,
      'picture': firebaseUser.photoURL ?? '',
    };
  }

  // ============ BACKEND COMMUNICATION ============
  /// Send authentication data to backend and handle response
  Future<void> _sendAuthenticationToBackend(
    Map<String, dynamic> payload,
  ) async {
    final endpoint = Uri.parse('${AdminIp.baseUrl}/api/googleroutes/google');

    final response = await http
        .post(
          endpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    if (!mounted) return;

    final body = _parseResponseBody(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _handleSuccessResponse(payload, body);
    } else {
      _handleErrorResponse(response, body);
    }
  }

  /// Parse HTTP response body to JSON
  Map<String, dynamic> _parseResponseBody(http.Response response) {
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    final isJson = contentType.contains('application/json');

    return (response.body.isNotEmpty && isJson)
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};
  }

  // ============ RESPONSE HANDLING ============
  /// Handle successful backend response
  Future<void> _handleSuccessResponse(
    Map<String, dynamic> payload,
    Map<String, dynamic> body,
  ) async {
    final backendData = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    final sessionData = {
      ...payload,
      ...backendData,
      'full_name': backendData['full_name'] ?? payload['full_name'],
      'picture': backendData['picture'] ?? payload['picture'],
    };

    LogSession.instance.setSessionFromBackend(sessionData);

    await _navigateBasedOnValidation(sessionData);
  }

  /// Handle error response from backend
  void _handleErrorResponse(http.Response response, Map<String, dynamic> body) {
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    final isJson = contentType.contains('application/json');

    final preview = response.body.length > 80
        ? '${response.body.substring(0, 80)}...'
        : response.body;

    final fallbackMessage = !isJson
        ? 'Non-JSON response from backend. URL: ${AdminIp.baseUrl}/api/googleroutes/google | status: ${response.statusCode} | content-type: $contentType | body: $preview'
        : 'Google authentication failed on backend.';

    _showErrorSnackBar((body['message'] as String?) ?? fallbackMessage);
  }

  // ============ NAVIGATION ============
  /// Navigate to appropriate screen based on phone validation requirement
  Future<void> _navigateBasedOnValidation(
    Map<String, dynamic> sessionData,
  ) async {
    final bool requiresPasswordSetup =
        sessionData['requires_password_setup'] == true;
    final bool requiresPhoneValidation =
        sessionData['requires_phone_validation'] == true;

    if (requiresPasswordSetup) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserPasswordScreen(userProfile: sessionData),
        ),
      );
    } else if (requiresPhoneValidation) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PhoneValiditionScreen(userProfile: sessionData),
        ),
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UserDashboardPage()),
        (route) => false,
      );
    }
  }

  /// Navigate to Sign Up screen
  void _navigateToSignUp() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignUpPage()));
  }

  /// Navigate to Login screen
  void _navigateToLogin() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  // ============ UI HELPERS ============
  /// Show error message via SnackBar
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ============ BUILD UI ============
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppBrandColors.blackBackgroundGradient,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    AppBar().preferredSize.height -
                    MediaQuery.of(context).padding.top,
                maxWidth: 500,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ShaderMask(
                        shaderCallback: (bounds) => AppBrandColors
                            .redYellowGradient
                            .createShader(bounds),
                        child: const Icon(
                          Icons.pedal_bike_rounded,
                          size: 120,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Choose Session',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppBrandColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: _navigateToSignUp,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Sign Up as New User'),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _navigateToLogin,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Login'),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _isGoogleLoading ? null : _continueWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppBrandColors.greenMid,
                        foregroundColor: AppBrandColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                      label: Text(
                        _isGoogleLoading
                            ? 'Connecting to Google...'
                            : 'Continue with Google',
                      ),
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
