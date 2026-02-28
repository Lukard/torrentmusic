import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../search/indexer_settings.dart';
import '../../search/leet_indexer.dart';
import '../theme/app_colors.dart';

/// Settings screen with indexer configuration.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(indexerSettingsProvider);
    final notifier = ref.read(indexerSettingsProvider.notifier);

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
                _section(context, 'Indexers'),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.search_rounded,
                    color: AppColors.onSurface,
                  ),
                  title: const Text('1337x'),
                  subtitle: Text(
                    settings.leetMirrors.first,
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: settings.leetEnabled,
                  onChanged: (v) => notifier.setLeetEnabled(v),
                ),
                if (settings.leetEnabled)
                  Padding(
                    padding: const EdgeInsets.only(left: 56, right: 16),
                    child: _MirrorListTile(
                      mirrors: settings.leetMirrors,
                      onChanged: notifier.setLeetMirrors,
                    ),
                  ),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.sailing_rounded,
                    color: AppColors.onSurface,
                  ),
                  title: const Text('The Pirate Bay'),
                  subtitle: const Text(
                    'apibay.org',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: settings.pirateBayEnabled,
                  onChanged: (v) => notifier.setPirateBayEnabled(v),
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

/// Displays the list of 1337x mirrors with add/remove/reorder capability.
class _MirrorListTile extends StatelessWidget {
  const _MirrorListTile({
    required this.mirrors,
    required this.onChanged,
  });

  final List<String> mirrors;
  final ValueChanged<List<String>> onChanged;

  void _showEditDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _MirrorEditDialog(
        mirrors: mirrors,
        onSave: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showEditDialog(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mirrors',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${mirrors.length} configured — tap to edit',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.subtle,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.edit_rounded,
              size: 18,
              color: AppColors.subtle,
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for editing 1337x mirror URLs.
class _MirrorEditDialog extends StatefulWidget {
  const _MirrorEditDialog({
    required this.mirrors,
    required this.onSave,
  });

  final List<String> mirrors;
  final ValueChanged<List<String>> onSave;

  @override
  State<_MirrorEditDialog> createState() => _MirrorEditDialogState();
}

class _MirrorEditDialogState extends State<_MirrorEditDialog> {
  late List<String> _mirrors;
  final _addController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mirrors = List.of(widget.mirrors);
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _addMirror() {
    final url = _addController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) return;
    setState(() {
      _mirrors.add(url);
      _addController.clear();
    });
  }

  void _resetDefaults() {
    setState(() {
      _mirrors = List.of(kLeetMirrors);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('1337x Mirrors'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Mirrors are tried in order. Drag to reorder.',
              style: TextStyle(fontSize: 12, color: AppColors.subtle),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: _mirrors.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _mirrors.removeAt(oldIndex);
                    _mirrors.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  return ListTile(
                    key: ValueKey('$index-${_mirrors[index]}'),
                    dense: true,
                    title: Text(
                      _mirrors[index],
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _mirrors.length > 1
                          ? () => setState(() => _mirrors.removeAt(index))
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'https://...',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onSubmitted: (_) => _addMirror(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: _addMirror,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _resetDefaults,
          child: const Text('Reset defaults'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_mirrors);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
