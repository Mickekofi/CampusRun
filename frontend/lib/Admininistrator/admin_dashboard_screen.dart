import 'package:flutter/material.dart';

import 'admin_bike_operations_screen.dart';
import 'admin_bike_upload_screen.dart';
import 'admin_live_tracker_screen.dart';
import 'admin_station_upload_screen.dart';
import 'admin_user_monitor_screen.dart';
import '../theme_settings.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    AdminBikeUploadScreen(),
    AdminStationUploadScreen(),
    AdminBikeOperationsScreen(),
    AdminUserMonitorScreen(),
    AdminLiveTrackerScreen(),
  ];

  final List<_AdminTabItem> _tabs = const [
    _AdminTabItem(icon: Icons.two_wheeler_rounded, label: 'Bike Upload'),
    _AdminTabItem(icon: Icons.location_city_rounded, label: 'Stations'),
    _AdminTabItem(icon: Icons.settings_suggest_rounded, label: 'Bike Ops'),
    _AdminTabItem(icon: Icons.monitor_heart_rounded, label: 'Users'),
    _AdminTabItem(icon: Icons.satellite_alt_rounded, label: 'Live Track'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Admin Control Arena'),
        centerTitle: true,
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: AppBrandColors.redYellowGradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppBrandColors.white.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: AppBrandColors.redYellowMid.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_tabs.length, (index) {
              final tab = _tabs[index];
              final selected = index == _currentIndex;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppBrandColors.blackStart.withOpacity(0.85)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.icon,
                          color: selected
                              ? AppBrandColors.greenMid
                              : AppBrandColors.white,
                          size: selected ? 26 : 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppBrandColors.white,
                            fontSize: 11,
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
      ),
    );
  }
}

class _AdminTabItem {
  const _AdminTabItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
