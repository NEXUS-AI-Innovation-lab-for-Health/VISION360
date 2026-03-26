import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/main.dart';

void main() {
  testWidgets('shows auth screen on startup', (WidgetTester tester) async {
    await tester.pumpWidget(const Vision360App());
    await tester.pumpAndSettle();

    expect(find.text('Connexion Vision360'), findsOneWidget);
  });
}
