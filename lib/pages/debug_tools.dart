import 'package:flutter/material.dart';

import '../features/app_controller.dart';

Widget debugBar(AppController app) {
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        OutlinedButton(onPressed: app.debugExpire, child: Text(app.locale == 'en' ? 'Check expiry' : '만료 검사')),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: app.debugUnlock, child: Text(app.locale == 'en' ? 'Release lock' : '잠금 해제')),
      ],
    ),
  );
}
