import 'dart:typed_data';

import '../../entities/models.dart';

class ApiException implements Exception {
  ApiException(this.code);
  final String code;
}

class AuthResult {
  AuthResult({required this.token, required this.profile});
  final String? token;
  final Profile profile;
}

class BoxOpen {
  BoxOpen({required this.box, this.pairingCode, this.pairingCodeDisplay});
  final BoxRecord box;
  final String? pairingCode;
  final String? pairingCodeDisplay;
}

class BoxHome {
  BoxHome({required this.profile, this.box, required this.items});
  final Profile profile;
  final BoxRecord? box;
  final List<BoxItem> items;
}

abstract class BoxApi {
  Future<void> health();
  Future<AuthResult> signup({required String kind, String? email, String? password, String? country, String? national});
  Future<AuthResult> login({required String kind, String? email, String? password, String? country, String? national});
  Future<AuthResult> google();
  Future<AuthResult> guest();
  Future<AuthResult> link({required String kind, String? email, String? password, String? country, String? national});
  Future<void> logout();
  Future<Profile> ensure();
  Future<Profile> setNickname(String nickname, {required bool confirm});
  Future<BoxOpen> createBox({bool fresh = false});
  Future<BoxOpen> redeem(String code);
  Future<BoxHome> listItems();
  Future<BoxItem> createMessage(String text, String requestId, {String? deviceId});
  Future<UploadTicket> beginFile({required String fileName, String? text, required int declaredBytes, required String requestId, String? deviceId});
  Future<void> putBytes(UploadTicket ticket, Uint8List bytes, Uint8List? thumb);
  Future<BoxItem> complete(UploadTicket ticket);
  Future<ClaimResult> claim(String itemId);
  Future<Uint8List> download(String url);
  Future<void> ack(String itemId, String token);
  Future<void> deleteItem(String itemId, {required bool confirm});
  Future<Profile> setBackend(String backend, int? driveMaxBytes, {int? cloudMaxBytes});
  Future<void> changePassword(String current, String next);
  Future<void> deleteAccount();
  Future<({List<StatRow> rows, List<StatBar> bars})> stats(int days);
  Future<List<AdminUser>> users(String query);
  Future<void> setAdmin(String uid, bool admin);
  Future<void> setDisabled(String uid, bool disabled);
  Future<int> previewPurge(String uid);
  Future<void> purgeGuest(String uid);
  Future<List<AuditRow>> audit();
  Future<Map<String, dynamic>> runExpire();
  Future<void> debugPurge();
  Future<void> debugUnlock();
}
