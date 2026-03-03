import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'leet_indexer.dart';

/// Persistent settings for indexer configuration.
class IndexerSettings {
  const IndexerSettings({
    this.leetEnabled = true,
    this.pirateBayEnabled = true,
    this.solidtorrentsEnabled = true,
    this.bitsearchEnabled = true,
    this.btdigEnabled = true,
    this.nyaaEnabled = true,
    this.torrentGalaxyEnabled = true,
    this.limeTorrentsEnabled = true,
    this.leetMirrors = kLeetMirrors,
  });

  /// Whether the 1337x indexer is enabled.
  final bool leetEnabled;

  /// Whether the PirateBay indexer is enabled.
  final bool pirateBayEnabled;

  /// Whether the Solidtorrents indexer is enabled.
  final bool solidtorrentsEnabled;

  /// Whether the Bitsearch indexer is enabled.
  final bool bitsearchEnabled;

  /// Whether the BTDig indexer is enabled.
  final bool btdigEnabled;

  /// Whether the Nyaa indexer is enabled.
  final bool nyaaEnabled;

  /// Whether the TorrentGalaxy indexer is enabled.
  final bool torrentGalaxyEnabled;

  /// Whether the LimeTorrents indexer is enabled.
  final bool limeTorrentsEnabled;

  /// Ordered list of 1337x mirror URLs.
  final List<String> leetMirrors;

  IndexerSettings copyWith({
    bool? leetEnabled,
    bool? pirateBayEnabled,
    bool? solidtorrentsEnabled,
    bool? bitsearchEnabled,
    bool? btdigEnabled,
    bool? nyaaEnabled,
    bool? torrentGalaxyEnabled,
    bool? limeTorrentsEnabled,
    List<String>? leetMirrors,
  }) {
    return IndexerSettings(
      leetEnabled: leetEnabled ?? this.leetEnabled,
      pirateBayEnabled: pirateBayEnabled ?? this.pirateBayEnabled,
      solidtorrentsEnabled: solidtorrentsEnabled ?? this.solidtorrentsEnabled,
      bitsearchEnabled: bitsearchEnabled ?? this.bitsearchEnabled,
      btdigEnabled: btdigEnabled ?? this.btdigEnabled,
      nyaaEnabled: nyaaEnabled ?? this.nyaaEnabled,
      torrentGalaxyEnabled: torrentGalaxyEnabled ?? this.torrentGalaxyEnabled,
      limeTorrentsEnabled: limeTorrentsEnabled ?? this.limeTorrentsEnabled,
      leetMirrors: leetMirrors ?? this.leetMirrors,
    );
  }
}

// SharedPreferences keys.
const _kLeetEnabled = 'indexer.leet.enabled';
const _kPirateBayEnabled = 'indexer.piratebay.enabled';
const _kSolidtorrentsEnabled = 'indexer.solidtorrents.enabled';
const _kBitsearchEnabled = 'indexer.bitsearch.enabled';
const _kBtdigEnabled = 'indexer.btdig.enabled';
const _kNyaaEnabled = 'indexer.nyaa.enabled';
const _kTorrentGalaxyEnabled = 'indexer.torrentgalaxy.enabled';
const _kLimeTorrentsEnabled = 'indexer.limetorrents.enabled';
const _kLeetMirrors = 'indexer.leet.mirrors';

/// Notifier that persists indexer settings to SharedPreferences.
class IndexerSettingsNotifier extends StateNotifier<IndexerSettings> {
  IndexerSettingsNotifier(this._prefs) : super(const IndexerSettings()) {
    _load();
  }

  final SharedPreferences _prefs;

  void _load() {
    state = IndexerSettings(
      leetEnabled: _prefs.getBool(_kLeetEnabled) ?? true,
      pirateBayEnabled: _prefs.getBool(_kPirateBayEnabled) ?? true,
      solidtorrentsEnabled: _prefs.getBool(_kSolidtorrentsEnabled) ?? true,
      bitsearchEnabled: _prefs.getBool(_kBitsearchEnabled) ?? true,
      btdigEnabled: _prefs.getBool(_kBtdigEnabled) ?? true,
      nyaaEnabled: _prefs.getBool(_kNyaaEnabled) ?? true,
      torrentGalaxyEnabled: _prefs.getBool(_kTorrentGalaxyEnabled) ?? true,
      limeTorrentsEnabled: _prefs.getBool(_kLimeTorrentsEnabled) ?? true,
      leetMirrors: _prefs.getStringList(_kLeetMirrors) ?? kLeetMirrors,
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

  void setSolidtorrentsEnabled(bool enabled) {
    state = state.copyWith(solidtorrentsEnabled: enabled);
    _prefs.setBool(_kSolidtorrentsEnabled, enabled);
  }

  void setBitsearchEnabled(bool enabled) {
    state = state.copyWith(bitsearchEnabled: enabled);
    _prefs.setBool(_kBitsearchEnabled, enabled);
  }

  void setBtdigEnabled(bool enabled) {
    state = state.copyWith(btdigEnabled: enabled);
    _prefs.setBool(_kBtdigEnabled, enabled);
  }

  void setNyaaEnabled(bool enabled) {
    state = state.copyWith(nyaaEnabled: enabled);
    _prefs.setBool(_kNyaaEnabled, enabled);
  }

  void setTorrentGalaxyEnabled(bool enabled) {
    state = state.copyWith(torrentGalaxyEnabled: enabled);
    _prefs.setBool(_kTorrentGalaxyEnabled, enabled);
  }

  void setLimeTorrentsEnabled(bool enabled) {
    state = state.copyWith(limeTorrentsEnabled: enabled);
    _prefs.setBool(_kLimeTorrentsEnabled, enabled);
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
