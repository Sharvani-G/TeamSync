import 'package:flutter_test/flutter_test.dart';

import 'package:teamsync/main.dart';

void main() {
  testWidgets('ProjectSync home shell loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ProjectSyncApp());
    await tester.pumpAndSettle();

    expect(find.text('Projects'), findsWidgets);
    expect(find.text('ProjectSync App'), findsOneWidget);
  });
}
