import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torrentmusic/main.dart';
import 'package:torrentmusic/search/indexer_settings.dart';

void main() {
  testWidgets('App renders without crashing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const TorrentMusicApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
