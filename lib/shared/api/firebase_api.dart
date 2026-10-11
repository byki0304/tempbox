import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

import '../../app/config.dart';
import '../../entities/models.dart';
import 'api_client.dart';
import 'dart:typed_data';

class FirebaseBoxApi implements BoxApi {
  FirebaseBoxApi(this._functions, this._auth, this._storage);
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    try {
      final result = await _functions.httpsCallable(name).call(data);
      final raw = result.data;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return {};
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      if (details is Map && details['code'] is String) throw ApiException(details['code'] as String);
      throw ApiException(error.message ?? 'invalid');
    }
  }

  Future<Profile> _ensureFromUser(User user) async {
    final json = await _call('ensureAccount', {});
    return Profile.fromJson(Map<String, dynamic>.from(json['profile'] as Map));
  }

  Future<AuthResult> _session() async {
    final user = _auth.currentUser;
    if (user == null) throw ApiException('unauthenticated');
    return AuthResult(token: await user.getIdToken(), profile: await _ensureFromUser(user));
  }

  @override
  Future<void> health() async {}

  @override
  Future<AuthResult> signup({required String kind, String? email, String? password, String? country, String? national}) async {
    final address = kind == 'phone' ? '${_phone(country, national)}@phone.tempbox.invalid' : email!.trim().toLowerCase();
    await _auth.createUserWithEmailAndPassword(email: address, password: password!);
    return _session();
  }

  @override
  Future<AuthResult> login({required String kind, String? email, String? password, String? country, String? national}) async {
    final address = kind == 'phone' ? '${_phone(country, national)}@phone.tempbox.invalid' : email!.trim().toLowerCase();
    try {
      await _auth.signInWithEmailAndPassword(email: address, password: password!);
    } on FirebaseAuthException {
      throw ApiException(kind == 'phone' ? 'invalid_phone_login' : 'invalid_login');
    }
    return _session();
  }

  String _phone(String? country, String? national) {
    final digits = (national ?? '').replaceAll(RegExp(r'\D'), '');
    var cc = (country ?? '+82').trim();
    if (!cc.startsWith('+')) cc = '+$cc';
    var body = digits;
    if (cc == '+82' && body.startsWith('0')) body = body.substring(1);
    return '$cc$body';
  }

  @override
  Future<AuthResult> google() async {
    await _auth.signInWithPopup(GoogleAuthProvider());
    return _session();
  }

  @override
  Future<AuthResult> guest() async {
    await _auth.signInAnonymously();
    return _session();
  }

  @override
  Future<AuthResult> link({required String kind, String? email, String? password, String? country, String? national}) async {
    final user = _auth.currentUser;
    if (user == null) throw ApiException('unauthenticated');
    if (kind == 'google') {
      await user.linkWithPopup(GoogleAuthProvider());
    } else {
      final address = kind == 'phone' ? '${_phone(country, national)}@phone.tempbox.invalid' : email!.trim().toLowerCase();
      await user.linkWithCredential(EmailAuthProvider.credential(email: address, password: password!));
    }
    return _session();
  }

  @override
  Future<void> logout() => _auth.signOut();

  @override
  Future<Profile> ensure() => _session().then((value) => value.profile);

  @override
  Future<Profile> setNickname(String nickname, {required bool confirm}) async {
    final json = await _call('setNickname', {'nickname': nickname, 'confirm': confirm});
    if (json['profile'] == null) return ensure();
    return Profile.fromJson(Map<String, dynamic>.from(json['profile'] as Map));
  }

  BoxOpen _box(Map<String, dynamic> json) => BoxOpen(
        box: BoxRecord.fromJson(Map<String, dynamic>.from(json['box'] as Map)),
        pairingCode: json['pairingCode'] as String?,
        pairingCodeDisplay: json['pairingCodeDisplay'] as String?,
      );

  @override
  Future<BoxOpen> createBox({bool fresh = false}) async => _box(await _call('createBox', {'fresh': fresh}));

  @override
  Future<BoxOpen> redeem(String code) async => _box(await _call('redeemPairingCode', {'code': code}));

  @override
  Future<BoxHome> listItems() async {
    final json = await _call('listItems', {});
    return BoxHome(
      profile: Profile.fromJson(Map<String, dynamic>.from(json['profile'] as Map)),
      box: json['box'] == null ? null : BoxRecord.fromJson(Map<String, dynamic>.from(json['box'] as Map)),
      items: (json['items'] as List? ?? []).map((row) => BoxItem.fromJson(Map<String, dynamic>.from(row as Map))).toList(),
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
    return UploadTicket.fromJson(json);
  }

  @override
  Future<void> putBytes(UploadTicket ticket, Uint8List bytes, Uint8List? thumb) async {
    if (ticket.uploadUrl != null) {
      final sent = await http.put(Uri.parse(ticket.uploadUrl!), body: bytes, headers: {'Cache-Control': 'no-store'});
      if (sent.statusCode >= 400) throw ApiException('invalid');
      if (thumb != null && ticket.thumbUrl != null) {
        await http.put(Uri.parse(ticket.thumbUrl!), body: thumb);
      }
      return;
    }
    if (ticket.storagePath == null) throw ApiException('invalid');
    await _storage.ref(ticket.storagePath).putData(bytes, SettableMetadata(contentType: 'application/octet-stream', cacheControl: 'private, no-store'));
    if (thumb != null) {
      await _storage.ref('thumbs/${ticket.uploadId}.webp').putData(thumb, SettableMetadata(contentType: 'image/webp', cacheControl: 'private, no-store'));
    }
  }

  @override
  Future<BoxItem> complete(UploadTicket ticket) async {
    final json = await _call('completeFileUpload', {'uploadId': ticket.uploadId, 'driveFileId': ticket.driveFileId});
    return BoxItem.fromJson(Map<String, dynamic>.from(json['item'] as Map));
  }

  @override
  Future<ClaimResult> claim(String itemId) async => ClaimResult.fromJson(await _call('claimItem', {'itemId': itemId}));

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
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) throw ApiException('forbidden');
    final cred = EmailAuthProvider.credential(email: email, password: current);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(next);
    await _call('recordPasswordChange', {});
  }

  @override
  Future<void> deleteAccount() async {
    await _call('deleteAccount', {});
    await _auth.currentUser?.delete();
  }

  @override
  Future<({List<StatRow> rows, List<StatBar> bars})> stats(int days) async {
    final json = await _call('adminGetStats', {'days': days});
    return (
      rows: (json['rows'] as List? ?? []).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        return StatRow(date: map['date'] as String, event: map['event'] as String, guest: (map['guest'] as num).toInt(), signed: (map['signed'] as num).toInt());
      }).toList(),
      bars: (json['bars'] as List? ?? []).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        return StatBar(date: map['date'] as String, guest: (map['guest'] as num).toInt(), signed: (map['signed'] as num).toInt());
      }).toList(),
    );
  }

  @override
  Future<List<AdminUser>> users(String query) async {
    final json = await _call('adminListUsers', {'query': query});
    return (json['users'] as List? ?? []).map((row) => AdminUser.fromJson(Map<String, dynamic>.from(row as Map))).toList();
  }

  @override
  Future<void> setAdmin(String uid, bool admin) => _call('setAdminClaim', {'targetUid': uid, 'admin': admin});

  @override
  Future<void> setDisabled(String uid, bool disabled) => _call('adminSetDisabled', {'targetUid': uid, 'disabled': disabled});

  @override
  Future<int> previewPurge(String uid) async => ((await _call('adminPurgeGuest', {'targetUid': uid, 'confirm': false}))['itemCount'] as num?)?.toInt() ?? 0;

  @override
  Future<void> purgeGuest(String uid) => _call('adminPurgeGuest', {'targetUid': uid, 'confirm': true});

  @override
  Future<List<AuditRow>> audit() async {
    final json = await _call('adminListAudit', {});
    return (json['rows'] as List? ?? []).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      return AuditRow(
        actorUid: map['actorUid'] as String,
        action: map['action'] as String,
        targetUid: map['targetUid'] as String?,
        changedFields: (map['changedFields'] as List? ?? []).map((field) => '$field').toList(),
        at: (map['at'] as num).toInt(),
      );
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> runExpire() => _call('purgeExpired', {});

  @override
  Future<void> debugPurge() async {}

  @override
  Future<void> debugUnlock() async {}
}

Future<BoxApi> openFirebaseApi() async {
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: AppConfig.apiKey,
      appId: AppConfig.appId,
      messagingSenderId: AppConfig.messagingSenderId,
      projectId: AppConfig.projectId,
      authDomain: AppConfig.authDomain.isEmpty ? null : AppConfig.authDomain,
      storageBucket: AppConfig.storageBucket.isEmpty ? null : AppConfig.storageBucket,
      measurementId: AppConfig.measurementId.isEmpty ? null : AppConfig.measurementId,
    ),
  );
  return FirebaseBoxApi(
    FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
    FirebaseAuth.instance,
    FirebaseStorage.instance,
  );
}
