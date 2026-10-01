import 'package:flutter_test/flutter_test.dart';

import 'package:auralis/main.dart';

void main() {
  testWidgets('Auralis explains prototype state and microphone test', (tester) async {
    await tester.pumpWidget(const AuralisApp());

    expect(find.text('Hear less noise.'), findsOneWidget);
    expect(find.text('Prototype mode — no ANC yet'), findsOneWidget);
    expect(find.text('Start microphone test'), findsOneWidget);
    expect(find.textContaining('does not yet generate anti-noise'), findsOneWidget);
  });
}
