import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../features/app_controller.dart';
import '../shared/format.dart';
import '../shared/widgets/common.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key, required this.app});
  final AppController app;

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final nickname = TextEditingController();
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  bool hide = true;
  bool nickArmed = false;

  @override
  void initState() {
    super.initState();
    nickname.text = widget.app.profile?.nickname ?? '';
  }

  @override
  void dispose() {
    nickname.dispose();
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final profile = app.profile;
    if (profile == null) return const SizedBox.shrink();
    final masked = profile.email != null
        ? maskEmail(profile.email!)
        : profile.phoneE164 != null
            ? maskPhone(profile.phoneE164!)
            : (profile.isGuest ? app.l10n.tr('maskedGuest') : app.l10n.tr('providerGoogle'));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(app.l10n.tr('my'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(controller: nickname, decoration: InputDecoration(labelText: app.l10n.tr('nickname'), errorText: app.fieldError)),
        const SizedBox(height: 8),
        FilledButton(
          style: nickArmed ? FilledButton.styleFrom(backgroundColor: TempColors.confirm) : null,
          onPressed: () async {
            if (!nickArmed) {
              setState(() => nickArmed = true);
              return;
            }
            await app.saveNickname(nickname.text, confirmed: true, stay: true);
            setState(() => nickArmed = false);
          },
          child: Text(nickArmed ? app.l10n.tr('saveConfirm') : app.l10n.tr('save')),
        ),
        const SizedBox(height: 16),
        Text(masked, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        if (profile.isGoogle)
          Text('${app.l10n.tr('loginMethod')}: ${app.l10n.tr('providerGoogle')}')
        else if (!profile.isGuest) ...[
          Text(app.l10n.tr('hiddenPassword'), style: const TextStyle(fontSize: 16, letterSpacing: 2)),
          const SizedBox(height: 8),
          TextField(
            controller: current,
            obscureText: hide,
            decoration: InputDecoration(
              labelText: app.l10n.tr('currentPassword'),
              suffixIcon: IconButton(
                tooltip: hide ? app.l10n.tr('showPassword') : app.l10n.tr('hidePassword'),
                onPressed: () => setState(() => hide = !hide),
                icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(controller: next, obscureText: hide, decoration: InputDecoration(labelText: app.l10n.tr('newPassword'), helperText: app.l10n.tr('passwordHelp'))),
          const SizedBox(height: 8),
          TextField(controller: confirm, obscureText: hide, decoration: InputDecoration(labelText: app.l10n.tr('passwordConfirm'))),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => app.changePassword(current.text, next.text, confirm.text), child: Text(app.l10n.tr('save'))),
        ],
        if (profile.isGoogle) ...[
          const SizedBox(height: 16),
          Text(app.l10n.tr('shelf'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          RadioListTile<String>(
            value: 'firebase',
            groupValue: profile.storageBackend,
            title: Text(app.l10n.tr('firebase')),
            onChanged: (value) => app.setShelf(value!, null),
          ),
          RadioListTile<String>(
            value: 'google_drive',
            groupValue: profile.storageBackend,
            title: Text(app.l10n.tr('drive')),
            onChanged: (value) => app.setShelf(value!, profile.driveMaxBytes ?? driveCaps.last),
          ),
          if (profile.storageBackend == 'google_drive') ...[
            Text(app.l10n.tr('driveNote')),
            const SizedBox(height: 8),
            DropdownButton<int>(
              isExpanded: true,
              value: driveCaps.contains(profile.driveMaxBytes) ? profile.driveMaxBytes : driveCaps.last,
              items: [
                for (final cap in driveCaps) DropdownMenuItem(value: cap, child: Text('${app.l10n.tr('driveCap')} ${driveCapLabel(cap)}')),
              ],
              onChanged: (value) {
                if (value != null) app.setShelf('google_drive', value);
              },
            ),
          ],
        ],
        if (profile.isGuest) ...[
          const SizedBox(height: 16),
          OutlinedButton(onPressed: () => app.go(Screen.signup), child: Text(app.l10n.tr('link'))),
        ],
        const SizedBox(height: 24),
        if (app.withdrawArmed) ...[
          Text(app.l10n.tr('withdrawBody')),
          const SizedBox(height: 8),
        ],
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: app.withdrawArmed ? TempColors.confirm : TempColors.danger),
          onPressed: app.withdraw,
          child: Text(app.withdrawArmed ? app.l10n.tr('withdrawConfirm') : app.l10n.tr('withdraw')),
        ),
        if (profile.admin) ...[
          const SizedBox(height: 16),
          OutlinedButton(onPressed: () => app.go(Screen.admin), child: Text(app.l10n.tr('stats'))),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            TextButton(onPressed: () => app.setLocale('ko'), child: Text(app.l10n.tr('korean'))),
            TextButton(onPressed: () => app.setLocale('en'), child: Text(app.l10n.tr('english'))),
          ],
        ),
      ],
    );
  }
}

class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.app});
  final AppController app;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.app.loadAdmin();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    if (app.profile?.admin != true) return Center(child: Text(app.l10n.tr('forbidden')));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(app.l10n.tr('stats'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final days in [7, 30, 90])
              ChoiceChip(
                label: Text(app.l10n.tr(days == 7 ? 'days7' : days == 30 ? 'days30' : 'days90')),
                selected: app.statDays == days,
                onSelected: (_) => app.setStatDays(days),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (app.statRows.isEmpty)
          Text(app.l10n.tr('noStats'))
        else ...[
          StatChart(bars: app.statBars, guestLabel: app.l10n.tr('legendGuest'), signedLabel: app.l10n.tr('legendSigned')),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(label: Text(app.l10n.tr('colDate'))),
                DataColumn(label: Text(app.l10n.tr('colEvent'))),
                DataColumn(label: Text(app.l10n.tr('colGuest'))),
                DataColumn(label: Text(app.l10n.tr('colSigned'))),
                DataColumn(label: Text(app.l10n.tr('colTotal'))),
              ],
              rows: [
                for (final row in app.statRows)
                  DataRow(cells: [
                    DataCell(Text(row.date)),
                    DataCell(Text(_event(app, row.event))),
                    DataCell(Text('${row.guest}')),
                    DataCell(Text('${row.signed}')),
                    DataCell(Text('${row.total}')),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => app.tools.saveFile('tempbox-stats.csv', Uint8List.fromList(utf8.encode(app.csv())), 'text/csv;charset=utf-8'),
            child: Text(app.l10n.tr('csv')),
          ),
        ],
        const SizedBox(height: 24),
        Text(app.l10n.tr('users'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        TextField(
          controller: search,
          decoration: InputDecoration(labelText: app.l10n.tr('search')),
          onSubmitted: app.searchUsers,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text(app.l10n.tr('colNick'))),
              DataColumn(label: Text(app.l10n.tr('colRole'))),
              DataColumn(label: Text(app.l10n.tr('colProvider'))),
              DataColumn(label: Text(app.l10n.tr('colContact'))),
              DataColumn(label: Text(app.l10n.tr('colCreated'))),
              DataColumn(label: Text(app.l10n.tr('colLast'))),
              DataColumn(label: Text(app.l10n.tr('colCount'))),
              const DataColumn(label: Text('')),
            ],
            rows: [
              for (final user in app.adminUsers)
                DataRow(cells: [
                  DataCell(Text(user.nickname)),
                  DataCell(Text(_role(app, user.role))),
                  DataCell(Text(_provider(app, user.provider))),
                  DataCell(Text(user.contact)),
                  DataCell(Text(seoulClock(user.createdAt))),
                  DataCell(Text(seoulClock(user.lastLoginAt))),
                  DataCell(Text('${user.itemCount}')),
                  DataCell(Wrap(
                    spacing: 4,
                    children: [
                      TextButton(onPressed: () => app.grant(user, user.role != 'admin'), child: Text(user.role == 'admin' ? app.l10n.tr('revoke') : app.l10n.tr('grant'))),
                      TextButton(onPressed: () => app.disable(user, !user.disabled), child: Text(user.disabled ? app.l10n.tr('enable') : app.l10n.tr('disable'))),
                      if (user.provider == 'anonymous')
                        TextButton(onPressed: () => app.armPurge(user), child: Text(app.l10n.tr('purge'))),
                    ],
                  )),
                ]),
            ],
          ),
        ),
        if (app.purgeUid != null) ...[
          const SizedBox(height: 8),
          Text(app.l10n.tr('purgeBody', {'count': '${app.purgeCount ?? 0}'})),
          FilledButton(onPressed: app.confirmPurge, child: Text(app.l10n.tr('purgeConfirm'))),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: app.runExpire, child: Text(app.l10n.tr('runExpire'))),
        const SizedBox(height: 24),
        Text(app.l10n.tr('audit'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        for (final row in app.auditRows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${row.action} · ${row.changedFields.join(', ')} · ${seoulClock(row.at)}', style: const TextStyle(fontSize: 16)),
          ),
      ],
    );
  }

  String _event(AppController app, String event) {
    switch (event) {
      case 'created':
        return app.l10n.tr('evCreated');
      case 'claimed':
        return app.l10n.tr('evClaimed');
      case 'deleted':
        return app.l10n.tr('evDeleted');
      case 'expired':
        return app.l10n.tr('evExpired');
      default:
        return app.l10n.tr('evRejected');
    }
  }

  String _role(AppController app, String role) {
    if (role == 'admin') return app.l10n.tr('roleAdmin');
    if (role == 'guest') return app.l10n.tr('roleGuest');
    return app.l10n.tr('roleUser');
  }

  String _provider(AppController app, String provider) {
    switch (provider) {
      case 'google':
        return app.l10n.tr('providerGoogle');
      case 'phone':
        return app.l10n.tr('providerPhone');
      case 'anonymous':
        return app.l10n.tr('providerGuest');
      default:
        return app.l10n.tr('providerEmail');
    }
  }
}
