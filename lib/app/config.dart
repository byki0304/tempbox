import 'package:flutter/foundation.dart';

class AppConfig {
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'tempbox-c3fc8');
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSyDz6E-qQOpytBkOjgQXOLAWdyKTCug_5W4');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '1:365507142335:web:70bcb33f83d80892205c0a');
  static const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '365507142335');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: 'tempbox-c3fc8.firebaseapp.com');
  static const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'tempbox-c3fc8.firebasestorage.app');
  static const measurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID', defaultValue: 'G-FH6SMZKF6V');
  static const googleCloudProjectId = String.fromEnvironment('GOOGLE_CLOUD_PROJECT_ID', defaultValue: 'tempbox-511314');
  static const apiOrigin = String.fromEnvironment('TEMPBOX_API', defaultValue: 'http://127.0.0.1:8787');

  static bool get firebaseReady => projectId.isNotEmpty && apiKey.isNotEmpty && appId.isNotEmpty;

  static bool get useLocalApi => !firebaseReady && kDebugMode;
}
