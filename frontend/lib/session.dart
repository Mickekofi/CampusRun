import 'package:flutter/material.dart';

import 'theme_settings.dart';
import 'signup_screen.dart';
import 'login_screen.dart';

class SessionPage extends StatelessWidget {
  const SessionPage({super.key});

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
              constraints: _buildConstraints(context),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 18),
                    _buildTitle(),
                    const SizedBox(height: 48),
                    _buildSignUpButton(context),
                    const SizedBox(height: 14),
                    _buildLoginButton(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Layout
  BoxConstraints _buildConstraints(BuildContext context) {
    return BoxConstraints(
      minHeight: MediaQuery.of(context).size.height -
          AppBar().preferredSize.height -
          MediaQuery.of(context).padding.top,
      maxWidth: 500,
    );
  }

  // UI Components
  Widget _buildLogo() {
    return Center(
      child: ShaderMask(
        shaderCallback: (bounds) =>
            AppBrandColors.redYellowGradient.createShader(bounds),
        child: const Icon(
          Icons.pedal_bike_rounded,
          size: 120,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'Choose Session',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppBrandColors.white,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // Navigation Buttons
  Widget _buildSignUpButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _navigateToSignUp(context),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: const Text('Sign Up as New User'),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _navigateToLogin(context),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      icon: const Icon(Icons.login_rounded),
      label: const Text('Login'),
    );
  }

  // Navigation
  void _navigateToSignUp(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SignUpPage()),
    );
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }
}
