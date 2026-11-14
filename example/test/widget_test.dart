import 'package:flutter_test/flutter_test.dart';
import 'package:firebridge_flutter/firebridge_flutter.dart';
import 'package:example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FirebridgeExampleApp renders AuthScreen smoke test', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await Firebridge.initialize(enableLogging: false);
    });

    await tester.pumpWidget(const FirebridgeExampleApp());
    await tester.pump();

    expect(find.text('Firebridge'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Direct Token Sign-In'), findsOneWidget);
  });
}
