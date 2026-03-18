import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../admin_ip.dart';
import '../log_session.dart';
import '../theme_settings.dart';
import '../widgets/app_status_chip.dart';

// Screens
import 'user_account_screen.dart';
import 'user_bike_selection_screen.dart';
import 'user_confirm_bike_screen.dart';
import 'user_ridemode_screen.dart';
import 'user_scanQR_screen.dart';
import 'user_deposit_screen.dart';

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  // =========================
  // SECTION 1: STATE
  // =========================

  int _currentIndex = 0;
  bool _loadingOverview = false;
  String _overviewError = '';

  int _activeRides = 0;
  int _totalRides = 0;
  int _activeReservations = 0;
  double _walletBalance = 0;

  // 1. The Global Refresh Seed (Forces frozen screens to update)
  int _globalRefreshSeed = 0;

  // 2. The Master Router Function
  void _switchTabAndRefresh(int targetIndex) {
    setState(() {
      _currentIndex = targetIndex;
      _globalRefreshSeed++; // Breaks the IndexedStack cache
    });
    _loadDashboardOverview(); // Refresh the top stats
  }

  // 3. The 5 Core Action Screens
  List<Widget> get _screens => [
    UserBikeSelectionScreen(
      key: ValueKey('select_$_globalRefreshSeed'),
      onRideSelected: (bikeId, stationId) =>
          _switchTabAndRefresh(1), // Auto-jump to Confirm
    ),
    UserConfirmBikeScreen(key: ValueKey('confirm_$_globalRefreshSeed')),
    UserScanQrScreen(
      key: ValueKey('scan_$_globalRefreshSeed'),
      onRideStarted: () => _switchTabAndRefresh(3), // Auto-jump to Ride
    ),
    UserRideModeScreen(
      key: ValueKey('ride_$_globalRefreshSeed'),
      onRideEnded: () => _switchTabAndRefresh(0), // Auto-jump back to Select
    ),
    UserDepositScreen(key: ValueKey('deposit_$_globalRefreshSeed')),
  ];

  // 4. The 5 Core Tabs (Account is removed)
  final List<_UserTabItem> _tabs = const [
    _UserTabItem(icon: Icons.pedal_bike_rounded, label: 'Select'),
    _UserTabItem(icon: Icons.verified_rounded, label: 'Confirm'),
    _UserTabItem(icon: Icons.qr_code_scanner_rounded, label: 'Scan'),
    _UserTabItem(icon: Icons.speed_rounded, label: 'Ride'),
    _UserTabItem(icon: Icons.account_balance_wallet_rounded, label: 'Deposit'),
  ];

  static const List<String> _titles = [
    'Bike Selection Arena',
    'Confirm Bike Access',
    'QR Launch Console',
    'Ride Mode Live',
    'Wallet Funding',
  ];

  // =========================
  // SECTION 3: LIFECYCLE
  // =========================

  @override
  void initState() {
    super.initState();
    _loadDashboardOverview();
  }

  // =========================
  // SECTION 4: API HELPERS
  // =========================

  Map<String, dynamic>? _decodeBody(http.Response response) {
    try {
      final raw = utf8.decode(response.bodyBytes);
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  Future<void> _loadDashboardOverview() async {
    final userId = LogSession.instance.userId;
    if (userId == null || userId <= 0) return;

    setState(() {
      _loadingOverview = true;
      _overviewError = '';
    });

    try {
      final uri = Uri.parse(
        '${AdminIp.baseUrl}/api/user_dashboard_routes/overview?user_id=$userId',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      final body = _decodeBody(response);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = body?['data'] as Map<String, dynamic>? ?? {};
        final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
        final profile = data['profile'] as Map<String, dynamic>? ?? {};

        setState(() {
          _activeRides = _toInt(metrics['active_rides']);
          _totalRides = _toInt(metrics['total_rides']);
          _activeReservations = _toInt(metrics['active_reservations']);
          _walletBalance = _toDouble(profile['wallet_balance']);
          _loadingOverview = false;
        });
      } else {
        setState(() {
          _loadingOverview = false;
          _overviewError = body?['message']?.toString() ?? 'Update failed.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingOverview = false;
          _overviewError = 'Network error.';
        });
      }
    }
  }

  int _toInt(dynamic value) =>
      value is int ? value : int.tryParse('${value ?? 0}') ?? 0;
  double _toDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('${value ?? 0}') ?? 0;

  // =========================
  // SECTION 5: UI WIDGETS
  // =========================

  // The Uber-Style Profile Badge in the AppBar
  Widget _buildProfileBadge() {
    final picUrl = LogSession.instance.profilePicture ?? '';
    final fullName = LogSession.instance.fullName ?? 'Rider';
    final firstName = fullName.split(' ').first; // Extract just the first name

    return GestureDetector(
      onTap: () {
        // Push the Account screen over the top of the dashboard
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserAccountScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppBrandColors.blackEnd,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppBrandColors.greenMid.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              firstName,
              style: const TextStyle(
                color: AppBrandColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 12,
              backgroundColor: AppBrandColors.blackStart,
              backgroundImage: picUrl.isNotEmpty && picUrl.startsWith('http')
                  ? NetworkImage(picUrl)
                  : null,
              child: picUrl.isEmpty || !picUrl.startsWith('http')
                  ? Text(
                      firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppBrandColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatsStrip() {
    if (_loadingOverview) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
        child: LinearProgressIndicator(minHeight: 4),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          AppStatusChip(
            label: 'Active Ride',
            color: AppBrandColors.greenMid,
            value: _activeRides,
          ),
          AppStatusChip(
            label: 'Total Rides',
            color: AppBrandColors.redYellowEnd,
            value: _totalRides,
          ),
          AppStatusChip(
            label: 'Reservations',
            color: AppBrandColors.whiteMuted,
            value: _activeReservations,
          ),
          AppStatusChip(
            label: 'Wallet GHS',
            color: AppBrandColors.redYellowMid,
            value: _walletBalance.round(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomGameTabs() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppBrandColors.redYellowStart,
              AppBrandColors.redYellowMid,
              AppBrandColors.blackEnd,
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppBrandColors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: AppBrandColors.redYellowMid.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppBrandColors.greenMid.withOpacity(0.22),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_tabs.length, (index) {
            final tab = _tabs[index];
            final selected = _currentIndex == index;

            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _currentIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            colors: [
                              AppBrandColors.blackStart,
                              AppBrandColors.blackEnd,
                            ],
                          )
                        : null,
                    color: selected ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppBrandColors.greenMid.withOpacity(0.85)
                          : Colors.transparent,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppBrandColors.greenMid.withOpacity(0.28),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.icon,
                        color: selected
                            ? AppBrandColors.greenMid
                            : AppBrandColors.white,
                        size: selected ? 21 : 19,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppBrandColors.white,
                          fontSize: 9.5,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // =========================
  // SECTION 6: BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            onPressed: _loadDashboardOverview,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh overview',
          ),
          _buildProfileBadge(), // The new top-right account button
        ],
      ),
      body: Column(
        children: [
          _buildLiveStatsStrip(),
          if (_overviewError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
              child: Text(
                _overviewError,
                style: const TextStyle(
                  color: AppBrandColors.redYellowStart,
                  fontSize: 12,
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomGameTabs(),
    );
  }
}

class _UserTabItem {
  const _UserTabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
