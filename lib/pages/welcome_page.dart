import 'package:flutter/material.dart';

import '../app/theme.dart';
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
                  const SizedBox(height: 12),
                  Text(app.l10n.tr('app'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(app.l10n.tr('lead'), textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  FilledButton(onPressed: () => app.go(Screen.login), child: Text(app.l10n.tr('login'))),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: () => app.go(Screen.signup), child: Text(app.l10n.tr('signup'))),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: app.openGuest, child: Text(app.l10n.tr('guestOpen'))),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton(onPressed: () => app.setLocale('ko'), child: Text(app.l10n.tr('korean'))),
                      TextButton(onPressed: () => app.setLocale('en'), child: Text(app.l10n.tr('english'))),
                    ],
                  ),
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
