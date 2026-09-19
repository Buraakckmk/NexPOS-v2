import "package:flutter_test/flutter_test.dart";
import "package:nexpos/main.dart";

void main() {
  testWidgets("POS login screen smoke test", (tester) async {
    await tester.pumpWidget(const PosApp());
    expect(find.text("NEXPOS"), findsOneWidget);
    expect(find.text("PIN Kodunuzu Girin"), findsOneWidget);
  });
}
