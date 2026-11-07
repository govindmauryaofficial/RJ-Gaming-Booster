import 'package:flutter_test/flutter_test.dart';
import 'package:rj_gaming_booster/main.dart';

void main() {
  testWidgets('shows RJ Gaming Booster home screen', (tester) async {
    await tester.pumpWidget(const RJGamingBoosterApp());
    expect(find.text('RJ GAMING'), findsOneWidget);
    expect(find.text('LIVE NETWORK PING'), findsOneWidget);
    expect(find.text('START LIVE MONITOR'), findsOneWidget);
  });
}
