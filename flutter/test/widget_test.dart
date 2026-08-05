import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visionaid/main.dart';

void main() {
  testWidgets('VisionAid app navigates from splash to auth', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VisionAidApp()));
    expect(find.text('VisionAid++'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}
