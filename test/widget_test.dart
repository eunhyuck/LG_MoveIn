// This is a basic Flutter widget test for the LG ThinQ MoveIn App.

import 'package:flutter_test/flutter_test.dart';

import 'package:lg_move_in/main.dart';

void main() {
  testWidgets('ThinQ MoveIn App Load Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the LG ThinQ title is displayed.
    expect(find.text('LG ThinQ'), findsOneWidget);

    // Verify that the Menu tab content loads and has the MoveIn helper button.
    expect(find.text('MoveIn · 이사 도우미'), findsOneWidget);
  });
}

