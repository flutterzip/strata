import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strata/config/app_theme.dart';
import 'package:strata/providers/notification_providers.dart';
import 'package:strata/screens/profile/widgets/notifications_sheet.dart';
import 'package:strata/shared/widgets/status_view.dart';

import '../support/harness.dart';

/// Storage is seeded directly rather than loaded from the bundle.
///
/// Reading the asset makes every test after the first in a file hang: the
/// second load never completes, the sheet sits on its spinner, and
/// `pumpAndSettle` times out. Pre-seeding keeps these deterministic and
/// keeps them about the tile's behaviour, which is what they test. Parsing
/// the real seed file is covered in the services tests.
const _long =
    'Your account was opened on a device we have not seen before. If this '
    'was you there is nothing to do. If it was not, change your password '
    'and sign out every other device from Profile, then contact support so '
    'we can freeze the card while we look into it.';

Map<String, Object> _seed({int count = 10, int unread = 4}) {
  final rows = [
    for (var i = 0; i < count; i++)
      {
        'id': 'n_${i.toString().padLeft(2, '0')}',
        'kind': i.isEven ? 'payment' : 'system',
        'title': i == 1 ? 'New sign-in from Lagos' : 'Notification $i',
        'body': i == 1 ? _long : 'Body for notification $i.',
        'sentAt': '2026-11-0${(i % 7) + 1}T09:00:00Z',
        'read': i >= unread,
      },
  ];
  return {'strata.notifications.v1': jsonEncode(rows)};
}

Widget sheetHarness() => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(child: NotificationsSheet()),
        ),
      ),
    );

/// Brings a row on screen before touching it.
///
/// Ten notifications are taller than a phone, so the row a test names is
/// usually below the fold. `tester.tap` on an off-screen widget warns and
/// then does nothing, which reads as the handler being broken.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(_seed()));

  testWidgets('renders ten notifications without overflowing', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sheetHarness());
    await tester.pumpAndSettle();

    expect(find.textContaining('Notification 0'), findsOneWidget);
    expect(find.textContaining('Notification 9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the header counts what is unread', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sheetHarness());
    await tester.pumpAndSettle();

    expect(find.textContaining('4 unread'), findsOneWidget);
  });

  testWidgets('tapping one opens it, and reading it is a consequence',
      (tester) async {
    // The obvious gesture does the most useful thing. Marking something
    // read is never the point of a tap; reading it is.
    usePhoneSurface(tester);
    await tester.pumpWidget(sheetHarness());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
        tester.element(find.byType(NotificationsSheet)));
    expect(container.read(unreadCountProvider), 4);

    await reveal(tester, find.textContaining('Notification 0'));
    await tester.tap(find.textContaining('Notification 0'));
    await tester.pumpAndSettle();

    expect(container.read(unreadCountProvider), 3);
    final opened = container
        .read(notificationsProvider)
        .value!
        .firstWhere((n) => n.id == 'n_00');
    expect(opened.read, isTrue);
  });

  testWidgets('putting one back to unread is a separate, explicit action',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sheetHarness());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
        tester.element(find.byType(NotificationsSheet)));

    // Open it first; the control only exists once it is open.
    await reveal(tester, find.textContaining('Notification 0'));
    await tester.tap(find.textContaining('Notification 0'));
    await tester.pumpAndSettle();
    expect(container.read(unreadCountProvider), 3);

    await reveal(tester, find.text('Mark unread'));
    await tester.tap(find.text('Mark unread'));
    await tester.pumpAndSettle();

    expect(container.read(unreadCountProvider), 4);
  });

  testWidgets('a collapsed body clamps to two lines', (tester) async {
    // A long security message must not push every other row off the sheet.
    usePhoneSurface(tester);
    await tester.pumpWidget(sheetHarness());
    await tester.pumpAndSettle();

    final body = tester.widget<Text>(find.text(_long));
    expect(body.maxLines, 2);
    expect(body.overflow, TextOverflow.ellipsis);

    await reveal(tester, find.text(_long));
    await tester.tap(find.text(_long));
    await tester.pumpAndSettle();

    // Open, it is shown in full.
    expect(tester.widget<Text>(find.text(_long)).maxLines, isNull);
  });

  testWidgets('swiping deletes one', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sheetHarness());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
        tester.element(find.byType(NotificationsSheet)));
    expect(container.read(notificationsProvider).value, hasLength(10));

    await reveal(tester, find.textContaining('Notification 0'));
    await tester.drag(
        find.textContaining('Notification 0'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(container.read(notificationsProvider).value, hasLength(9));
    expect(find.textContaining('Notification 0'), findsNothing);
  });

  testWidgets('mark all as read clears the count and the button',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sheetHarness());
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Mark all as read'));
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
        tester.element(find.byType(NotificationsSheet)));
    expect(container.read(unreadCountProvider), 0);
    // Nothing left to do, so the control goes rather than sitting inert.
    expect(find.text('Mark all as read'), findsNothing);
  });

  testWidgets('with nothing unread the header says so', (tester) async {
    SharedPreferences.setMockInitialValues(_seed(count: 3, unread: 0));
    usePhoneSurface(tester);
    await tester.pumpWidget(sheetHarness());
    await tester.pumpAndSettle();

    expect(find.textContaining('unread'), findsNothing);
  });

  testWidgets('an empty list says so rather than showing a blank sheet',
      (tester) async {
    SharedPreferences.setMockInitialValues(_seed(count: 0));
    usePhoneSurface(tester);
    await tester.pumpWidget(sheetHarness());
    await tester.pumpAndSettle();

    expect(find.byType(StatusView), findsOneWidget);
  });
}
