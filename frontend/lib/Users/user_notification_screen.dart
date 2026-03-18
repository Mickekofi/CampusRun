import 'package:flutter/material.dart';

import '../theme_settings.dart';

class UserNotificationScreen extends StatelessWidget {
  const UserNotificationScreen({super.key});

  Widget _buildItem({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppBrandColors.blackEnd,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppBrandColors.white.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppBrandColors.greenMid, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppBrandColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppBrandColors.whiteMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppBrandColors.blackBackgroundGradient,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          const Text(
            'Notifications',
            style: TextStyle(
              color: AppBrandColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _buildItem(
            icon: Icons.directions_bike_rounded,
            title: 'Ride Reminder',
            body: 'Your reserved bike expires in 7 minutes.',
          ),
          _buildItem(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Wallet',
            body: 'Top up to avoid ride interruption.',
          ),
          _buildItem(
            icon: Icons.support_agent_rounded,
            title: 'Support',
            body: 'New response from support team is available.',
          ),
        ],
      ),
    );
  }
}
