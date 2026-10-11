import 'package:flutter/material.dart';

import '../features/app_controller.dart';
import '../pages/account_page.dart';
import '../pages/auth_page.dart';
import '../pages/home_page.dart';
import '../pages/welcome_page.dart';
import '../shared/widgets/common.dart';
import 'theme.dart';

class TempBoxApp extends StatefulWidget {
  const TempBoxApp({super.key});

  @override
  State<TempBoxApp> createState() => _TempBoxAppState();
}

class _TempBoxAppState extends State<TempBoxApp> {
  final app = AppController();
  final keys = FocusNode();

  @override
  void initState() {
    super.initState();
    app.addListener(() {
      if (mounted) setState(() {});
    });
    app.boot();
  }

  @override
  void dispose() {
    keys.dispose();
    app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page();
    return MaterialApp(
      title: app.l10n.tr('app'),
      debugShowCheckedModeBanner: false,
      theme: TempTheme.light(),
      locale: Locale(app.locale),
      home: Listener(
        onPointerDown: (_) => app.touch(),
        child: KeyboardListener(
          focusNode: keys,
          onKeyEvent: (_) => app.touch(),
          child: AnimatedSwitcher(
            duration: motion(context),
            child: KeyedSubtree(key: ValueKey(app.screen), child: page),
          ),
        ),
      ),
    );
  }

  Widget _page() {
    switch (app.screen) {
      case Screen.boot:
        return const Scaffold(body: Center(child: SealMark()));
      case Screen.welcome:
        return WelcomePage(app: app);
      case Screen.login:
        return AuthPage(app: app, signup: false);
      case Screen.signup:
        return AuthPage(app: app, signup: true);
      case Screen.nickname:
        return NicknamePage(app: app);
      case Screen.guest:
        return GuestPage(app: app);
      case Screen.help:
        if (app.profile == null) return HelpPage(app: app);
        return AppShell(app: app, child: HelpPage(app: app, inShell: true));
      case Screen.me:
        return AppShell(app: app, child: MyPage(app: app));
      case Screen.admin:
        return AppShell(app: app, child: AdminPage(app: app));
      case Screen.box:
        return AppShell(app: app, child: HomePage(app: app));
    }
  }
}
