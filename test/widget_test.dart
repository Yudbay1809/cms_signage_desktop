// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:cms_signage_desktop/main.dart';

void main() {
  testWidgets('App boots and renders tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const CmsApp());
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Content Control'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Devices'), findsOneWidget);

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    expect(find.text('Buat schedule untuk playlist:'), findsOneWidget);
  });
}
