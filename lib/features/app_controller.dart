import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app/config.dart';
import '../app/i18n.dart';
import '../entities/models.dart';
import '../shared/api/api_client.dart';
import '../shared/api/firebase_gate.dart' if (dart.library.html) '../shared/api/firebase_gate_web.dart';
import '../shared/api/local_api.dart';
import '../shared/format.dart';
import '../shared/web/web_tools.dart';
import '../shared/web/web_tools_api.dart';

enum Screen { boot, welcome, login, signup, nickname, guest, box, help, me, admin }

class PendingSend {
  PendingSend(this.id, this.label);
  final String id;
  final String label;
  String? error;
}

class AppController extends ChangeNotifier {
  AppController();

  late WebTools tools;
  BoxApi? api;
  L10n l10n = L10n(L10n.ko);
  String locale = L10n.ko;
  Screen screen = Screen.boot;
  Profile? profile;
  BoxRecord? box;
  List<BoxItem> items = [];
  List<PendingSend> pending = [];
  String? live;
  String? fieldError;
  bool offline = false;
  bool busy = false;
  bool dragging = false;
  String draft = '';
  List<PickedFile> files = [];
  String? pairingCode;
  String? armedDelete;
  bool withdrawArmed = false;
  bool nicknameArmed = false;
  final usedNames = <String>{};
  List<StatRow> statRows = [];
  List<StatBar> statBars = [];
  int statDays = 7;
  List<AdminUser> adminUsers = [];
  List<AuditRow> auditRows = [];
  String? purgeUid;
  int? purgeCount;
  Timer? _timer;
  DateTime lastActivity = DateTime.now();

  bool get signedIn => profile != null;

  Future<void> boot() async {
    tools = createWebTools();
    locale = tools.read('tempbox.locale') == 'en' ? 'en' : 'ko';
    l10n = L10n(locale);
    pairingCode = tools.read('tempbox.code');
    draft = tools.read('tempbox.draft') ?? '';
    tools.listenPop((path) {
      if (screen == Screen.boot) return;
      _applyPath(path, sync: false);
    });
    if (AppConfig.firebaseReady) {
      api = await openFirebaseApi();
    } else if (AppConfig.useLocalApi) {
      api = LocalApi(AppConfig.apiOrigin, tools: tools);
    }
    await ping();
    if (api != null && (api is! LocalApi || (api as LocalApi).token != null)) {
      try {
        final home = await api!.listItems();
        profile = home.profile;
        box = home.box;
        items = home.items;
      } on ApiException {
        profile = null;
      } catch (_) {
        offline = true;
      }
    }
    _applyPath(tools.currentPath(), sync: false);
    if (screen == Screen.boot) screen = Screen.welcome;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _tick());
    notifyListeners();
  }

  Future<void> _tick() async {
    if (profile != null && DateTime.now().difference(lastActivity) > const Duration(minutes: 30)) {
      await logout(idle: true);
      return;
    }
    await ping();
    if (screen == Screen.box && api != null && !offline && profile != null) {
      try {
        final home = await api!.listItems();
        items = home.items;
        box = home.box;
        profile = home.profile;
        notifyListeners();
      } catch (_) {}
    }
  }

  void touch() {
    lastActivity = DateTime.now();
  }

  Future<void> ping() async {
    final was = offline;
    if (api == null) {
      offline = true;
    } else if (!tools.online) {
      offline = true;
    } else {
      try {
        await api!.health();
        offline = false;
      } catch (_) {
        offline = true;
      }
    }
    if (was != offline) notifyListeners();
  }

  void setLocale(String code) {
    locale = code == 'en' ? 'en' : 'ko';
    l10n = L10n(locale);
    tools.write('tempbox.locale', locale);
    notifyListeners();
  }

  void say(String message) {
    live = message;
    notifyListeners();
  }

  String explain(Object error) {
    final code = error is ApiException ? error.code : 'invalid';
    switch (code) {
      case 'quota_project':
      case 'quota_user':
        return l10n.tr('quota');
      case 'type_rejected':
        return l10n.tr('typeRejected');
      case 'empty_message':
        return l10n.tr('emptySend');
      case 'locked':
        return l10n.tr('locked');
      case 'already_taken':
        return l10n.tr('taken');
      case 'expired':
        return l10n.tr('expired');
      case 'too_large':
        return l10n.tr('tooLarge');
      case 'plan_capacity':
        return l10n.tr('plan');
      case 'invalid_login':
        return l10n.tr('emailAuth');
      case 'invalid_phone_login':
        return l10n.tr('phoneAuth');
      case 'invalid_email':
        return l10n.tr('emailInvalid');
      case 'invalid_phone':
        return l10n.tr('phoneInvalid');
      case 'invalid_password':
        return l10n.tr('passwordCharset');
      case 'invalid_code':
        return l10n.tr('badCode');
      case 'rate_limited':
        return l10n.tr('rate');
      case 'exists':
        return l10n.tr('exists');
      case 'self_admin':
        return l10n.tr('selfAdmin');
      case 'last_admin':
        return l10n.tr('lastAdmin');
      case 'unauthenticated':
        return l10n.tr('idle');
      default:
        return l10n.tr('forbidden');
    }
  }

  void go(Screen next) {
    _applyPath(_path(next), sync: true);
  }

  String _path(Screen value) {
    switch (value) {
      case Screen.login:
        return '/login';
      case Screen.signup:
        return '/signup';
      case Screen.nickname:
        return '/nickname';
      case Screen.guest:
        return '/guest';
      case Screen.help:
        return '/help';
      case Screen.me:
        return '/me';
      case Screen.admin:
        return '/admin';
      case Screen.box:
        return '/box';
      case Screen.welcome:
      case Screen.boot:
        return '/';
    }
  }

  void _applyPath(String path, {required bool sync}) {
    final normalized = path == '' ? '/' : path;
    if (profile == null) {
      if (normalized == '/help') {
        screen = Screen.help;
      } else if (normalized == '/login') {
        screen = Screen.login;
      } else if (normalized == '/signup') {
        screen = Screen.signup;
      } else {
        screen = Screen.welcome;
      }
    } else if (profile!.nickname == null || profile!.nickname!.isEmpty) {
      screen = Screen.nickname;
    } else if (box == null && profile!.isGuest && normalized != '/help' && normalized != '/me') {
      screen = normalized == '/guest' || normalized == '/box' || normalized == '/' ? Screen.guest : Screen.guest;
    } else {
      switch (normalized) {
        case '/help':
          screen = Screen.help;
        case '/me':
          screen = Screen.me;
        case '/admin':
          screen = profile!.admin ? Screen.admin : Screen.box;
        case '/login':
        case '/signup':
        case '/':
          screen = Screen.box;
        default:
          screen = Screen.box;
      }
    }
    if (sync) tools.setPath(_path(screen));
    notifyListeners();
  }

  Future<void> refresh() async {
    if (api == null || profile == null) return;
    final home = await api!.listItems();
    profile = home.profile;
    box = home.box;
    items = home.items;
    notifyListeners();
  }

  Future<void> _enter(AuthResult result) async {
    profile = result.profile;
    fieldError = null;
    if (profile!.nickname == null || profile!.nickname!.isEmpty) {
      nicknameArmed = false;
      go(Screen.nickname);
      return;
    }
    await _openExistingOrGuest();
  }

  Future<void> _openExistingOrGuest() async {
    final home = await api!.listItems();
    profile = home.profile;
    box = home.box;
    items = home.items;
    if (box == null && profile!.isGuest) {
      go(Screen.guest);
      return;
    }
    if (box == null) {
      final opened = await api!.createBox();
      box = opened.box;
      _rememberCode(opened);
      await refresh();
    }
    if (!profile!.isGuest && tools.read('tempbox.hint') != '1') {
      tools.write('tempbox.hint', '1');
      say(l10n.tr('accountHint'));
    }
    go(Screen.box);
  }

  void _rememberCode(BoxOpen opened) {
    if (opened.pairingCodeDisplay != null) {
      pairingCode = opened.pairingCodeDisplay;
      tools.write('tempbox.code', pairingCode);
    }
  }

  Future<void> submitAuth({
    required bool signup,
    required String kind,
    String? email,
    String? password,
    String? confirm,
    String? country,
    String? national,
  }) async {
    fieldError = null;
    if (kind != 'google' && kind == 'email' && !validEmail(email ?? '')) {
      fieldError = l10n.tr('emailInvalid');
      notifyListeners();
      return;
    }
    if (kind != 'google' && kind == 'phone' && normalizePhone(country ?? '+82', national ?? '') == null) {
      fieldError = l10n.tr('phoneInvalid');
      notifyListeners();
      return;
    }
    if (kind != 'google' && !validPassword(password ?? '')) {
      fieldError = l10n.tr('passwordCharset');
      notifyListeners();
      return;
    }
    if (signup && password != confirm) {
      fieldError = l10n.tr('passwordMismatch');
      notifyListeners();
      return;
    }
    if (api == null) {
      say(l10n.tr('setup'));
      return;
    }
    if (offline) {
      say(l10n.tr('offline'));
      return;
    }
    busy = true;
    notifyListeners();
    try {
      final linking = profile?.isGuest == true && signup;
      final AuthResult result;
      if (linking) {
        result = await api!.link(kind: kind, email: email, password: password, country: country, national: national);
      } else if (signup) {
        result = await api!.signup(kind: kind, email: email, password: password, country: country, national: national);
      } else if (kind == 'google') {
        result = await api!.google();
      } else {
        result = await api!.login(kind: kind, email: email, password: password, country: country, national: national);
      }
      await _enter(result);
    } catch (error) {
      fieldError = explain(error);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> google() => submitAuth(signup: false, kind: 'google');

  Future<void> openGuest() async {
    if (api == null) {
      say(l10n.tr('setup'));
      return;
    }
    if (offline) {
      say(l10n.tr('offline'));
      return;
    }
    busy = true;
    notifyListeners();
    try {
      final result = await api!.guest();
      await _enter(result);
    } catch (error) {
      say(explain(error));
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> saveNickname(String value, {bool? confirmed, bool stay = false}) async {
    final confirm = confirmed ?? nicknameArmed;
    if (!confirm) {
      if (!validNickname(value.trim())) {
        fieldError = l10n.tr('nicknameInvalid');
        notifyListeners();
        return;
      }
      nicknameArmed = true;
      fieldError = null;
      notifyListeners();
      return;
    }
    if (api == null || offline) {
      say(l10n.tr('offline'));
      return;
    }
    busy = true;
    notifyListeners();
    try {
      profile = await api!.setNickname(value.trim(), confirm: true);
      nicknameArmed = false;
      fieldError = null;
      if (stay) {
        notifyListeners();
        return;
      }
      await _openExistingOrGuest();
    } catch (error) {
      fieldError = explain(error);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> createFreshBox() async {
    if (api == null || offline) {
      say(l10n.tr('offline'));
      return;
    }
    final opened = await api!.createBox(fresh: true);
    box = opened.box;
    _rememberCode(opened);
    await refresh();
    go(Screen.box);
  }

  Future<void> redeem(String code) async {
    if (api == null || offline) {
      say(l10n.tr('offline'));
      return;
    }
    busy = true;
    notifyListeners();
    try {
      final opened = await api!.redeem(code);
      box = opened.box;
      pairingCode = code.toUpperCase();
      await refresh();
      go(Screen.box);
      fieldError = null;
    } catch (error) {
      fieldError = explain(error);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void setDraft(String value) {
    draft = value;
    tools.write('tempbox.draft', value);
    notifyListeners();
  }

  Future<void> addFiles(List<PickedFile> incoming, {bool camera = false}) async {
    if (camera) {
      final picked = await tools.pick(camera: true);
      incoming = picked;
    }
    if (files.length + incoming.length > 10) {
      say(l10n.tr('fileLimit'));
    }
    files = [...files, ...incoming].take(10).toList();
    notifyListeners();
  }

  void removeFile(int index) {
    files = [...files]..removeAt(index);
    notifyListeners();
  }

  String _requestId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> send() async {
    touch();
    fieldError = null;
    if (offline || api == null) {
      say(l10n.tr('offline'));
      return;
    }
    if (profile?.disabled == true) {
      say(l10n.tr('disabled'));
      return;
    }
    final text = draft;
    final batch = files.take(10).toList();
    if (batch.isEmpty && meaningfulLength(text) < 1) {
      fieldError = l10n.tr('emptySend');
      notifyListeners();
      return;
    }
    final cards = <PendingSend>[
      if (batch.isEmpty) PendingSend(_requestId(), l10n.tr('putting')),
      for (final file in batch) PendingSend(_requestId(), file.name),
    ];
    pending = [...pending, ...cards];
    notifyListeners();
    var anyOk = false;
    if (batch.isEmpty) {
      try {
        await api!.createMessage(text, cards.first.id);
        pending = pending.where((card) => card.id != cards.first.id).toList();
        anyOk = true;
      } catch (error) {
        cards.first.error = explain(error);
      }
    } else {
      for (var i = 0; i < batch.length; i++) {
        final file = batch[i];
        final card = cards[i];
        try {
          final thumb = file.mime.startsWith('image/') ? await tools.webpThumb(Uint8List.fromList(file.bytes)) : null;
          final ticket = await api!.beginFile(
            fileName: file.name,
            text: i == 0 && meaningfulLength(text) > 0 ? text : null,
            declaredBytes: file.bytes.length,
            requestId: card.id,
          );
          if (file.bytes.length > ticket.maxBytes) {
            card.error = l10n.tr('tooLarge');
            continue;
          }
          await api!.putBytes(ticket, Uint8List.fromList(file.bytes), thumb);
          await api!.complete(ticket);
          pending = pending.where((item) => item.id != card.id).toList();
          anyOk = true;
        } catch (error) {
          card.error = explain(error);
        }
      }
    }
    if (anyOk) {
      draft = '';
      files = [];
      tools.write('tempbox.draft', '');
      say(l10n.tr('createOk'));
      try {
        await refresh();
      } catch (error) {
        say(explain(error));
      }
    }
    notifyListeners();
  }

  Future<void> copyItem(BoxItem item) async {
    if (!item.hasText) return;
    await Clipboard.setData(ClipboardData(text: item.text!));
    say(l10n.tr('copied'));
  }

  Future<void> receive(BoxItem item) async {
    touch();
    if (offline || api == null) {
      say(l10n.tr('offline'));
      return;
    }
    if (item.status == 'locked' && (item.lockExpiresAt ?? 0) > DateTime.now().millisecondsSinceEpoch) {
      say(l10n.tr('locked'));
      return;
    }
    busy = true;
    say(l10n.tr('receiving'));
    notifyListeners();
    try {
      final claim = await api!.claim(item.itemId);
      if (item.kind == 'message') {
        final name = textDownloadName(DateTime.now().toUtc(), usedNames);
        tools.saveFile(name, Uint8List.fromList(utf8.encode(claim.text ?? item.text ?? '')), 'text/plain;charset=utf-8');
      } else if (claim.downloadUrl != null) {
        final bytes = await api!.download(claim.downloadUrl!);
        final ext = (claim.fileName ?? item.fileName ?? '').split('.').last.toLowerCase();
        final mime = {'html', 'htm', 'svg', 'apk'}.contains(ext) ? 'application/octet-stream' : (claim.mime ?? 'application/octet-stream');
        tools.saveFile(claim.fileName ?? item.fileName ?? 'file', bytes, mime);
      }
      await api!.ack(item.itemId, claim.claimToken);
      await refresh();
      say(l10n.tr('receiveOk'));
    } catch (error) {
      say(explain(error));
      try {
        await refresh();
      } catch (_) {}
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> deleteItem(BoxItem item) async {
    if (armedDelete != item.itemId) {
      armedDelete = item.itemId;
      notifyListeners();
      return;
    }
    if (offline || api == null) {
      say(l10n.tr('offline'));
      return;
    }
    busy = true;
    notifyListeners();
    try {
      await api!.deleteItem(item.itemId, confirm: true);
      armedDelete = null;
      await refresh();
    } catch (error) {
      say(explain(error));
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout({bool idle = false}) async {
    try {
      await api?.logout();
    } catch (_) {}
    profile = null;
    box = null;
    items = [];
    pending = [];
    files = [];
    withdrawArmed = false;
    if (idle) say(l10n.tr('idle'));
    go(Screen.welcome);
  }

  Future<void> changePassword(String current, String next, String confirm) async {
    if (!validPassword(next)) {
      fieldError = l10n.tr('passwordCharset');
      notifyListeners();
      return;
    }
    if (next != confirm) {
      fieldError = l10n.tr('passwordMismatch');
      notifyListeners();
      return;
    }
    if (api == null || offline) {
      say(l10n.tr('offline'));
      return;
    }
    try {
      await api!.changePassword(current, next);
      fieldError = null;
      say(l10n.tr('save'));
    } catch (error) {
      fieldError = explain(error);
      notifyListeners();
    }
  }

  Future<void> setShelf(String backend, int? cap) async {
    if (api == null || offline) {
      say(l10n.tr('offline'));
      return;
    }
    try {
      profile = await api!.setBackend(backend, cap);
      notifyListeners();
    } catch (error) {
      say(explain(error));
    }
  }

  Future<void> withdraw() async {
    if (!withdrawArmed) {
      withdrawArmed = true;
      notifyListeners();
      return;
    }
    if (api == null) return;
    try {
      await api!.deleteAccount();
      profile = null;
      box = null;
      items = [];
      tools.write('tempbox.code', null);
      tools.write('tempbox.token', null);
      withdrawArmed = false;
      say(l10n.tr('withdrawDone'));
      go(Screen.welcome);
    } catch (error) {
      say(explain(error));
    }
  }

  Future<void> loadAdmin() async {
    if (api == null || profile?.admin != true) return;
    final stats = await api!.stats(statDays);
    statRows = stats.rows;
    statBars = stats.bars;
    adminUsers = await api!.users('');
    auditRows = await api!.audit();
    notifyListeners();
  }

  Future<void> searchUsers(String query) async {
    if (api == null) return;
    adminUsers = await api!.users(query);
    notifyListeners();
  }

  Future<void> setStatDays(int days) async {
    statDays = days;
    if (api == null) return;
    final stats = await api!.stats(days);
    statRows = stats.rows;
    statBars = stats.bars;
    notifyListeners();
  }

  String csv() {
    final buffer = StringBuffer('\uFEFF');
    buffer.writeln('${l10n.tr('colDate')},${l10n.tr('colEvent')},${l10n.tr('colGuest')},${l10n.tr('colSigned')},${l10n.tr('colTotal')}');
    for (final row in statRows) {
      buffer.writeln('${row.date},${_eventLabel(row.event)},${row.guest},${row.signed},${row.total}');
    }
    return buffer.toString();
  }

  String _eventLabel(String event) {
    switch (event) {
      case 'created':
        return l10n.tr('evCreated');
      case 'claimed':
        return l10n.tr('evClaimed');
      case 'deleted':
        return l10n.tr('evDeleted');
      case 'expired':
        return l10n.tr('evExpired');
      default:
        return l10n.tr('evRejected');
    }
  }

  Future<void> grant(AdminUser user, bool admin) async {
    try {
      await api!.setAdmin(user.uid, admin);
      await searchUsers('');
    } catch (error) {
      say(explain(error));
    }
  }

  Future<void> disable(AdminUser user, bool disabled) async {
    try {
      await api!.setDisabled(user.uid, disabled);
      await searchUsers('');
    } catch (error) {
      say(explain(error));
    }
  }

  Future<void> armPurge(AdminUser user) async {
    purgeCount = await api!.previewPurge(user.uid);
    purgeUid = user.uid;
    notifyListeners();
  }

  Future<void> confirmPurge() async {
    if (purgeUid == null) return;
    await api!.purgeGuest(purgeUid!);
    purgeUid = null;
    purgeCount = null;
    await searchUsers('');
  }

  Future<void> runExpire() async {
    await api!.runExpire();
    say(l10n.tr('expireDone'));
    await loadAdmin();
  }

  Future<void> debugExpire() async {
    await api?.debugPurge();
    await refresh();
    say(l10n.tr('expireDone'));
  }

  Future<void> debugUnlock() async {
    await api?.debugUnlock();
    await refresh();
    say(l10n.tr('unlockDone'));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
