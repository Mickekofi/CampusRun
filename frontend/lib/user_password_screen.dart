import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../admin_ip.dart';
import '../log_session.dart';
import 'Users/phone_validition_screen.dart';
import '../theme_settings.dart';
import 'Users/user_dashboard_screen.dart';

class UserPasswordScreen extends StatefulWidget {
  const UserPasswordScreen({super.key, required this.userProfile});

  final Map<String, dynamic> userProfile;

  @override
  State<UserPasswordScreen> createState() => _UserPasswordScreenState();
}

class _UserPasswordScreenState extends State<UserPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final endpoint = Uri.parse(
        '${AdminIp.baseUrl}/api/userpasswordroutes/set-password',
      );

      final response = await http
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'student_id': widget.userProfile['student_id'],
              'email': widget.userProfile['email'],
              'new_password': _passwordController.text,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final contentType = (response.headers['content-type'] ?? '')
          .toLowerCase();
      final isJson = contentType.contains('application/json');
      final body = (response.body.isNotEmpty && isJson)
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final backendData = body['data'] is Map<String, dynamic>
            ? body['data'] as Map<String, dynamic>
            : <String, dynamic>{};

        final mergedData = {
          ...widget.userProfile,
          ...backendData,
          'requires_password_setup': false,
        };

        LogSession.instance.setSessionFromBackend(mergedData);
        LogSession.instance.markPasswordSetupCompleted();

        final requiresPhoneValidation =
            mergedData['requires_phone_validation'] == true;

        if (requiresPhoneValidation) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PhoneValiditionScreen(userProfile: mergedData),
            ),
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const UserDashboardPage()),
            (route) => false,
          );
        }
      } else {
        final message =
            (body['message'] as String?) ?? 'Could not set password.';
        _showSnack(message);
      }
    } catch (_) {
      _showSnack('Unable to set password right now.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Account Password')),
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
                        const Text(
                          'Create your login password',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppBrandColors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This links your Google account to manual Email/Password login.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppBrandColors.whiteMuted),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
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
                            if (value.length < 6) {
                              return 'Use at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_person_outlined),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                );
                              },
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitPassword,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppBrandColors.white,
                                  ),
                                )
                              : const Icon(Icons.verified_user_rounded),
                          label: Text(
                            _isSubmitting ? 'Saving...' : 'Set Password',
                          ),
                        ),
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
}
