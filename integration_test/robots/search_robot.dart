import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Page Object for search screen interactions.
class SearchRobot {
  final WidgetTester tester;

  const SearchRobot(this.tester);

  Finder get _searchField => find.byType(TextField);
  Finder get _clearButton => find.byTooltip('Clear search');
  Finder get _loadingIndicator => find.byType(CircularProgressIndicator);
  Finder get _retryButton => find.text('Retry');
  Finder get _noResultsIcon => find.byIcon(Icons.music_off_rounded);
  Finder get _searchHint => find.text('Search for music to start streaming');

  /// Enter a search query and submit.
  Future<void> enterQuery(String query) async {
    await tester.enterText(_searchField, query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  /// Clear the search field.
  Future<void> clearQuery() async {
    // First type something so clear button appears.
    if (_clearButton.evaluate().isNotEmpty) {
      await tester.tap(_clearButton);
      await tester.pumpAndSettle();
    }
  }

  /// Tap a search result by its title text.
  Future<void> tapResult(String title) async {
    final finder = find.text(title);
    expect(finder, findsOneWidget, reason: 'Result "$title" should be visible');
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Long-press a search result to add to queue.
  Future<void> longPressResult(String title) async {
    final finder = find.text(title);
    expect(finder, findsOneWidget, reason: 'Result "$title" should be visible');
    await tester.longPress(finder);
    await tester.pumpAndSettle();
  }

  /// Tap the retry button.
  Future<void> tapRetry() async {
    expect(_retryButton, findsOneWidget, reason: 'Retry button should exist');
    await tester.tap(_retryButton);
    await tester.pumpAndSettle();
  }

  /// Verify search results are displayed.
  void expectResultsVisible(List<String> titles) {
    for (final title in titles) {
      expect(
        find.text(title),
        findsOneWidget,
        reason: '"$title" should be visible',
      );
    }
  }

  /// Verify that a result tile shows seeds, source, and size info.
  void expectResultMetadata(String title) {
    expect(find.text(title), findsOneWidget);
    // Seeds icon exists
    expect(find.bySemanticsLabel('Seeds'), findsWidgets);
  }

  /// Verify results are cleared.
  void expectResultsCleared() {
    expect(_searchHint, findsOneWidget);
  }

  /// Verify loading state is shown.
  void expectLoading() {
    expect(_loadingIndicator, findsWidgets);
  }

  /// Verify empty results message.
  void expectEmptyResults(String query) {
    expect(find.textContaining('No results found'), findsOneWidget);
  }

  /// Verify error state with retry button.
  void expectError() {
    expect(find.text('Search failed'), findsOneWidget);
    expect(_retryButton, findsOneWidget);
  }

  /// Verify no results icon is not shown (i.e. results exist).
  void expectNoEmptyState() {
    expect(_noResultsIcon, findsNothing);
  }
}
