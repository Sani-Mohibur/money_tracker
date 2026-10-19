import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_tracker/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MoneyTrackerApp renders 5-tab navigation, balance card and FAB', (WidgetTester tester) async {
    await tester.pumpWidget(const MoneyTrackerApp(initialThemeMode: ThemeMode.light));
    await tester.pumpAndSettle();

    // Verify app title and navigation bar destinations
    expect(find.text('Money Tracker'), findsWidgets);
    expect(find.text('TOTAL BALANCE'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify FAB is present
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // Switch to Calendar tab
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    expect(find.text('Calendar'), findsWidgets);

    // Switch to Stats tab
    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Category Breakdown'), findsOneWidget);

    // Switch to History tab
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget); // Search bar

    // Switch to Settings tab
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('CURRENCY & EXCHANGE RATES'), findsOneWidget);
  });
}
