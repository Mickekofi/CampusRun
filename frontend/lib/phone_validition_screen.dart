import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'admin_ip.dart';
import 'log_session.dart';
import 'theme_settings.dart';
import 'user_dashboard_screen.dart';

class PhoneValiditionScreen extends StatefulWidget {
  const PhoneValiditionScreen({super.key, required this.userProfile});

  final Map<String, dynamic> userProfile;

  @override
  State<PhoneValiditionScreen> createState() => _PhoneValiditionScreenState();
}

class _PhoneValiditionScreenState extends State<PhoneValiditionScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isSendingCode = false;
  bool _isVerifyingOtp = false;
  String? _verificationId;
  int? _resendToken;

  // ============================================================================
  // LIFECYCLE & CLEANUP
  // ============================================================================

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ============================================================================
  // PHONE NUMBER UTILITIES
  // ============================================================================

  String _normalizePhone(String phoneInput) {
    final cleaned = phoneInput.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.startsWith('0')) {
      return '+233${cleaned.substring(1)}';
    }
    if (cleaned.startsWith('233')) {
      return '+$cleaned';
    }
    return cleaned;
  }

  // ============================================================================
  // OTP OPERATIONS
  // ============================================================================

  Future<void> _sendOtp() async {
    final normalizedPhone = _normalizePhone(_phoneController.text.trim());
    if (normalizedPhone.isEmpty) {
      _showSnack('Enter a phone number linked to MoMo.');
      return;
    }

    setState(() => _isSendingCode = true);

    await FirebaseAuth.instance
        .verifyPhoneNumber(
          phoneNumber: normalizedPhone,
          forceResendingToken: _resendToken,
          verificationCompleted: (PhoneAuthCredential credential) async {
            await FirebaseAuth.instance.signInWithCredential(credential);
          },
          verificationFailed: (FirebaseAuthException e) {
            _showSnack(e.message ?? 'Phone verification failed.');
          },
          codeSent: (String verificationId, int? resendToken) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
            });
            _showSnack('OTP sent successfully.');
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
        )
        .whenComplete(() {
          if (mounted) {
            setState(() => _isSendingCode = false);
          }
        });
  }

  Future<void> _verifyOtpAndContinue() async {
    if (_verificationId == null) {
      _showSnack('Send OTP first.');
      return;
    }

    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      _showSnack('Enter a valid 6-digit OTP.');
      return;
    }

    setState(() => _isVerifyingOtp = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final normalizedPhone = _normalizePhone(_phoneController.text.trim());
      await _submitPhoneToBackend(userCredential, normalizedPhone);
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'OTP verification failed.');
    } catch (_) {
      _showSnack('Could not validate phone right now.');
    } finally {
      if (mounted) {
        setState(() => _isVerifyingOtp = false);
      }
    }
  }

  // ============================================================================
  // BACKEND OPERATIONS
  // ============================================================================

  Future<void> _submitPhoneToBackend(
    UserCredential userCredential,
    String normalizedPhone,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AdminIp.baseUrl}/api/phoneroutes/phone'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'student_id': widget.userProfile['student_id'],
              'email': widget.userProfile['email'],
              'phone': normalizedPhone,
              'firebase_uid': userCredential.user?.uid,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        LogSession.instance.updatePhone(normalizedPhone);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const UserDashboardPage()),
          (route) => false,
        );
      } else {
        _showSnack((body['message'] as String?) ?? 'Phone validation failed.');
      }
    } catch (_) {
      _showSnack('Could not validate phone right now.');
    }
  }

  // ============================================================================
  // UI HELPERS
  // ============================================================================

  // Displays a dialog with the given message. If the message contains keywords like "success", "sent", or "validated", it shows a success icon; otherwise, it shows an error icon.
  void _showSnack(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isSuccess =
            message.toLowerCase().contains('success') ||
            message.toLowerCase().contains('sent') ||
            message.toLowerCase().contains('validated');

        return AlertDialog(
          backgroundColor: const Color(0xFF121212),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          icon: Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
            color: isSuccess ? Colors.green : Colors.red,
            size: 48,
          ),
          title: Text(
            isSuccess ? 'Success' : 'Error',
            style: const TextStyle(color: AppBrandColors.white),
          ),
          content: Text(
            message,
            style: const TextStyle(color: AppBrandColors.white),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Validation')),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: AppBrandColors.blackBackgroundGradient,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              color: const Color(0xFF121212),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter a phone number linked to your MoMo account.',
                      style: TextStyle(
                        color: AppBrandColors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'MoMo Phone Number',
                        hintText: '+233XXXXXXXXX',
                        prefixIcon: Icon(Icons.phone_android_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _isSendingCode ? null : _sendOtp,
                      icon: const Icon(Icons.sms_rounded),
                      label: Text(
                        _isSendingCode ? 'Sending OTP...' : 'Send OTP',
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'OTP Code',
                        hintText: 'Enter 6-digit code',
                        prefixIcon: Icon(Icons.password_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _isVerifyingOtp ? null : _verifyOtpAndContinue,
                      icon: const Icon(Icons.verified_user_rounded),
                      label: Text(
                        _isVerifyingOtp
                            ? 'Validating...'
                            : 'Validate & Continue',
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
