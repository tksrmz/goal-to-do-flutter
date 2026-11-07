import 'package:flutter_test/flutter_test.dart';

import 'package:goal_to_do/main.dart';

void main() {
  testWidgets('MainApp renders', (tester) async {
    await tester.pumpWidget(const MainApp());

    expect(find.text('Hello World!'), findsOneWidget);
  });
}
