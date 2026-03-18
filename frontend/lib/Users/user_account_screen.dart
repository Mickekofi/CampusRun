import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/session_screen.dart';
import 'package:http/http.dart' as http;

import '../admin_ip.dart';
import '../log_session.dart';
import '../theme_settings.dart';
import '../widgets/app_status_chip.dart';

class UserAccountScreen extends StatefulWidget {
  const UserAccountScreen({super.key});

  @override
  State<UserAccountScreen> createState() => _UserAccountScreenState();
}

class _UserAccountScreenState extends State<UserAccountScreen> {
  bool _isLoading = true;
  String _errorMessage = '';

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _rating;

  @override
  void initState() {
    super.initState();
    _fetchAccountData();
  }

  Future<void> _fetchAccountData() async {
    final userId = LogSession.instance.userId;
    if (userId == null) return;

    try {
      final res = await http.get(
        Uri.parse('${AdminIp.baseUrl}/api/account/profile?user_id=$userId'),
      );

      if (!mounted) return;
      final body = jsonDecode(res.body);

      if (res.statusCode == 200) {
        setState(() {
          _profile = body['data']['profile'];
          _stats = body['data']['stats'];
          _rating = body['data']['rating'];
          _isLoading = false;
          _errorMessage = '';
        });
      } else {
        setState(() {
          _errorMessage = body['message'] ?? 'Failed to load profile.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network connection failed.';
        _isLoading = false;
      });
    }
  }

  void _handleLogout() {
    // 1. Destroy the session in memory
    LogSession.instance.clear();

    // 2. Show the success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppBrandColors.greenMid,
        content: Text(
          'Logged out successfully.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );

    // 3. Destroy navigation history and kick to Login Screen
    // Note: If your class is not named LoginScreen, change it here.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SessionPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // We use a Scaffold here so we can have an AppBar with a Back Button
    return Scaffold(
      backgroundColor: AppBrandColors.blackStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppBrandColors.white,
          ),
          onPressed: () =>
              Navigator.of(context).pop(), // Goes back to Dashboard
        ),
        title: const Text(
          "RIDER NEXUS",
          style: TextStyle(
            color: AppBrandColors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppBrandColors.blackBackgroundGradient,
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppBrandColors.greenMid,
                ),
              )
            : _errorMessage.isNotEmpty
            ? Center(
                child: Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: AppBrandColors.redYellowStart,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _fetchAccountData,
                color: AppBrandColors.greenMid,
                backgroundColor: AppBrandColors.blackEnd,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                  children: [
                    // SECTION A: Massive Profile Information
                    _buildSectionA(),
                    const SizedBox(height: 40),

                    // SECTION B: Gamified Rider Score
                    _buildSectionB(),
                    const SizedBox(height: 40),

                    // SECTION C: System Actions
                    _buildSectionC(),
                  ],
                ),
              ),
      ),
    );
  }

  // ============================================================================
  // SECTION A: MASSIVE, BOLD PROFILE DETAILS
  // ============================================================================
  Widget _buildSectionA() {
    final avatarUrl = _profile!['profile_picture'] ?? '';
    final status = _profile!['account_status'] ?? 'active';

    Color statusColor = AppBrandColors.greenMid;
    if (status == 'suspended') statusColor = AppBrandColors.redYellowEnd;
    if (status == 'banned') statusColor = AppBrandColors.redYellowStart;

    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [statusColor, AppBrandColors.blackEnd],
              ),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 70, // Increased size significantly
              backgroundColor: AppBrandColors.blackStart,
              backgroundImage:
                  avatarUrl.isNotEmpty && avatarUrl.startsWith('http')
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty || !avatarUrl.startsWith('http')
                  ? Text(
                      _profile!['full_name'][0].toUpperCase(),
                      style: const TextStyle(
                        color: AppBrandColors.white,
                        fontSize: 56, // Massive font for missing avatars
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _profile!['full_name'],
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppBrandColors.white,
            fontSize: 28, // Bolder name
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _profile!['student_id'],
          style: const TextStyle(
            color: AppBrandColors.redYellowMid,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _profile!['email'],
          style: const TextStyle(
            color: AppBrandColors.whiteMuted,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        AppStatusChip(label: status.toUpperCase(), color: statusColor),
      ],
    );
  }

  // ============================================================================
  // SECTION B: THE GAMIFIED SCORE CHART
  // ============================================================================
  Widget _buildSectionB() {
    final score = _rating!['score'];
    final grade = _rating!['grade'];
    final title = _rating!['title'];

    final colorStr = _rating!['colorHex'] as String;
    final ratingColor = Color(int.parse(colorStr));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppBrandColors.blackEnd,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppBrandColors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "RIDER TRUST SCORE",
            style: TextStyle(
              color: AppBrandColors.whiteMuted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 32),

          // The Circular Gauge
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 14,
                  backgroundColor: AppBrandColors.blackStart,
                  color: ratingColor,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    grade,
                    style: TextStyle(
                      color: ratingColor,
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppBrandColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 40),
          const Divider(color: Color(0xFF2B2B2B)),
          const SizedBox(height: 20),

          // The Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatBlock(
                "TOTAL RIDES",
                _stats!['total_rides'].toString(),
                AppBrandColors.white,
              ),
              Container(width: 1, height: 50, color: const Color(0xFF2B2B2B)),
              _buildStatBlock(
                "VIOLATIONS",
                _stats!['total_violations'].toString(),
                AppBrandColors.redYellowStart,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBlock(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppBrandColors.whiteMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // SECTION C: SYSTEM ACTIONS & LOGOUT
  // ============================================================================
  Widget _buildSectionC() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 12, bottom: 12),
          child: Text(
            "SYSTEM",
            style: TextStyle(
              color: AppBrandColors.whiteMuted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppBrandColors.blackEnd,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppBrandColors.white.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildActionTile(Icons.history_rounded, "Ride History", () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Ride History coming soon.")),
                );
              }),
              const Divider(color: Color(0xFF2B2B2B), height: 1),
              _buildActionTile(
                Icons.gavel_rounded,
                "Terms & Conditions",
                () {},
              ),
              const Divider(color: Color(0xFF2B2B2B), height: 1),

              // The Destructive Logout Button
              _buildActionTile(
                Icons.logout_rounded,
                "Log Out",
                _handleLogout,
                isDestructive: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? AppBrandColors.redYellowStart
        : AppBrandColors.white;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: color, size: 28),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppBrandColors.whiteMuted.withOpacity(0.5),
      ),
    );
  }
}
