import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gymtrackr/src/app.dart';


void main() {
  testWidgets('Bottom navigation with 5 tabs is visible and tappable', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GymTrackrApp()));
    await tester.pumpAndSettle();

    // NavigationBar vorhanden
    final navBar = find.byType(NavigationBar);
    expect(navBar, findsOneWidget);

    // Tabs (Labels) sind in der NavigationBar sichtbar
    expect(find.descendant(of: navBar, matching: find.text('Heute')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('Pläne')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('Übungen')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('Historie')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('Einstellungen')), findsOneWidget);

    // Start: Heute-Seite ist aktiv
    expect(find.byKey(const Key('title-today')), findsOneWidget);

    // Zu "Pläne" wechseln
    await tester.tap(find.descendant(of: navBar, matching: find.text('Pläne')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('title-plans')), findsOneWidget);
    expect(find.byKey(const Key('title-today')), findsNothing);

    // Zu "Übungen" wechseln
    await tester.tap(find.descendant(of: navBar, matching: find.text('Übungen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('title-exercises')), findsOneWidget);

    // Zu "Historie" wechseln
    await tester.tap(find.descendant(of: navBar, matching: find.text('Historie')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('title-history')), findsOneWidget);

    // Zu "Einstellungen" wechseln
    await tester.tap(find.descendant(of: navBar, matching: find.text('Einstellungen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('title-settings')), findsOneWidget);
  });
}
