import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../features/app_controller.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.app, required this.signup});
  final AppController app;
  final bool signup;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final phone = TextEditingController();
  final country = TextEditingController(text: '+82');
  String kind = 'email';
  bool hide = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirm.dispose();
    phone.dispose();
    country.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final l10n = app.l10n;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(widget.signup ? l10n.tr('signup') : l10n.tr('login'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              if (!widget.signup) ...[
                FilledButton(onPressed: app.google, child: Text(l10n.tr('google'))),
                const SizedBox(height: 12),
              ],
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'email', label: Text(l10n.tr('email'))),
                  ButtonSegment(value: 'phone', label: Text(l10n.tr('phone'))),
                ],
                selected: {widget.signup ? kind : kind},
                onSelectionChanged: (value) => setState(() => kind = value.first),
              ),
              const SizedBox(height: 16),
              if (kind == 'email')
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: l10n.tr('email'), hintText: 'name@example.com', errorText: app.fieldError),
                )
              else ...[
                TextField(controller: country, decoration: InputDecoration(labelText: l10n.tr('country'))),
                const SizedBox(height: 12),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: l10n.tr('phone'), hintText: '10-1234-5678', errorText: app.fieldError),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: hide,
                decoration: InputDecoration(
                  labelText: l10n.tr('password'),
                  helperText: l10n.tr('passwordHelp'),
                  suffixIcon: IconButton(
                    tooltip: hide ? l10n.tr('showPassword') : l10n.tr('hidePassword'),
                    onPressed: () => setState(() => hide = !hide),
                    icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
              ),
              if (widget.signup) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: confirm,
                  obscureText: hide,
                  decoration: InputDecoration(labelText: l10n.tr('passwordConfirm')),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: app.busy
                    ? null
                    : () => app.submitAuth(
                          signup: widget.signup,
                          kind: kind,
                          email: email.text,
                          password: password.text,
                          confirm: confirm.text,
                          country: country.text,
                          national: phone.text,
                        ),
                child: Text(widget.signup ? l10n.tr('signup') : l10n.tr('login')),
              ),
              if (!widget.signup) ...[
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => app.go(Screen.signup), child: Text(l10n.tr('signup'))),
              ],
              const SizedBox(height: 12),
              TextButton(onPressed: () => app.go(Screen.welcome), child: Text(l10n.tr('cancel'))),
            ],
          ),
        ),
      ),
    );
  }
}

class NicknamePage extends StatefulWidget {
  const NicknamePage({super.key, required this.app});
  final AppController app;

  @override
  State<NicknamePage> createState() => _NicknamePageState();
}

class _NicknamePageState extends State<NicknamePage> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(app.l10n.tr('nickname'), style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: app.l10n.tr('nickname'),
                    helperText: app.l10n.tr('nicknameHelp'),
                    errorText: app.fieldError,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: app.busy ? null : () => app.saveNickname(controller.text),
                  child: Text(app.l10n.tr('save')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GuestPage extends StatefulWidget {
  const GuestPage({super.key, required this.app});
  final AppController app;

  @override
  State<GuestPage> createState() => _GuestPageState();
}

class _GuestPageState extends State<GuestPage> {
  Future<void> _askCode() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CodeEntryDialog(app: widget.app),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(app.l10n.tr('guestHint'), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(app.l10n.tr('lostCode'), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(onPressed: app.busy ? null : app.createFreshBox, child: Text(app.l10n.tr('newBox'))),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: app.busy ? null : _askCode, child: Text(app.l10n.tr('enterCode'))),
                if (app.fieldError != null) ...[
                  const SizedBox(height: 12),
                  Text(app.fieldError!, textAlign: TextAlign.center, style: const TextStyle(color: TempColors.danger)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeEntryDialog extends StatefulWidget {
  const _CodeEntryDialog({required this.app});
  final AppController app;

  @override
  State<_CodeEntryDialog> createState() => _CodeEntryDialogState();
}

class _CodeEntryDialogState extends State<_CodeEntryDialog> {
  final code = TextEditingController();

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.app.redeem(code.text);
    if (!mounted) return;
    if (widget.app.screen == Screen.box) {
      Navigator.pop(context);
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return AlertDialog(
      title: Text(app.l10n.tr('enterCode')),
      content: TextField(
        controller: code,
        autofocus: true,
        decoration: InputDecoration(
          labelText: app.l10n.tr('code'),
          hintText: app.l10n.tr('codeHint'),
          errorText: app.fieldError,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(app.l10n.tr('cancel'))),
        FilledButton(onPressed: app.busy ? null : _submit, child: Text(app.l10n.tr('join'))),
      ],
    );
  }
}
