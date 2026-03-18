import 'package:flutter/material.dart';

import '../theme_settings.dart';

class UserSupportScreen extends StatelessWidget {
  const UserSupportScreen({super.key});

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppBrandColors.blackEnd,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppBrandColors.redYellowMid.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppBrandColors.redYellowEnd, size: 20),
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
                  subtitle,
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
            'Support Hub',
            style: TextStyle(
              color: AppBrandColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _buildContactCard(
            icon: Icons.call_rounded,
            title: 'Call Support',
            subtitle: '+233 XX XXX XXXX',
          ),
          _buildContactCard(
            icon: Icons.message_rounded,
            title: 'Chat Support',
            subtitle: 'Average response: 2 mins',
          ),
          _buildContactCard(
            icon: Icons.report_problem_rounded,
            title: 'Report Incident',
            subtitle: 'Bike fault, route issue, payment issue',
          ),
        ],
      ),
    );
  }
}
