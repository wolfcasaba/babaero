import 'package:babaero/features/chat/widgets/message_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Smoke coverage for the read-receipt UI on the shared MessageBubble. Pure
/// widget test — no Supabase, no network — so it's stable in the headless env.
void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      );

  final t = DateTime(2026, 7, 5, 14, 30);

  testWidgets('read message shows the double-check receipt', (tester) async {
    await tester.pumpWidget(host(MessageBubble(
      mine: true,
      body: 'hello',
      createdAt: t,
      readReceipt: true,
    )));
    expect(tester.takeException(), isNull);
    expect(find.byIcon(LucideIcons.checkCheck), findsOneWidget);
    expect(find.byIcon(LucideIcons.check), findsNothing);
  });

  testWidgets('sent-but-unread message shows the single-check receipt',
      (tester) async {
    await tester.pumpWidget(host(MessageBubble(
      mine: true,
      body: 'hello',
      createdAt: t,
      readReceipt: false,
    )));
    expect(tester.takeException(), isNull);
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    expect(find.byIcon(LucideIcons.checkCheck), findsNothing);
  });

  testWidgets('incoming message shows no receipt', (tester) async {
    await tester.pumpWidget(host(MessageBubble(
      mine: false,
      body: 'hi there',
      createdAt: t,
    )));
    expect(tester.takeException(), isNull);
    expect(find.byIcon(LucideIcons.check), findsNothing);
    expect(find.byIcon(LucideIcons.checkCheck), findsNothing);
  });
}
