import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torrentmusic/search/indexer_settings.dart';
import 'package:torrentmusic/search/leet_indexer.dart';

void main() {
  group('IndexerSettings defaults', () {
    test('all indexers default to enabled', () {
      const settings = IndexerSettings();
      expect(settings.leetEnabled, isTrue);
      expect(settings.pirateBayEnabled, isTrue);
      expect(settings.solidtorrentsEnabled, isTrue);
      expect(settings.bitsearchEnabled, isTrue);
      expect(settings.btdigEnabled, isTrue);
      expect(settings.nyaaEnabled, isTrue);
      expect(settings.torrentGalaxyEnabled, isTrue);
      expect(settings.limeTorrentsEnabled, isTrue);
    });

    test('default mirrors match kLeetMirrors', () {
      const settings = IndexerSettings();
      expect(settings.leetMirrors, equals(kLeetMirrors));
    });
  });

  group('IndexerSettings copyWith', () {
    test('preserves unspecified fields', () {
      const settings = IndexerSettings();
      final copy = settings.copyWith(leetEnabled: false);
      expect(copy.leetEnabled, isFalse);
      expect(copy.pirateBayEnabled, isTrue);
      expect(copy.solidtorrentsEnabled, isTrue);
      expect(copy.bitsearchEnabled, isTrue);
      expect(copy.btdigEnabled, isTrue);
      expect(copy.nyaaEnabled, isTrue);
      expect(copy.torrentGalaxyEnabled, isTrue);
      expect(copy.limeTorrentsEnabled, isTrue);
    });

    test('updates all specified fields', () {
      const settings = IndexerSettings();
      final copy = settings.copyWith(
        leetEnabled: false,
        pirateBayEnabled: false,
        solidtorrentsEnabled: false,
        bitsearchEnabled: false,
        btdigEnabled: false,
        nyaaEnabled: false,
        torrentGalaxyEnabled: false,
        limeTorrentsEnabled: false,
      );
      expect(copy.leetEnabled, isFalse);
      expect(copy.pirateBayEnabled, isFalse);
      expect(copy.solidtorrentsEnabled, isFalse);
      expect(copy.bitsearchEnabled, isFalse);
      expect(copy.btdigEnabled, isFalse);
      expect(copy.nyaaEnabled, isFalse);
      expect(copy.torrentGalaxyEnabled, isFalse);
      expect(copy.limeTorrentsEnabled, isFalse);
    });
  });

  group('IndexerSettingsNotifier persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads all-enabled defaults when no prefs stored', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = IndexerSettingsNotifier(prefs);

      expect(notifier.state.leetEnabled, isTrue);
      expect(notifier.state.pirateBayEnabled, isTrue);
      expect(notifier.state.solidtorrentsEnabled, isTrue);
      expect(notifier.state.bitsearchEnabled, isTrue);
      expect(notifier.state.btdigEnabled, isTrue);
      expect(notifier.state.nyaaEnabled, isTrue);
      expect(notifier.state.torrentGalaxyEnabled, isTrue);
      expect(notifier.state.limeTorrentsEnabled, isTrue);
    });

    test('persists leet enabled flag and reloads correctly', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = IndexerSettingsNotifier(prefs);

      notifier.setLeetEnabled(false);
      expect(prefs.getBool('indexer.leet.enabled'), isFalse);

      final reloaded = IndexerSettingsNotifier(prefs);
      expect(reloaded.state.leetEnabled, isFalse);
    });

    test('persists pirateBay enabled flag', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = IndexerSettingsNotifier(prefs);

      notifier.setPirateBayEnabled(false);
      expect(prefs.getBool('indexer.piratebay.enabled'), isFalse);

      final reloaded = IndexerSettingsNotifier(prefs);
      expect(reloaded.state.pirateBayEnabled, isFalse);
    });

    test('persists solidtorrents enabled flag', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = IndexerSettingsNotifier(prefs);

      notifier.setSolidtorrentsEnabled(false);
      expect(prefs.getBool('indexer.solidtorrents.enabled'), isFalse);

      final reloaded = IndexerSettingsNotifier(prefs);
      expect(reloaded.state.solidtorrentsEnabled, isFalse);
    });

    test('persists bitsearch enabled flag', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = IndexerSettingsNotifier(prefs);

      notifier.setBitsearchEnabled(false);
      expect(prefs.getBool('indexer.bitsearch.enabled'), isFalse);

      final reloaded = IndexerSettingsNotifier(prefs);
      expect(reloaded.state.bitsearchEnabled, isFalse);
    });

    test('persists btdig enabled flag', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = IndexerSettingsNotifier(prefs);

      notifier.setBtdigEnabled(false);
      expect(prefs.getBool('indexer.btdig.enabled'), isFalse);

      final reloaded = IndexerSettingsNotifier(prefs);
      expect(reloaded.state.btdigEnabled, isFalse);
    });

    test('persists nyaa enabled flag', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = IndexerSettingsNotifier(prefs);

      notifier.setNyaaEnabled(false);
      expect(prefs.getBool('indexer.nyaa.enabled'), isFalse);

      final reloaded = IndexerSettingsNotifier(prefs);
      expect(reloaded.state.nyaaEnabled, isFalse);
    });

    test('persists torrentGalaxy enabled flag', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = IndexerSettingsNotifier(prefs);

      notifier.setTorrentGalaxyEnabled(false);
      expect(prefs.getBool('indexer.torrentgalaxy.enabled'), isFalse);

      final reloaded = IndexerSettingsNotifier(prefs);
      expect(reloaded.state.torrentGalaxyEnabled, isFalse);
    });

    test('persists limeTorrents enabled flag', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = IndexerSettingsNotifier(prefs);

      notifier.setLimeTorrentsEnabled(false);
      expect(prefs.getBool('indexer.limetorrents.enabled'), isFalse);

      final reloaded = IndexerSettingsNotifier(prefs);
      expect(reloaded.state.limeTorrentsEnabled, isFalse);
    });

    test('persists leet mirrors list', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = IndexerSettingsNotifier(prefs);

      const customMirrors = ['https://mirror1.example.com'];
      notifier.setLeetMirrors(customMirrors);
      expect(prefs.getStringList('indexer.leet.mirrors'), customMirrors);

      final reloaded = IndexerSettingsNotifier(prefs);
      expect(reloaded.state.leetMirrors, customMirrors);
    });

    test('loads stored values when prefs are pre-populated', () async {
      SharedPreferences.setMockInitialValues({
        'indexer.leet.enabled': false,
        'indexer.solidtorrents.enabled': false,
        'indexer.nyaa.enabled': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = IndexerSettingsNotifier(prefs);

      expect(notifier.state.leetEnabled, isFalse);
      expect(notifier.state.solidtorrentsEnabled, isFalse);
      expect(notifier.state.nyaaEnabled, isFalse);
      // Unpersisted ones still default to true.
      expect(notifier.state.pirateBayEnabled, isTrue);
      expect(notifier.state.bitsearchEnabled, isTrue);
    });
  });
}
