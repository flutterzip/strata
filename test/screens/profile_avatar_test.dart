import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strata/config/app_theme.dart';
import 'package:strata/models/user_profile.dart';
import 'package:strata/providers/media_providers.dart';
import 'package:strata/screens/profile/avatar_crop_screen.dart';
import 'package:strata/screens/profile/profile_screen.dart';
import 'package:strata/screens/profile/widgets/avatar_sheet.dart';
import 'package:strata/services/media_ref.dart';
import 'package:strata/services/photo_picker.dart';
import 'package:strata/shared/widgets/avatar_circle.dart';

import '../support/fake_media_store.dart';

Uint8List photo(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(
          x, y, (x * 255 / width).round(), (y * 255 / height).round(), 90);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

/// A picker with a scripted answer, so the flow is testable without a
/// camera, a library or a permission dialog.
class ScriptedPicker implements PhotoPicker {
  ScriptedPicker({this.bytes, this.throws});

  final Uint8List? bytes;
  final Object? throws;
  final List<PhotoOrigin> asked = [];

  @override
  Future<Uint8List?> pick(PhotoOrigin origin) async {
    asked.add(origin);
    if (throws != null) throw throws!;
    return bytes;
  }
}

void seedProfile({String? avatar}) {
  SharedPreferences.setMockInitialValues({
    'strata.profile.v1': jsonEncode({
      'name': 'Olympicson',
      'email': 'hello@flutterzip.com',
      'handle': '@olympicson',
      'avatar': avatar,
      'preferredCurrency': 'USD',
      'themeMode': 'light',
      'showDemoHints': true,
    }),
    'strata.notifications.v1': jsonEncode(const <Map<String, Object>>[]),
  });
}

Widget profileHarness({
  required PhotoPicker picker,
  FakeMediaStore? store,
}) =>
    ProviderScope(
      overrides: [
        photoPickerProvider.overrideWithValue(picker),
        if (store != null) mediaStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const ProfileScreen(),
      ),
    );

void main() {
  late FakeMediaStore store;

  setUp(() {
    seedProfile();
    store = FakeMediaStore();
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('with no photo the avatar is the initials', (tester) async {
    phone(tester);
    await tester.pumpWidget(profileHarness(picker: ScriptedPicker()));
    await tester.pumpAndSettle();

    expect(find.byType(AvatarCircle), findsOneWidget);
    expect(find.text('O'), findsOneWidget);
  });

  testWidgets('tapping the avatar offers camera and library, but not remove',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(profileHarness(picker: ScriptedPicker()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AvatarKeys.avatar));
    await tester.pumpAndSettle();

    expect(find.byKey(AvatarKeys.camera), findsOneWidget);
    expect(find.byKey(AvatarKeys.choose), findsOneWidget);
    // Nothing to remove, so no button that would do nothing.
    expect(find.byKey(AvatarKeys.remove), findsNothing);
  });

  testWidgets('choosing a photo goes through the crop step, never straight in',
      (tester) async {
    phone(tester);
    final picker = ScriptedPicker(bytes: photo(1200, 800));
    await tester.pumpWidget(profileHarness(picker: picker, store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AvatarKeys.avatar));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AvatarKeys.choose));
    await tester.pumpAndSettle();

    expect(picker.asked, [PhotoOrigin.gallery]);
    expect(find.byType(AvatarCropScreen), findsOneWidget);
    expect(find.text('Position your photo'), findsOneWidget);
  });

  testWidgets('confirming the crop stores a file and shows the photo',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(profileHarness(
      picker: ScriptedPicker(bytes: photo(1200, 800)),
      store: store,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AvatarKeys.avatar));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AvatarKeys.choose));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AvatarCropScreen.confirmKey));
    await tester.pumpAndSettle();

    // Exactly one file, named by us, and the initials are gone.
    expect(store.files, hasLength(1));
    expect(store.files.keys.single, startsWith('media/avatar_me_'));
    expect(store.files.keys.single, endsWith('.jpg'));
    expect(find.text('O'), findsNothing);
  });

  testWidgets('the stored reference is relative, so it survives a reinstall',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(profileHarness(
      picker: ScriptedPicker(bytes: photo(900, 900)),
      store: store,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AvatarKeys.avatar));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AvatarKeys.choose));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AvatarCropScreen.confirmKey));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('strata.profile.v1')!)
        as Map<String, dynamic>;
    final avatar = saved['avatar'] as String;

    // Relative only. An absolute path is invalidated by the next reinstall,
    // because the app container is a new UUID every time.
    expect(avatar, startsWith('file:media/avatar_me_'));
    expect(avatar, isNot(contains('/Users')));
    expect(avatar, isNot(contains('Application Support')));
  });

  testWidgets('replacing a photo deletes the file it replaced', (tester) async {
    phone(tester);
    // Start from an avatar that is already stored.
    final first =
        await store.write(photo(600, 600), entity: 'avatar', id: 'me');
    seedProfile(avatar: first.encoded);

    await tester.pumpWidget(profileHarness(
      picker: ScriptedPicker(bytes: photo(800, 600)),
      store: store,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AvatarKeys.avatar));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AvatarKeys.choose));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AvatarCropScreen.confirmKey));
    await tester.pumpAndSettle();

    // Orphaned media is invisible and grows forever.
    expect(store.deleted, contains(first.path));
    expect(store.files, hasLength(1));
    expect(store.files.keys, isNot(contains(first.path)));
  });

  testWidgets('removing falls back to initials and deletes the file',
      (tester) async {
    phone(tester);
    final existing =
        await store.write(photo(600, 600), entity: 'avatar', id: 'me');
    seedProfile(avatar: existing.encoded);

    await tester
        .pumpWidget(profileHarness(picker: ScriptedPicker(), store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AvatarKeys.avatar));
    await tester.pumpAndSettle();
    expect(find.byKey(AvatarKeys.remove), findsOneWidget);

    await tester.tap(find.byKey(AvatarKeys.remove));
    await tester.pumpAndSettle();

    expect(find.text('O'), findsOneWidget);
    expect(store.deleted, contains(existing.path));
    expect(store.files, isEmpty);
  });

  testWidgets('a record pointing at a deleted file falls back cleanly',
      (tester) async {
    phone(tester);
    // The record outlives the file: restored backup, cleared storage.
    seedProfile(avatar: 'file:media/avatar_me_gone.jpg');

    await tester
        .pumpWidget(profileHarness(picker: ScriptedPicker(), store: store));
    await tester.pumpAndSettle();

    // Initials, not a broken-image box, and no thrown exception.
    expect(find.text('O'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refused camera permission is explained, with a way forward',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(profileHarness(
      picker:
          ScriptedPicker(throws: const PhotoAccessDenied(PhotoOrigin.camera)),
      store: store,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AvatarKeys.avatar));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AvatarKeys.camera));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('does not have permission to use the camera'),
      findsOneWidget,
    );
    // The other route is still there, and the sheet is still usable.
    expect(find.textContaining('choose an existing photo'), findsOneWidget);
    expect(find.byKey(AvatarKeys.choose), findsOneWidget);
  });

  testWidgets('backing out of the picker changes nothing', (tester) async {
    phone(tester);
    // A null answer means dismissed, which is not a failure.
    await tester.pumpWidget(profileHarness(
      picker: ScriptedPicker(bytes: null),
      store: store,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AvatarKeys.avatar));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AvatarKeys.choose));
    await tester.pumpAndSettle();

    expect(find.byType(AvatarCropScreen), findsNothing);
    expect(find.byKey(AvatarKeys.camera), findsOneWidget);
    expect(store.files, isEmpty);
  });

  testWidgets('cancelling the crop stores nothing', (tester) async {
    phone(tester);
    await tester.pumpWidget(profileHarness(
      picker: ScriptedPicker(bytes: photo(900, 600)),
      store: store,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AvatarKeys.avatar));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AvatarKeys.choose));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(AvatarCropScreen), findsNothing);
    expect(store.files, isEmpty);
  });

  testWidgets('a failed write rolls back to the old picture, with a message',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(profileHarness(
      picker: ScriptedPicker(bytes: photo(900, 600)),
      store: FakeMediaStore(failWrites: true),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AvatarKeys.avatar));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AvatarKeys.choose));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AvatarCropScreen.confirmKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not save that photo'), findsOneWidget);

    // The optimistic picture is gone; the profile is as it was.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('O'), findsOneWidget);
  });

  test('copyWith can clear the avatar, which null cannot express', () {
    const withPhoto = UserProfile(
      name: 'Olympicson',
      email: 'a@b.c',
      handle: '@olympicson',
      avatar: MediaRef(MediaSource.file, 'media/avatar_me_1.jpg'),
    );
    expect(withPhoto.copyWith(name: 'Olympicson O').avatar, isNotNull);
    expect(withPhoto.copyWith(clearAvatar: true).avatar, isNull);
  });
}
