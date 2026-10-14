import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempbox/app/theme.dart';
import 'package:tempbox/entities/models.dart';
import 'package:tempbox/features/app_controller.dart';
import 'package:tempbox/pages/auth_page.dart';
import 'package:tempbox/pages/home_page.dart';
import 'package:tempbox/shared/web/web_tools_api.dart';
import 'package:tempbox/shared/widgets/common.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('portrait and landscape use separate shells', (tester) async {
    final app = _app();
    await _pump(tester, app, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(_hintWidth(tester), greaterThan(280));
    expect(find.text('Google Cloud'), findsOneWidget);
    expect(find.text('파일 하나 상한'), findsOneWidget);
    expect(find.text('100MB'), findsOneWidget);
    expect(find.text('TempBox'), findsWidgets);

    await _pump(tester, app, const Size(844, 390));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('상자'), findsWidgets);
    expect(_hintWidth(tester), greaterThan(360));
    expect(tester.takeException(), isNull);

    await _pump(tester, app, const Size(740, 340));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(_hintWidth(tester), greaterThan(280));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a guest box shows the file size choices', (tester) async {
    final app = _app();
    app.profile = Profile(
      uid: 'guest',
      provider: 'anonymous',
      storageBackend: 'google_cloud',
      disabled: false,
      admin: false,
      createdAt: 0,
      lastLoginAt: 0,
      nickname: '손님',
    );
    await _pump(tester, app, const Size(390, 844));
    expect(find.text('파일 하나 상한'), findsOneWidget);
    expect(find.text('20MB'), findsOneWidget);
    expect(find.byType(DropdownButton<int>), findsOneWidget);
    expect(find.text('TempBox'), findsWidgets);
    expect(tester.takeException(), isNull);

    await _pump(tester, app, const Size(844, 390));
    expect(find.text('파일 하나 상한'), findsOneWidget);
    expect(find.byType(DropdownButton<int>), findsOneWidget);
    expect(find.text('TempBox'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest entry screen hides the file size choices', (tester) async {
    final app = _app();
    app.profile = Profile(
      uid: 'guest',
      provider: 'anonymous',
      storageBackend: 'google_cloud',
      disabled: false,
      admin: false,
      createdAt: 0,
      lastLoginAt: 0,
      nickname: '손님',
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: TempTheme.light(), home: GuestPage(app: app)),
    );
    await tester.pump();
    expect(find.text('파일 하나 상한'), findsNothing);
    expect(find.text('Google Cloud'), findsNothing);
    expect(find.byType(DropdownButton<int>), findsNothing);
    expect(find.text('새 상자 열기'), findsOneWidget);
    expect(find.text('To Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nickname and guest entry return home from the top right', (tester) async {
    for (final size in const [Size(390, 844), Size(844, 390), Size(1280, 800)]) {
      final nickname = _guestApp();
      await _pumpPage(tester, size, NicknamePage(app: nickname));
      _expectTopRight(tester, find.text('To Home'), size);
      await tester.tap(find.text('To Home'));
      await tester.pump();
      expect(nickname.screen, Screen.welcome);
      expect(nickname.profile, isNull);

      final guest = _guestApp();
      await _pumpPage(tester, size, GuestPage(app: guest));
      _expectTopRight(tester, find.text('To Home'), size);
      expect(find.text('새 상자 열기'), findsOneWidget);
      await tester.tap(find.text('To Home'));
      await tester.pump();
      expect(guest.screen, Screen.welcome);
      expect(guest.profile, isNull);
    }
  });
}

void _expectTopRight(WidgetTester tester, Finder finder, Size size) {
  expect(finder, findsOneWidget);
  final box = tester.getRect(finder);
  expect(box.right, greaterThan(size.width * 0.75));
  expect(box.top, lessThan(72));
}

Future<void> _pumpPage(WidgetTester tester, Size size, Widget page) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: TempTheme.light(), home: page));
  await tester.pump();
}

AppController _guestApp() {
  final app = AppController()..tools = _Tools();
  app.screen = Screen.guest;
  app.profile = Profile(
    uid: 'guest',
    provider: 'anonymous',
    storageBackend: 'google_cloud',
    disabled: false,
    admin: false,
    createdAt: 0,
    lastLoginAt: 0,
    nickname: '손님',
  );
  return app;
}

AppController _app() {
  final app = AppController()..tools = _Tools();
  app.screen = Screen.box;
  app.pairingCode = 'AB12-CD34';
  app.profile = Profile(
    uid: 'user',
    provider: 'google',
    storageBackend: 'google_cloud',
    disabled: false,
    admin: false,
    createdAt: 0,
    lastLoginAt: 0,
    nickname: 'box',
    cloudMaxBytes: 100 * 1024 * 1024,
  );
  final now = DateTime.now().millisecondsSinceEpoch;
  app.items = [
    BoxItem(
      itemId: 'a',
      boxId: 'b',
      kind: 'message',
      status: 'available',
      createdAt: now - 60000,
      expiresAt: now + 3600000,
      text: '보낸 메시지',
      originDeviceId: 'here',
    ),
    BoxItem(
      itemId: 'c',
      boxId: 'b',
      kind: 'file',
      status: 'available',
      createdAt: now,
      expiresAt: now + 3600000,
      fileName: 'notes.pdf',
      bytes: 12000,
      originDeviceId: 'other',
    ),
  ];
  return app;
}

Future<void> _pump(WidgetTester tester, AppController app, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: TempTheme.light(),
      home: AppShell(app: app, child: HomePage(app: app)),
    ),
  );
  await tester.pump();
}

double _hintWidth(WidgetTester tester) {
  final hint = find.text('다른 기기에서는 같은 계정으로 열면 이 상자가 보입니다.');
  expect(hint, findsOneWidget);
  return tester.renderObject<RenderParagraph>(hint).size.width;
}

class _Tools implements WebTools {
  @override
  void bindDrop(void Function(bool hovering) hover, void Function(List<PickedFile> files) onFiles) {}

  @override
  void bindPaste(void Function(List<PickedFile> files) onFiles) {}

  @override
  String currentPath() => '/';

  @override
  void listenPop(void Function(String path) onPop) {}

  @override
  bool get online => true;

  @override
  Future<List<PickedFile>> pick({bool camera = false}) async => const [];

  @override
  String? read(String key) => null;

  @override
  void saveFile(String filename, Uint8List bytes, String mime) {}

  @override
  void setPath(String path) {}

  @override
  void unbindDrop() {}

  @override
  void unbindPaste() {}

  @override
  Future<Uint8List?> webpThumb(Uint8List bytes) async => null;

  @override
  void write(String key, String? value) {}
}
