import 'package:flutter_test/flutter_test.dart';
import 'package:karta_mobile/main.dart';
void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KartaMobileApp());
    expect(find.text('karta.ba'), findsOneWidget);
  });
}