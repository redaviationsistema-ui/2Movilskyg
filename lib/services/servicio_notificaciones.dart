import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint(
      '[PUSH][background] messageId=${message.messageId} data=${jsonEncode(message.data)}',
    );
  } catch (error) {
    debugPrint('[PUSH][background] init_failed error=$error');
  }
}

class PushNotificationsService {
  PushNotificationsService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'redsky_general_notifications',
        'Red Sky Notifications',
        description: 'Alertas generales y operativas de Red Sky.',
        importance: Importance.high,
      );

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    try {
      await Firebase.initializeApp();
      debugPrint('[PUSH] Firebase.initializeApp success');
    } catch (error) {
      debugPrint(
        '[PUSH] Firebase.initializeApp failed. '
        'Verifica google-services.json / GoogleService-Info.plist. error=$error',
      );
      return;
    }

    await _initializeLocalNotifications();
    await _requestPermissions();
    await _configureForegroundPresentation();
    await _logFcmToken();
    _bindMessageStreams();
  }

  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    final androidPlugin =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidPlugin?.createNotificationChannel(_androidChannel);
  }

  static Future<void> _requestPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint(
        '[PUSH] requestPermission status=${settings.authorizationStatus}',
      );
    } catch (error) {
      debugPrint('[PUSH] requestPermission failed error=$error');
    }
  }

  static Future<void> _configureForegroundPresentation() async {
    if (!Platform.isIOS && !Platform.isMacOS) return;
    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[PUSH] iOS foreground presentation enabled');
    } catch (error) {
      debugPrint('[PUSH] foreground presentation failed error=$error');
    }
  }

  static Future<void> _logFcmToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('[PUSH] FCM token=$token');
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        debugPrint('[PUSH] APNS token=$apnsToken');
      }
    } catch (error) {
      debugPrint('[PUSH] getToken failed error=$error');
    }
  }

  static void _bindMessageStreams() {
    FirebaseMessaging.onMessage.listen((message) async {
      debugPrint(
        '[PUSH][foreground] messageId=${message.messageId} '
        'notification=${message.notification?.title} '
        'data=${jsonEncode(message.data)}',
      );
      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint(
        '[PUSH][opened_app] messageId=${message.messageId} data=${jsonEncode(message.data)}',
      );
    });
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'redsky_general_notifications',
      'Red Sky Notifications',
      channelDescription: 'Alertas generales y operativas de Red Sky.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(message.data),
    );
  }
}
