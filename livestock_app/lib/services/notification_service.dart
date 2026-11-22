import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  final StreamController<String> _tokenController =
      StreamController<String>.broadcast();

  Stream<String> get onTokenRefresh => _tokenController.stream;

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'livestock_alerts',
    'Livestock Alerts',
    description: 'Notifications about livestock tracking and alerts.',
    importance: Importance.max,
  );

  Future<void> initialize() async {
    if (_initialized) return;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      'Notification permission: ${settings.authorizationStatus}',
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );

      await _localNotifications.initialize(initializationSettings);

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    // Get the current FCM token.
    _fcmToken = await _messaging.getToken();

    if (_fcmToken != null) {
      debugPrint('FCM token obtained.');
      _tokenController.add(_fcmToken!);
    }

    // Listen for token changes.
    _messaging.onTokenRefresh.listen(
      (newToken) {
        _fcmToken = newToken;
        debugPrint('FCM token refreshed.');
        _tokenController.add(newToken);
      },
      onError: (error) {
        debugPrint('FCM token refresh error: $error');
      },
    );

    // Foreground notifications.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('Foreground notification: ${message.messageId}');

      final notification = message.notification;
      final title = notification?.title ?? message.data['title'];
      final body = notification?.body ?? message.data['body'];

      if (title == null && body == null) return;

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _localNotifications.show(
          message.messageId?.hashCode ??
              DateTime.now().millisecondsSinceEpoch,
          title ?? 'Livestock Alert',
          body ?? 'A new alert has been received.',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'livestock_alerts',
              'Livestock Alerts',
              channelDescription:
                  'Notifications about livestock tracking and alerts.',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification opened: ${message.messageId}');
    });

    final initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      debugPrint(
        'App launched from notification: ${initialMessage.messageId}',
      );
    }

    _initialized = true;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  debugPrint('Background message received: ${message.messageId}');
}