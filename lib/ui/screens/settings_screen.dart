import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Settings screen — basic structure, details in future PRs.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _section(context, 'Playback'),
                _tile(
                  icon: Icons.high_quality_rounded,
                  title: 'Audio Quality',
                  subtitle: 'High (320 kbps)',
                ),
                _tile(
                  icon: Icons.storage_rounded,
                  title: 'Cache Size Limit',
                  subtitle: '2 GB',
                ),
                const Divider(color: AppColors.divider, height: 32),
                _section(context, 'Sources'),
                _tile(
                  icon: Icons.travel_explore_rounded,
                  title: 'Tracker Configuration',
                  subtitle: 'Manage torrent trackers',
                ),
                const Divider(color: AppColors.divider, height: 32),
                _section(context, 'Appearance'),
                _tile(
                  icon: Icons.dark_mode_rounded,
                  title: 'Theme',
                  subtitle: 'Dark',
                ),
                const Divider(color: AppColors.divider, height: 32),
                _section(context, 'Integrations'),
                _tile(
                  icon: Icons.radio_rounded,
                  title: 'Last.fm Scrobbling',
                  subtitle: 'Not connected',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.onSurface),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.subtle,
      ),
      onTap: () {},
    );
  }
}
