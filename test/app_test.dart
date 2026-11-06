import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventh_card_game/app.dart';

void main() {
  testWidgets('opens in Arabic, right to left, by default', (tester) async {
    await tester.pumpWidget(const SeventhCardApp());
    await tester.pumpAndSettle();

    final title = find.text('الورقة السابعة');
    expect(title, findsOneWidget);
    expect(Directionality.of(tester.element(title)), TextDirection.rtl);
  });

  testWidgets('shows English left to right when the locale is English', (tester) async {
    await tester.pumpWidget(const SeventhCardApp(locale: Locale('en')));
    await tester.pumpAndSettle();

    final title = find.text('The Seventh Card');
    expect(title, findsOneWidget);
    expect(Directionality.of(tester.element(title)), TextDirection.ltr);
  });
}
