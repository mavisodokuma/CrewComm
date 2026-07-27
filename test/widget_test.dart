import 'package:cmc/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CrewComm lobby renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CrewCommApp()));

    expect(find.text('CrewComm'), findsOneWidget);
    expect(find.text('Create Admin Room'), findsOneWidget);
    expect(find.text('Scan Crew Invite'), findsOneWidget);
  });
}
