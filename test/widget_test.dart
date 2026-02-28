import 'package:flutter_test/flutter_test.dart';

import 'package:torrentmusic/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const TorrentMusicApp());
    expect(find.text('TorrentMusic'), findsOneWidget);
  });
}
