import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Library screen — placeholder for Phase 2 (playlists, favorites, etc.).
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Library',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.library_music_rounded,
                    size: 64,
                    color: AppColors.surfaceVariant,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Your library will appear here',
                    style: TextStyle(color: AppColors.subtle),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
