import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'leet_indexer.dart';

/// Persistent settings for indexer configuration.
class IndexerSettings {
  const IndexerSettings({
    this.leetEnabled = true,
    this.pirateBayEnabled = true,
    this.leetMirrors = kLeetMirrors,
  });

  /// Whether the 1337x indexer is enabled.
  final bool leetEnabled;

  /// Whether the PirateBay indexer is enabled.
  final bool pirateBayEnabled;

  /// Ordered list of 1337x mirror URLs.
  final List<String> leetMirrors;

  IndexerSettings copyWith({
    bool? leetEnabled,
    bool? pirateBayEnabled,
    List<String>? leetMirrors,
  }) {
    return IndexerSettings(
      leetEnabled: leetEnabled ?? this.leetEnabled,
      pirateBayEnabled: pirateBayEnabled ?? this.pirateBayEnabled,
      leetMirrors: leetMirrors ?? this.leetMirrors,
    );
  }
}

// SharedPreferences keys.
const _kLeetEnabled = 'indexer.leet.enabled';
const _kPirateBayEnabled = 'indexer.piratebay.enabled';
const _kLeetMirrors = 'indexer.leet.mirrors';

/// Notifier that persists indexer settings to SharedPreferences.
class IndexerSettingsNotifier extends StateNotifier<IndexerSettings> {
  IndexerSettingsNotifier(this._prefs) : super(const IndexerSettings()) {
    _load();
  }

  final SharedPreferences _prefs;

  void _load() {
    final leetEnabled = _prefs.getBool(_kLeetEnabled) ?? true;
    final pirateBayEnabled = _prefs.getBool(_kPirateBayEnabled) ?? false;
    final mirrors = _prefs.getStringList(_kLeetMirrors) ?? kLeetMirrors;

    state = IndexerSettings(
      leetEnabled: leetEnabled,
      pirateBayEnabled: pirateBayEnabled,
      leetMirrors: mirrors,
    );
  }

  void setLeetEnabled(bool enabled) {
    state = state.copyWith(leetEnabled: enabled);
    _prefs.setBool(_kLeetEnabled, enabled);
  }

  void setPirateBayEnabled(bool enabled) {
    state = state.copyWith(pirateBayEnabled: enabled);
    _prefs.setBool(_kPirateBayEnabled, enabled);
  }

  void setLeetMirrors(List<String> mirrors) {
    state = state.copyWith(leetMirrors: mirrors);
    _prefs.setStringList(_kLeetMirrors, mirrors);
  }
}

/// Provides SharedPreferences — must be overridden at app startup.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with a real instance.',
  );
});

/// Provides the [IndexerSettings] state with persistence.
final indexerSettingsProvider =
    StateNotifierProvider<IndexerSettingsNotifier, IndexerSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return IndexerSettingsNotifier(prefs);
});
