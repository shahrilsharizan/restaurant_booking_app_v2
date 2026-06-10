import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_booking_app/main.dart';

void main() {
  testWidgets('Restaurant booking app starts on initial screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: RestaurantBookingApp()));
    await tester.pumpAndSettle();

    expect(
      find.text("Welcome to the app &\nlet's get started"),
      findsOneWidget,
    );
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Join now'), findsOneWidget);
  });
}
