import 'package:flutter_test/flutter_test.dart';
import 'package:mouse_munch/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the game starts with an empty floor and a hint', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const MouseMunchApp());
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.textContaining('кормушку'), findsOneWidget);
    expect(find.textContaining('Крошек: 0'), findsOneWidget);
  });
}
