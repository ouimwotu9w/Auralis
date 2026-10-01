import 'package:flutter_test/flutter_test.dart';

import 'package:auralis/main.dart';

void main() {
  testWidgets('Auralis bootstraps', (tester) async {
    await tester.pumpWidget(const AuralisApp());
    expect(find.text('Auralis Audio Engine'), findsOneWidget);
    expect(find.text('Start Engine'), findsOneWidget);
  });
}
