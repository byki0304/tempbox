String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String remainingLabel(int expiresAt, int nowMs, String Function(int days, int hours) daysHours, String Function(int minutes) minutes) {
  final left = expiresAt - nowMs;
  if (left >= 3600000) {
    final hoursTotal = left ~/ 3600000;
    return daysHours(hoursTotal ~/ 24, hoursTotal % 24);
  }
  final mins = left <= 0 ? 0 : (left / 60000).ceil();
  return minutes(mins < 1 ? 1 : mins);
}

String seoulStamp(DateTime utc) {
  final seoul = utc.toUtc().add(const Duration(hours: 9));
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(seoul.year % 100)}${p(seoul.month)}${p(seoul.day)}-${p(seoul.hour)}${p(seoul.minute)}${p(seoul.second)}';
}

String textDownloadName(DateTime utc, Set<String> used) {
  final base = seoulStamp(utc);
  var name = '$base.txt';
  var n = 2;
  while (used.contains(name)) {
    name = '$base-$n.txt';
    n += 1;
  }
  used.add(name);
  return name;
}

String displayPairingCode(String code) {
  final raw = code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (raw.length < 8) return raw;
  return '${raw.substring(0, 4)}-${raw.substring(4, 8)}';
}

String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  return '${email.substring(0, 1)}***${email.substring(at)}';
}

String maskPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final last = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
  final head = phone.length >= 3 ? phone.substring(0, 3) : phone;
  return '$head **** $last';
}

bool validPassword(String value) => RegExp(r'^[A-Za-z0-9]{6,20}$').hasMatch(value);

bool validEmail(String value) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);

bool validNickname(String value) => RegExp(r'^[\p{L}\p{N}]{2,16}$', unicode: true).hasMatch(value);

String? normalizePhone(String country, String national) {
  final digits = national.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 9 || digits.length > 11) return null;
  var cc = country.trim();
  if (!cc.startsWith('+')) cc = '+${cc.replaceAll(RegExp(r'\D'), '')}';
  var body = digits;
  if (cc == '+82' && body.startsWith('0')) body = body.substring(1);
  if (body.length < 9 || body.length > 11) return null;
  return '$cc$body';
}

int meaningfulLength(String text) => text.runes.where((r) => !RegExp(r'\s').hasMatch(String.fromCharCode(r))).length;

String seoulClock(int epochMs) {
  final seoul = DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).add(const Duration(hours: 9));
  String p(int n) => n.toString().padLeft(2, '0');
  return '${seoul.year}-${p(seoul.month)}-${p(seoul.day)} ${p(seoul.hour)}:${p(seoul.minute)}';
}

String seoulHm(int epochMs) => seoulClock(epochMs).substring(11);

String chatDayLabel(int epochMs, int nowMs, {required String locale}) {
  final seoul = DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).add(const Duration(hours: 9));
  final today = DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true).add(const Duration(hours: 9));
  final sameYear = seoul.year == today.year;
  if (locale == 'ja') {
    if (sameYear) return '${seoul.month}月${seoul.day}日';
    return '${seoul.year}年${seoul.month}月${seoul.day}日';
  }
  if (locale == 'ko') {
    if (sameYear) return '${seoul.month}월 ${seoul.day}일';
    return '${seoul.year}년 ${seoul.month}월 ${seoul.day}일';
  }
  if (sameYear) return '${seoul.month}/${seoul.day}';
  return '${seoul.year}-${seoul.month}-${seoul.day}';
}

String seoulDayKey(int epochMs) => seoulClock(epochMs).substring(0, 10);

const cloudCaps = <int>[
  20 * 1024 * 1024,
  100 * 1024 * 1024,
  256 * 1024 * 1024,
  512 * 1024 * 1024,
  1024 * 1024 * 1024,
];

const driveCaps = <int>[
  128 * 1024 * 1024,
  256 * 1024 * 1024,
  512 * 1024 * 1024,
  1024 * 1024 * 1024,
  2 * 1024 * 1024 * 1024,
];

String driveCapLabel(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) return '${bytes ~/ (1024 * 1024 * 1024)}GB';
  return '${bytes ~/ (1024 * 1024)}MB';
}
