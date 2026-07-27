import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/cliente_api.dart';
import '../core/config/app_environment.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
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
  static bool _firebaseReady = false;
  static Object? _initializationError;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _deviceUuidKey = 'red_sky_device_uuid';
  static final StreamController<Map<String, dynamic>> _openedMessages =
      StreamController<Map<String, dynamic>>.broadcast();
  static final List<Map<String, dynamic>> _pendingOpenedMessages = [];

  static Stream<Map<String, dynamic>> get openedMessages =>
      _openedMessages.stream;
  static bool get isAvailable => _firebaseReady;
  static Object? get initializationError => _initializationError;

  static List<Map<String, dynamic>> takePendingOpenedMessages() {
    final pending = List<Map<String, dynamic>>.from(_pendingOpenedMessages);
    _pendingOpenedMessages.clear();
    return pending;
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (error) {
      _firebaseReady = false;
      _initializationError = error;
      _diagnostic(
        'Firebase/FCM no disponible en ${AppEnvironment.current.label}. '
        'La app continuara sin notificaciones. Verifica google-services.json, '
        'GoogleService-Info.plist, APNs y las credenciales FCM.',
        error,
      );
      return;
    }

    try {
      await _initializeLocalNotifications();
      await _requestPermissions();
      await _configureForegroundPresentation();
      _bindMessageStreams();
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) _emitOpenedMessage(initialMessage);
    } catch (error) {
      _initializationError = error;
      _diagnostic(
        'FCM se inicializo, pero la configuracion de notificaciones fallo. '
        'La app continuara sin notificaciones.',
        error,
      );
    }
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
      _diagnostic('Permiso push: ${settings.authorizationStatus}');
    } catch (error) {
      _diagnostic('No se pudo solicitar permiso push.', error);
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
    } catch (error) {
      _diagnostic('No se pudo configurar presentación foreground.', error);
    }
  }

  static void _bindMessageStreams() {
    FirebaseMessaging.onMessage.listen((message) async {
      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_emitOpenedMessage);
    _messaging.onTokenRefresh.listen((_) => syncAuthenticatedDevice());
  }

  static void _emitOpenedMessage(RemoteMessage message) {
    final data = Map<String, dynamic>.unmodifiable(message.data);
    _pendingOpenedMessages.add(data);
    _openedMessages.add(data);
  }

  static Future<void> syncAuthenticatedDevice() async {
    if (!_firebaseReady || !ApiClient.instance.hasToken) return;
    try {
      final uuid = await _deviceUuid();
      final token = await _messaging.getToken();
      await ApiClient.instance.registerDevice(
        deviceUuid: uuid,
        platform: Platform.isIOS ? 'ios' : 'android',
        pushToken: token,
        appVersion: const String.fromEnvironment('APP_VERSION'),
      );
    } catch (error) {
      _diagnostic('No se pudo sincronizar el dispositivo.', error);
    }
  }

  static Future<void> revokeAuthenticatedDevice() async {
    if (!ApiClient.instance.hasToken) return;
    try {
      await ApiClient.instance.revokeDevice(await _deviceUuid());
    } catch (error) {
      _diagnostic('No se pudo revocar remotamente el dispositivo.', error);
    }
  }

  static Future<String> _deviceUuid() async {
    final existing = await _secureStorage.read(key: _deviceUuidKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = const Uuid().v4();
    await _secureStorage.write(
      key: _deviceUuidKey,
      value: generated,
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
    return generated;
  }

  static void _diagnostic(String message, [Object? error]) {
    if (!AppEnvironment.current.allowsDiagnosticLogs) return;
    debugPrint(
      error == null
          ? '[PUSH] $message'
          : '[PUSH] $message ${error.runtimeType}',
    );
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
