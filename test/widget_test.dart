import 'package:flutter_test/flutter_test.dart';
import 'package:site_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SiteApp());
    expect(find.byType(SiteApp), findsOneWidget);
  });
}
