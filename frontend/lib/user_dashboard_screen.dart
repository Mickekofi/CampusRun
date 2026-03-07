import 'package:flutter/material.dart';

import 'theme_settings.dart';

class UserDashboardPage extends StatelessWidget {
  const UserDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Dashboard')),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppBrandColors.blackBackgroundGradient,
        ),
        child: const Center(
          child: Text(
            'User dashboard coming next.',
            style: TextStyle(color: AppBrandColors.white, fontSize: 22),
          ),
        ),
      ),
    );
  }
}
