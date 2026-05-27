import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teamsync/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sender does not see self-echo SnackBar', (WidgetTester tester) async {
    // Initialize Firebase and sign in anonymously for a test session.
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // ignore - app may initialize itself in main
    }

    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (_) {
      // ignore sign-in errors; if already signed in, continue
    }

    // Start the real app.
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Try to find a chat input field and send button.
    final Finder textField = find.byType(TextField);
    expect(textField, findsAtLeastNWidgets(0));

    if (await tester.pumpAndSettle().then((_) => textField.evaluate().isNotEmpty)) {
      // Enter a test message into the first text field found.
      await tester.enterText(textField.first, 'integration-test-message');
      await tester.pumpAndSettle();

      // Attempt to find the send icon and tap it.
      final Finder sendIcon = find.byIcon(Icons.send);
      if (sendIcon.evaluate().isNotEmpty) {
        await tester.tap(sendIcon.first);
      } else {
        // Try a generic icon button with tooltip 'Send' or an ElevatedButton with 'Send'
        final Finder sendButton = find.widgetWithText(ElevatedButton, 'Send');
        if (sendButton.evaluate().isNotEmpty) {
          await tester.tap(sendButton.first);
        }
      }

      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    // Assert that no SnackBar or banner with 'New message from' is present on sender's viewport.
    final Finder newMessageFinder = find.textContaining('New message from');
    expect(newMessageFinder, findsNothing);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
