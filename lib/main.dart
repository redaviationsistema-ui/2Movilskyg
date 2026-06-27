import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'providers/proveedor_autenticacion.dart';
import 'providers/proveedor_reservaciones.dart';
import 'providers/proveedor_flujo_trabajo.dart';
import 'screens/auth/pantalla_puerta_autenticacion.dart';
import 'screens/cliente/views/pantalla_historial_cliente.dart';
import 'screens/cliente/views/pantalla_pago_cliente.dart';
import 'services/servicio_notificaciones.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPaintBaselinesEnabled = false;
  debugPaintSizeEnabled = false;
  debugPaintPointersEnabled = false;
  debugPaintLayerBordersEnabled = false;
  debugRepaintRainbowEnabled = false;
  Intl.defaultLocale = 'es_MX';
  await initializeDateFormatting('es_MX');
  await initializeDateFormatting('es');
  await PushNotificationsService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ReservationProvider()),
        ChangeNotifierProvider(create: (_) => WorkflowProvider()),
      ],
      child: const _RedSkyAppShell(),
    );
  }
}

class _RedSkyAppShell extends StatefulWidget {
  const _RedSkyAppShell();

  @override
  State<_RedSkyAppShell> createState() => _RedSkyAppShellState();
}

class _RedSkyAppShellState extends State<_RedSkyAppShell> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _paymentLinkSubscription;
  String _lastHandledPaymentLink = '';

  @override
  void initState() {
    super.initState();
    _bindPaymentReturnLinks();
  }

  @override
  void dispose() {
    _paymentLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bindPaymentReturnLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        unawaited(_handlePaymentReturnLink(initialUri));
      }
    } catch (_) {
      // El flujo tambien se cubre con el stream cuando la app ya esta viva.
    }

    _paymentLinkSubscription = _appLinks.uriLinkStream.listen((uri) {
      unawaited(_handlePaymentReturnLink(uri));
    });
  }

  Future<void> _handlePaymentReturnLink(Uri uri) async {
    if (uri.scheme != kMobileCheckoutReturnScheme) return;
    if (uri.host != kMobileCheckoutReturnHost) return;
    if (uri.path != kMobileCheckoutReturnPath) return;

    final linkKey = uri.toString();
    if (_lastHandledPaymentLink == linkKey) return;
    if (ClientPaymentScreen.hasActiveCommercialAccessHandler) return;
    _lastHandledPaymentLink = linkKey;

    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    final refreshTarget =
        uri.queryParameters['refresh']?.trim().toLowerCase() ?? '';
    final reservationId =
        (uri.queryParameters['reservation_id'] ??
                uri.queryParameters['reservationId'] ??
                uri.queryParameters['booking_id'] ??
                uri.queryParameters['bookingId'] ??
                '')
            .trim();
    final flightRequestId =
        (uri.queryParameters['flight_request_id'] ??
                uri.queryParameters['flightRequestId'] ??
                uri.queryParameters['request_id'] ??
                uri.queryParameters['requestId'] ??
                '')
            .trim();
    final checkoutSessionId =
        (uri.queryParameters['session_id'] ??
                uri.queryParameters['checkout_session_id'] ??
                uri.queryParameters['checkoutSessionId'] ??
                uri.queryParameters['sessionId'] ??
                '')
            .trim();
    final isFlightPaymentReturn =
        refreshTarget == 'flight_payment' ||
        refreshTarget == 'reservation_payment' ||
        reservationId.isNotEmpty ||
        flightRequestId.isNotEmpty;

    if (isFlightPaymentReturn) {
      if (ClientPaymentScreen.hasActiveReservationPaymentHandler) return;
      navigator.push(
        MaterialPageRoute(
          builder:
              (_) => ClientPaymentScreen(
                request: {
                  if (reservationId.isNotEmpty) 'reservation_id': reservationId,
                  if (reservationId.isNotEmpty) 'booking_id': reservationId,
                  if (flightRequestId.isNotEmpty)
                    'flight_request_id': flightRequestId,
                  if (checkoutSessionId.isNotEmpty)
                    'checkout_session_id': checkoutSessionId,
                },
                showBackButton: false,
                initialCheckoutReturnUri: uri,
                onPaymentComplete: () async {
                  final context = _navigatorKey.currentContext;
                  if (context == null) return;
                  await context
                      .read<ReservationProvider>()
                      .loadClientWorkspaceData(force: true);
                  final navigator = _navigatorKey.currentState;
                  if (navigator == null) return;
                  navigator.pushReplacement(
                    MaterialPageRoute(
                      builder:
                          (_) =>
                              const ClientHistoryScreen(showBackButton: false),
                    ),
                  );
                },
              ),
        ),
      );
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder:
            (_) => ClientPaymentScreen(
              request: const {},
              commercialAccessMode: true,
              showBackButton: false,
              initialCheckoutReturnUri: uri,
              onPaymentComplete: () async {
                final context = _navigatorKey.currentContext;
                if (context == null) return;
                await context
                    .read<AuthProvider>()
                    .refreshCommercialAccessStatus();
                if (!context.mounted) return;
                Navigator.of(context).pop();
                await context
                    .read<ReservationProvider>()
                    .loadClientWorkspaceData(force: true);
              },
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Red Sky',
      themeMode: ThemeMode.system,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [
        Locale('es', 'MX'),
        Locale('es'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGateScreen(),
    );
  }
}
