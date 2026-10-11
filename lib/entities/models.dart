class Profile {
  Profile({
    required this.uid,
    required this.provider,
    required this.storageBackend,
    required this.disabled,
    required this.admin,
    required this.createdAt,
    required this.lastLoginAt,
    this.nickname,
    this.email,
    this.phoneE164,
    this.driveMaxBytes,
    this.cloudMaxBytes,
  });

  final String uid;
  final String? nickname;
  final String provider;
  final String? email;
  final String? phoneE164;
  final String storageBackend;
  final int? driveMaxBytes;
  final int? cloudMaxBytes;
  final bool disabled;
  final bool admin;
  final int createdAt;
  final int lastLoginAt;

  bool get isGuest => provider == 'anonymous';
  bool get isGoogle => provider == 'google';

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      uid: json['uid'] as String,
      nickname: json['nickname'] as String?,
      provider: json['provider'] as String? ?? 'email',
      email: json['email'] as String?,
      phoneE164: json['phoneE164'] as String?,
      storageBackend: json['storageBackend'] as String? ?? 'firebase',
      driveMaxBytes: (json['driveMaxBytes'] as num?)?.toInt(),
      cloudMaxBytes: (json['cloudMaxBytes'] as num?)?.toInt(),
      disabled: json['disabled'] == true,
      admin: json['admin'] == true,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      lastLoginAt: (json['lastLoginAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class BoxRecord {
  BoxRecord({required this.boxId, required this.ownerUid, required this.kind, required this.createdAt});
  final String boxId;
  final String ownerUid;
  final String kind;
  final int createdAt;

  factory BoxRecord.fromJson(Map<String, dynamic> json) {
    return BoxRecord(
      boxId: json['boxId'] as String,
      ownerUid: json['ownerUid'] as String,
      kind: json['kind'] as String,
      createdAt: (json['createdAt'] as num).toInt(),
    );
  }
}

class BoxItem {
  BoxItem({
    required this.itemId,
    required this.boxId,
    required this.kind,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.text,
    this.fileName,
    this.mime,
    this.bytes,
    this.backend,
    this.lockExpiresAt,
    this.thumbnailUrl,
    this.originDeviceId,
    this.authorUid,
  });

  final String itemId;
  final String boxId;
  final String kind;
  final String? text;
  final String? fileName;
  final String? mime;
  final int? bytes;
  final String? backend;
  final String status;
  final int? lockExpiresAt;
  final int createdAt;
  final int expiresAt;
  final String? thumbnailUrl;
  final String? originDeviceId;
  final String? authorUid;

  bool get hasText => text != null && text!.trim().isNotEmpty;
  bool get isFile => kind == 'file' || kind == 'message_file';

  factory BoxItem.fromJson(Map<String, dynamic> json) {
    return BoxItem(
      itemId: json['itemId'] as String,
      boxId: json['boxId'] as String,
      kind: json['kind'] as String,
      text: json['text'] as String?,
      fileName: json['fileName'] as String?,
      mime: json['mime'] as String?,
      bytes: (json['bytes'] as num?)?.toInt(),
      backend: json['backend'] as String?,
      status: json['status'] as String? ?? 'available',
      lockExpiresAt: (json['lockExpiresAt'] as num?)?.toInt(),
      createdAt: (json['createdAt'] as num).toInt(),
      expiresAt: (json['expiresAt'] as num).toInt(),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      originDeviceId: json['originDeviceId'] as String?,
      authorUid: json['authorUid'] as String?,
    );
  }
}

class UploadTicket {
  UploadTicket({
    required this.uploadId,
    required this.maxBytes,
    required this.backend,
    this.storagePath,
    this.uploadUrl,
    this.thumbUrl,
    this.driveFileId,
    this.fellBack = false,
  });

  final String uploadId;
  final int maxBytes;
  final String backend;
  final String? storagePath;
  final String? uploadUrl;
  final String? thumbUrl;
  final String? driveFileId;
  final bool fellBack;

  factory UploadTicket.fromJson(Map<String, dynamic> json) {
    return UploadTicket(
      uploadId: json['uploadId'] as String,
      maxBytes: (json['maxBytes'] as num).toInt(),
      backend: json['backend'] as String,
      storagePath: json['storagePath'] as String?,
      uploadUrl: json['uploadUrl'] as String?,
      thumbUrl: json['thumbUrl'] as String?,
      driveFileId: json['driveFileId'] as String?,
      fellBack: json['fellBack'] == true,
    );
  }
}

class ClaimResult {
  ClaimResult({required this.claimToken, this.downloadUrl, this.text, this.fileName, this.mime});
  final String claimToken;
  final String? downloadUrl;
  final String? text;
  final String? fileName;
  final String? mime;

  factory ClaimResult.fromJson(Map<String, dynamic> json) {
    return ClaimResult(
      claimToken: json['claimToken'] as String,
      downloadUrl: json['downloadUrl'] as String?,
      text: json['text'] as String?,
      fileName: json['fileName'] as String?,
      mime: json['mime'] as String?,
    );
  }
}

class PickedFile {
  PickedFile({required this.name, required this.mime, required this.bytes});
  final String name;
  final String mime;
  final List<int> bytes;
}

class AdminUser {
  AdminUser({
    required this.uid,
    required this.nickname,
    required this.role,
    required this.provider,
    required this.contact,
    required this.createdAt,
    required this.lastLoginAt,
    required this.itemCount,
    required this.disabled,
  });
  final String uid;
  final String nickname;
  final String role;
  final String provider;
  final String contact;
  final int createdAt;
  final int lastLoginAt;
  final int itemCount;
  final bool disabled;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      uid: json['uid'] as String,
      nickname: json['nickname'] as String? ?? '',
      role: json['role'] as String? ?? 'signed',
      provider: json['provider'] as String? ?? '',
      contact: json['contact'] as String? ?? '',
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      lastLoginAt: (json['lastLoginAt'] as num?)?.toInt() ?? 0,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      disabled: json['disabled'] == true,
    );
  }
}

class StatRow {
  StatRow({required this.date, required this.event, required this.guest, required this.signed});
  final String date;
  final String event;
  final int guest;
  final int signed;
  int get total => guest + signed;
}

class StatBar {
  StatBar({required this.date, required this.guest, required this.signed});
  final String date;
  final int guest;
  final int signed;
}

class AuditRow {
  AuditRow({required this.actorUid, required this.action, required this.targetUid, required this.changedFields, required this.at});
  final String actorUid;
  final String action;
  final String? targetUid;
  final List<String> changedFields;
  final int at;
}
