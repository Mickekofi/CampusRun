import 'package:flutter/material.dart';

import 'theme_settings.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppBrandColors.blackBackgroundGradient,
        ),
        child: const Center(
          child: Text(
            'Admin dashboard coming next.',
            style: TextStyle(color: AppBrandColors.white, fontSize: 22),
          ),
        ),
      ),
    );
  }
}
