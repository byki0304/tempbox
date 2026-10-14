import 'package:flutter/material.dart';

import '../features/app_controller.dart';
import '../shared/widgets/common.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 96),
                children: [
                  const Center(child: BrandImage(path: '/brand/characters/box-keeper.png', height: 180)),
                  const SizedBox(height: 16),
                  const TempBoxMark(),
                  const SizedBox(height: 16),
                  Text(app.l10n.tr('lead'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.45)),
                  const SizedBox(height: 28),
                  FilledButton(onPressed: () => app.go(Screen.login), child: Text(app.l10n.tr('login'))),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: () => app.go(Screen.signup), child: Text(app.l10n.tr('signup'))),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: app.openGuest, child: Text(app.l10n.tr('guestOpen'))),
                  const SizedBox(height: 20),
                  LanguageChoices(app: app, alignment: WrapAlignment.center),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FilledButton(onPressed: () => app.go(Screen.help), child: Text(app.l10n.tr('help'))),
          ),
        ],
      ),
    );
  }
}
