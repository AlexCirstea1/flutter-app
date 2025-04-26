// import 'package:firebase_messaging/firebase_messaging.dart';
//
// typedef TokenSender = Future<void> Function(String token);
//
// class PushService {
//   PushService._();
//   static final instance = PushService._();
//
//   /// Registers for push *once* and keeps backend in sync when FCM rotates.
//   Future<void> register(TokenSender sendTokenToBackend) async {
//     final fm = FirebaseMessaging.instance;
//
//     // Ask permission (handled automatically on Android ≤12)
//     final perms = await fm.requestPermission(alert: true, badge: true, sound: true);
//     if (perms.authorizationStatus == AuthorizationStatus.denied) return;
//
//     // Current token
//     final token = await fm.getToken();
//     if (token != null) await sendTokenToBackend(token);
//
//     // Future rotations
//     fm.onTokenRefresh.listen(sendTokenToBackend);
//   }
// }
