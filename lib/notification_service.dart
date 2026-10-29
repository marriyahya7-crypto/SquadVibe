import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static String? _registeredUid;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'squadvibe_alerts',
    'SquadVibe',
    description: 'Notifications de messages et appels SquadVibe',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _local.initialize(settings);
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;
      _local.show(
        notification.hashCode,
        notification.title ?? 'SquadVibe',
        notification.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });
    _initialized = true;
  }

  static Future<void> registerForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _registeredUid == user.uid) return;
    _registeredUid = user.uid;

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(user.uid, token);
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _saveToken(user.uid, newToken);
      });
    } catch (_) {
      // The app remains usable if notifications are not available on this device.
      _registeredUid = null;
    }
  }

  static Future<void> _saveToken(String uid, String token) async {
    await FirebaseFirestore.instance.collection('notificationTokens').doc(uid).set({
      'uid': uid,
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
