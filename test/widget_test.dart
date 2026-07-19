import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site/data/models/assessment.dart';
import 'package:site/shared/widgets/risk_badge.dart';

// Note: pumping the real app (SiteApp) isn't a viable smoke test here — it
// bootstraps Firebase via AuthGate the moment it builds, which requires
// Firebase.initializeApp() and isn't available in a plain widget test
// without additional mocking infrastructure this project doesn't have yet.
// RiskBadge is a pure presentational widget with no such dependency.
void main() {
  testWidgets('RiskBadge shows the label and color for each risk level',
      (WidgetTester tester) async {
    for (final level in RiskLevel.values) {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: RiskBadge(riskLevel: level))),
      );

      expect(find.text(level.label), findsOneWidget);
      expect(find.byIcon(level.icon), findsOneWidget);
    }
  });
}
