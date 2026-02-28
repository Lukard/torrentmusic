import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrentmusic/main.dart';

void main() {
  testWidgets('App renders without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TorrentMusicApp()),
    );
    // Just verify it builds without throwing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
