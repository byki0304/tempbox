import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../entities/models.dart';
import '../web/web_tools.dart';
import '../web/web_tools_api.dart';
import 'api_client.dart';

class LocalApi implements BoxApi {
  LocalApi(this.origin, {WebTools? tools}) : tools = tools ?? createWebTools() {
    token = this.tools.read('tempbox.token');
  }

  final String origin;
  final WebTools tools;
  String? token;

  Map<String, String> _headers({bool auth = true}) {
    final headers = {'Content-Type': 'application/json'};
    if (auth && token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data, {bool auth = true}) async {
    final response = await http.post(
      Uri.parse('$origin/v1/$name'),
      headers: _headers(auth: auth),
      body: jsonEncode({'data': data}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException((body['error'] as Map?)?['code'] as String? ?? 'invalid');
    }
    return Map<String, dynamic>.from(body['result'] as Map);
  }

  void _keep(AuthResult result) {
    token = result.token;
    tools.write('tempbox.token', token);
  }

  AuthResult _auth(Map<String, dynamic> json) {
    final result = AuthResult(
      token: json['token'] as String?,
      profile: Profile.fromJson(Map<String, dynamic>.from(json['profile'] as Map)),
    );
    _keep(result);
    return result;
  }

  @override
  Future<void> health() async {
    final response = await http.get(Uri.parse('$origin/health'));
    if (response.statusCode >= 400) throw ApiException('offline');
  }

  @override
  Future<AuthResult> signup({required String kind, String? email, String? password, String? country, String? national}) async {
    return _auth(await _call('signup', {
      'kind': kind,
      'email': email,
      'password': password,
      'country': country,
      'national': national,
    }, auth: false));
  }

  @override
  Future<AuthResult> login({required String kind, String? email, String? password, String? country, String? national}) async {
    return _auth(await _call('login', {
      'kind': kind,
      'email': email,
      'password': password,
      'country': country,
      'national': national,
    }, auth: false));
  }

  @override
  Future<AuthResult> google() async => _auth(await _call('google', {}, auth: false));

  @override
  Future<AuthResult> guest() async => _auth(await _call('guest', {}, auth: false));

  @override
  Future<AuthResult> link({required String kind, String? email, String? password, String? country, String? national}) async {
    return _auth(await _call('link', {
      'kind': kind,
      'email': email,
      'password': password,
      'country': country,
      'national': national,
    }));
  }

  @override
  Future<void> logout() async {
    try {
      await _call('logout', {});
    } catch (_) {}
    token = null;
    tools.write('tempbox.token', null);
  }

  @override
  Future<Profile> ensure() async {
    final json = await _call('ensureAccount', {});
    return Profile.fromJson(Map<String, dynamic>.from(json['profile'] as Map));
  }

  @override
  Future<Profile> setNickname(String nickname, {required bool confirm}) async {
    final json = await _call('setNickname', {'nickname': nickname, 'confirm': confirm});
    if (json['profile'] == null) return ensure();
    return Profile.fromJson(Map<String, dynamic>.from(json['profile'] as Map));
  }

  BoxOpen _box(Map<String, dynamic> json) {
    return BoxOpen(
      box: BoxRecord.fromJson(Map<String, dynamic>.from(json['box'] as Map)),
      pairingCode: json['pairingCode'] as String?,
      pairingCodeDisplay: json['pairingCodeDisplay'] as String?,
    );
  }

  @override
  Future<BoxOpen> createBox({bool fresh = false}) async => _box(await _call('createBox', {'fresh': fresh}));

  @override
  Future<BoxOpen> redeem(String code) async => _box(await _call('redeemPairingCode', {'code': code}));

  @override
  Future<BoxHome> listItems() async {
    final json = await _call('listItems', {});
    final items = (json['items'] as List? ?? []).map((row) => BoxItem.fromJson(Map<String, dynamic>.from(row as Map))).toList();
    return BoxHome(
      profile: Profile.fromJson(Map<String, dynamic>.from(json['profile'] as Map)),
      box: json['box'] == null ? null : BoxRecord.fromJson(Map<String, dynamic>.from(json['box'] as Map)),
      items: items,
    );
  }

  @override
  Future<BoxItem> createMessage(String text, String requestId) async {
    final json = await _call('createMessageItem', {'text': text, 'clientRequestId': requestId});
    return BoxItem.fromJson(Map<String, dynamic>.from(json['item'] as Map));
  }

  @override
  Future<UploadTicket> beginFile({required String fileName, String? text, required int declaredBytes, required String requestId}) async {
    final json = await _call('beginFileUpload', {
      'fileName': fileName,
      'text': text,
      'declaredBytes': declaredBytes,
      'clientRequestId': requestId,
    });
    if (json['already'] == true && json['item'] != null) {
      throw ApiException('already_done');
    }
    return UploadTicket.fromJson(json);
  }

  @override
  Future<void> putBytes(UploadTicket ticket, Uint8List bytes, Uint8List? thumb) async {
    if (ticket.uploadUrl == null) throw ApiException('invalid');
    final sent = await http.put(Uri.parse(ticket.uploadUrl!), body: bytes, headers: {'Cache-Control': 'no-store'});
    if (sent.statusCode >= 400) {
      final body = jsonDecode(sent.body);
      throw ApiException((body['error'] as Map?)?['code'] as String? ?? 'invalid');
    }
    if (thumb != null && ticket.thumbUrl != null) {
      await http.put(Uri.parse(ticket.thumbUrl!), body: thumb, headers: {'Cache-Control': 'no-store'});
    }
  }

  @override
  Future<BoxItem> complete(UploadTicket ticket) async {
    final json = await _call('completeFileUpload', {
      'uploadId': ticket.uploadId,
      'driveFileId': ticket.driveFileId,
    });
    return BoxItem.fromJson(Map<String, dynamic>.from(json['item'] as Map));
  }

  @override
  Future<ClaimResult> claim(String itemId) async {
    return ClaimResult.fromJson(await _call('claimItem', {'itemId': itemId}));
  }

  @override
  Future<Uint8List> download(String url) async {
    final response = await http.get(Uri.parse(url), headers: {'Cache-Control': 'no-store'});
    if (response.statusCode >= 400) throw ApiException('expired');
    return response.bodyBytes;
  }

  @override
  Future<void> ack(String itemId, String claimToken) async {
    await _call('ackItem', {'itemId': itemId, 'claimToken': claimToken});
  }

  @override
  Future<void> deleteItem(String itemId, {required bool confirm}) async {
    await _call('deleteItem', {'itemId': itemId, 'confirm': confirm});
  }

  @override
  Future<Profile> setBackend(String backend, int? driveMaxBytes) async {
    final json = await _call('setStorageBackend', {'storageBackend': backend, 'driveMaxBytes': driveMaxBytes});
    return Profile.fromJson(Map<String, dynamic>.from(json['profile'] as Map));
  }

  @override
  Future<void> changePassword(String current, String next) async {
    await _call('changePassword', {'current': current, 'next': next});
  }

  @override
  Future<void> deleteAccount() async {
    await _call('deleteAccount', {});
    token = null;
    tools.write('tempbox.token', null);
  }

  @override
  Future<({List<StatRow> rows, List<StatBar> bars})> stats(int days) async {
    final json = await _call('adminGetStats', {'days': days});
    final rows = (json['rows'] as List? ?? []).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      return StatRow(
        date: map['date'] as String,
        event: map['event'] as String,
        guest: (map['guest'] as num).toInt(),
        signed: (map['signed'] as num).toInt(),
      );
    }).toList();
    final bars = (json['bars'] as List? ?? []).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      return StatBar(date: map['date'] as String, guest: (map['guest'] as num).toInt(), signed: (map['signed'] as num).toInt());
    }).toList();
    return (rows: rows, bars: bars);
  }

  @override
  Future<List<AdminUser>> users(String query) async {
    final json = await _call('adminListUsers', {'query': query});
    return (json['users'] as List? ?? []).map((row) => AdminUser.fromJson(Map<String, dynamic>.from(row as Map))).toList();
  }

  @override
  Future<void> setAdmin(String uid, bool admin) async {
    await _call('setAdminClaim', {'targetUid': uid, 'admin': admin});
  }

  @override
  Future<void> setDisabled(String uid, bool disabled) async {
    await _call('adminSetDisabled', {'targetUid': uid, 'disabled': disabled});
  }

  @override
  Future<int> previewPurge(String uid) async {
    final json = await _call('adminPurgeGuest', {'targetUid': uid, 'confirm': false});
    return (json['itemCount'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> purgeGuest(String uid) async {
    await _call('adminPurgeGuest', {'targetUid': uid, 'confirm': true});
  }

  @override
  Future<List<AuditRow>> audit() async {
    final json = await _call('adminListAudit', {});
    return (json['rows'] as List? ?? []).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      return AuditRow(
        actorUid: map['actorUid'] as String,
        action: map['action'] as String,
        targetUid: map['targetUid'] as String?,
        changedFields: (map['changedFields'] as List? ?? []).map((field) => field.toString()).toList(),
        at: (map['at'] as num).toInt(),
      );
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> runExpire() async => _call('purgeExpired', {});

  @override
  Future<void> debugPurge() async {
    await _call('debugPurge', {});
  }

  @override
  Future<void> debugUnlock() async {
    await _call('debugUnlock', {});
  }
}
