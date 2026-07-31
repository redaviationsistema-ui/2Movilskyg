import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/acceso_comercial_cliente.dart';
import '../../../core/cliente_api.dart';
import '../../../core/payment_authorization_state.dart';
import '../../../core/replay_guard.dart';
import '../../../core/stripe_checkout_flow.dart';
import '../../../providers/proveedor_autenticacion.dart';
import '../../../providers/proveedor_reservaciones.dart';
import 'client_access_payment_view.dart';
import 'client_flight_payment_view.dart';
import 'client_payment_shared_widgets.dart';
import 'pantalla_historial_cliente.dart';
import '../tema_cliente.dart';

const String kMobileCheckoutReturnScheme = 'redsky';
const String kMobileCheckoutReturnHost = 'cliente';
const String kMobileCheckoutReturnPath = '/pago';

class ClientPaymentScreen extends StatefulWidget {
  const ClientPaymentScreen({
    super.key,
    required this.request,
    required this.onPaymentComplete,
    this.onBack,
    this.onOpenTrips,
    this.commercialAccessMode = false,
    this.showBackButton = true,
    this.initialCheckoutReturnUri,
    this.onAircraftUnavailable,
  });

  final Map<String, dynamic> request;
  final VoidCallback onPaymentComplete;
  final VoidCallback? onBack;
  final VoidCallback? onOpenTrips;
  final bool commercialAccessMode;
  final bool showBackButton;
  final Uri? initialCheckoutReturnUri;
  final ValueChanged<Map<String, dynamic>>? onAircraftUnavailable;

  static int _activeCommercialAccessHandlers = 0;
  static int _activeReservationPaymentHandlers = 0;

  static bool get hasActiveCommercialAccessHandler =>
      _activeCommercialAccessHandlers > 0;

  static bool get hasActiveReservationPaymentHandler =>
      _activeReservationPaymentHandlers > 0;

  @override
  State<ClientPaymentScreen> createState() => _ClientPaymentScreenState();
}

class _ClientPaymentScreenState extends State<ClientPaymentScreen>
    with WidgetsBindingObserver {
  String _paymentMethod = 'link';
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _wireReferenceController =
      TextEditingController();
  final CardEditController _stripeCardController = CardEditController();
  CardFieldInputDetails? _cardDetails;
  final AppLinks _appLinks = AppLinks();
  bool _submitting = false;
  bool _isValidatingPayment = false;
  bool _checkoutCompleted = false;
  bool _openingReservationCheckout = false;
  bool _waitingForCommercialAccessReturn = false;
  bool _waitingForReservationCheckoutReturn = false;
  bool _showTripsShortcut = false;
  bool _forceNewCheckoutAfterValidation = false;
  bool _confirmedReservationRedirectScheduled = false;
  bool _stripeCardReady = false;
  bool _stripeCardLoading = false;
  String _inlineMessage = '';
  String _accessCheckoutSessionId = '';
  String _reservationCheckoutSessionId = '';
  String _reservationCheckoutFlightRequestId = '';
  String _reservationCheckoutReservationId = '';
  String _stripeCardError = '';
  final ReplayGuard _checkoutReturnReplayGuard = ReplayGuard();
  Map<String, dynamic>? _cardPaymentIntentSeed;
  StreamSubscription<Uri>? _appLinkSubscription;
  Timer? _reservationCheckoutOpeningTimer;
  Future<Map<String, dynamic>>? _lightweightPaymentRefreshFuture;
  DateTime? _lastLightweightPaymentRefreshAt;

  @override
  void initState() {
    super.initState();
    if (widget.commercialAccessMode) {
      ClientPaymentScreen._activeCommercialAccessHandlers++;
    } else {
      ClientPaymentScreen._activeReservationPaymentHandlers++;
    }
    WidgetsBinding.instance.addObserver(this);
    _emailController.addListener(_refresh);
    _wireReferenceController.addListener(_refresh);
    final auth = context.read<AuthProvider>();
    final initialEmail =
        auth.user?.email.trim().isNotEmpty == true
            ? auth.user!.email.trim()
            : _requestContactEmail(widget.request);
    if (initialEmail.isNotEmpty) {
      _emailController.text = initialEmail;
    }
    _bindCheckoutReturnLinks();
    final initialReturnUri = widget.initialCheckoutReturnUri;
    if (initialReturnUri != null) {
      unawaited(_handleIncomingCheckoutUri(initialReturnUri));
    }
    _syncContractWarningVisibility();
    if (!widget.commercialAccessMode &&
        !_contractAllowsPayment(widget.request)) {
      _scheduleRefreshSignedContractState();
    }
    if (_paymentMethod == 'card') {
      unawaited(_ensureStripeCardReady());
    }
    if (!widget.commercialAccessMode) {
      unawaited(_bootstrapReservationPaymentState());
    }
  }

  @override
  void didUpdateWidget(covariant ClientPaymentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.request, widget.request)) {
      _syncContractWarningVisibility();
      if (!widget.commercialAccessMode &&
          !_contractAllowsPayment(widget.request)) {
        _scheduleRefreshSignedContractState();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.removeListener(_refresh);
    _wireReferenceController.removeListener(_refresh);
    _emailController.dispose();
    _wireReferenceController.dispose();
    _stripeCardController.dispose();
    _appLinkSubscription?.cancel();
    _reservationCheckoutOpeningTimer?.cancel();
    if (widget.commercialAccessMode) {
      if (ClientPaymentScreen._activeCommercialAccessHandlers > 0) {
        ClientPaymentScreen._activeCommercialAccessHandlers--;
      }
    } else {
      if (ClientPaymentScreen._activeReservationPaymentHandlers > 0) {
        ClientPaymentScreen._activeReservationPaymentHandlers--;
      }
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!widget.commercialAccessMode) {
      unawaited(_refreshSignedContractState());
      if (_shouldValidateReservationPaymentOnReturn) {
        unawaited(_validateReservationCheckoutReturn());
      } else if (_waitingForReservationCheckoutReturn &&
          !_shouldValidateReservationPaymentOnReturn &&
          mounted) {
        setState(() {
          _waitingForReservationCheckoutReturn = false;
          if (_reservationCheckoutAwaitingCompletion) {
            _inlineMessage =
                'Tu reserva esta pendiente de pago. Abre Stripe Checkout para capturar tu tarjeta y continuar.';
          }
        });
      }
    }
    if (!_waitingForCommercialAccessReturn || !widget.commercialAccessMode) {
      return;
    }

    unawaited(_validateCommercialAccessAfterCheckout());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _redirectToTripsAfterConfirmedReservation({
    String? message,
  }) async {
    if (widget.commercialAccessMode || _confirmedReservationRedirectScheduled) {
      return;
    }

    _confirmedReservationRedirectScheduled = true;

    if (mounted && message != null && message.isNotEmpty) {
      setState(() {
        _inlineMessage = message;
      });
    }

    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    widget.onPaymentComplete();
  }

  Future<void> _ensureStripeCardReady({bool forceRefresh = false}) async {
    if (_paymentMethod != 'card') return;
    if (_stripeCardLoading) return;
    if (!forceRefresh && _stripeCardReady && _cardPaymentIntentSeed != null) {
      return;
    }

    if (mounted) {
      setState(() {
        _stripeCardLoading = true;
        _stripeCardError = '';
      });
    }

    try {
      late final Map<String, dynamic> intent;
      if (widget.commercialAccessMode) {
        intent = await _createCommercialAccessIntentSeed();
      } else {
        final flightRequestId = _flightRequestId(widget.request);
        final reservationId = _reservationId(widget.request);
        if (flightRequestId.isEmpty) {
          throw const ApiException(
            'No encontramos la reserva para preparar la tarjeta.',
          );
        }
        final effectiveReservationId = await _ensureReservationId(
          flightRequestId: flightRequestId,
          reservationId: reservationId,
          logPrefix: '[Pago]',
        );
        intent = await ApiClient.instance.createClientPaymentIntent(
          flightRequestId: flightRequestId,
          paymentPayload: {
            'contact_email': _emailController.text.trim(),
            'reservation_id': effectiveReservationId,
          },
        );
      }
      final publishableKey = _publishableKey(intent);
      final clientSecret = _clientSecret(intent);
      if (widget.commercialAccessMode &&
          (publishableKey.isEmpty || clientSecret.isEmpty) &&
          _checkoutUrl(intent).isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _cardPaymentIntentSeed = intent;
        });
        throw const ApiException(
          'Tu banco se validara en la pagina segura de Stripe.',
        );
      }
      if (publishableKey.isEmpty) {
        throw const ApiException(
          'El backend no devolvio la llave publica de Stripe para preparar la tarjeta.',
        );
      }
      if (clientSecret.isEmpty) {
        throw const ApiException(
          'El backend no devolvio client_secret para habilitar la tarjeta en este flujo.',
        );
      }

      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();

      if (!mounted) return;
      setState(() {
        _cardPaymentIntentSeed = intent;
        _stripeCardReady = true;
        _stripeCardError = '';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isAircraftNotAvailable) {
        context.read<ReservationProvider>().handleAircraftUnavailable(
          widget.request,
        );
        widget.onAircraftUnavailable?.call(widget.request);
      }
      setState(() {
        _stripeCardReady = false;
        _stripeCardError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stripeCardReady = false;
        _stripeCardError = 'No fue posible preparar Stripe: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _stripeCardLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _createCommercialAccessIntentSeed() {
    final backendSuccessUrl = _buildCommercialAccessBackendReturnUrl('success');
    final backendCancelUrl = _buildCommercialAccessBackendReturnUrl('cancel');
    return ApiClient.instance.createClientAccessCheckout(
      paymentPayload: {
        'contact_email': _contactEmail,
        'payment_method': 'card',
        'successUrl': backendSuccessUrl,
        'cancelUrl': backendCancelUrl,
      },
      successUrl: backendSuccessUrl,
      cancelUrl: backendCancelUrl,
      returnUrl: backendSuccessUrl,
    );
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.pop(context);
  }

  void _openTripsView() {
    if (widget.onOpenTrips != null) {
      widget.onOpenTrips!();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const ClientHistoryScreen(showBackButton: false),
      ),
    );
  }

  Future<void> _bindCheckoutReturnLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        unawaited(_handleIncomingCheckoutUri(initialUri));
      }
    } catch (_) {
      // Ignoramos errores de lectura inicial y conservamos el fallback por resume.
    }

    _appLinkSubscription = _appLinks.uriLinkStream.listen((uri) {
      unawaited(_handleIncomingCheckoutUri(uri));
    });
  }

  Future<void> _handleIncomingCheckoutUri(Uri uri) async {
    if (uri.scheme != kMobileCheckoutReturnScheme) return;
    if (uri.host != kMobileCheckoutReturnHost) return;
    if (uri.path != kMobileCheckoutReturnPath) return;
    final uriKey = uri.toString();
    if (!_checkoutReturnReplayGuard.accept(uriKey)) return;

    final returnContext = parseReservationCheckoutReturn(
      uri,
      fallbackSessionId:
          widget.commercialAccessMode
              ? _accessCheckoutSessionId
              : _effectiveCheckoutSessionId(widget.request),
      fallbackReservationId: _effectiveReservationId(widget.request),
      fallbackFlightRequestId: _effectiveFlightRequestId(widget.request),
    );
    final checkoutResult = returnContext.checkoutResult;
    final sessionId = returnContext.sessionId;

    if (!widget.commercialAccessMode) {
      if (returnContext.reservationId.isNotEmpty) {
        _reservationCheckoutReservationId = returnContext.reservationId;
        widget.request['reservation_id'] = returnContext.reservationId;
        widget.request['booking_id'] = returnContext.reservationId;
      }
      if (returnContext.flightRequestId.isNotEmpty) {
        _reservationCheckoutFlightRequestId = returnContext.flightRequestId;
        widget.request['flight_request_id'] = returnContext.flightRequestId;
      }
    }

    if (isStripeCheckoutSessionId(sessionId)) {
      if (widget.commercialAccessMode) {
        _accessCheckoutSessionId = sessionId;
      } else {
        _reservationCheckoutSessionId = sessionId;
      }
    }

    if (!mounted) return;

    if (!widget.commercialAccessMode) {
      if (!returnContext.hasReferenceIdentity) {
        setState(() {
          _waitingForReservationCheckoutReturn = false;
          _reservationCheckoutSessionId = '';
          _inlineMessage =
              'No encontramos una sesion activa de Stripe para validar. Abre Stripe Checkout nuevamente.';
        });
        return;
      }

      if (checkoutResult == 'cancel' || checkoutResult == 'cancelled') {
        await ApiClient.instance
            .cancelClientCheckout(
              sessionId: sessionId.isEmpty ? null : sessionId,
            )
            .catchError((_) => <String, dynamic>{});
        setState(() {
          _isValidatingPayment = false;
          _checkoutCompleted = false;
          _showTripsShortcut = false;
          _waitingForReservationCheckoutReturn = false;
          _inlineMessage =
              'Stripe Checkout fue cancelado. Puedes intentarlo de nuevo cuando quieras.';
        });
        return;
      }

      setState(() {
        _checkoutCompleted = true;
        _isValidatingPayment = true;
        _showTripsShortcut = false;
        _waitingForReservationCheckoutReturn = true;
        _inlineMessage = 'Stripe regreso a la app. Validando pago del vuelo...';
      });
      await _validateReservationCheckoutReturn();
      return;
    }

    if (checkoutResult == 'cancel' || checkoutResult == 'cancelled') {
      await ApiClient.instance
          .cancelClientAccessPayment(
            sessionId: sessionId.isEmpty ? null : sessionId,
          )
          .catchError((_) => <String, dynamic>{});
      if (!mounted) return;
      setState(() {
        _waitingForCommercialAccessReturn = false;
        _inlineMessage =
            'Stripe Checkout fue cancelado. Puedes intentarlo de nuevo cuando quieras.';
      });
      return;
    }

    setState(() {
      _waitingForCommercialAccessReturn = true;
      _inlineMessage = 'Stripe regreso a la app. Validando acceso comercial...';
    });
    await _validateCommercialAccessAfterCheckout();
  }

  String _buildCommercialAccessReturnUrl(
    String checkout, {
    bool includeStripeSessionPlaceholder = false,
  }) {
    if (includeStripeSessionPlaceholder) {
      return Uri(
        scheme: kMobileCheckoutReturnScheme,
        host: kMobileCheckoutReturnHost,
        path: kMobileCheckoutReturnPath,
        queryParameters: {
          'checkout': checkout,
          'session_id': '{CHECKOUT_SESSION_ID}',
          'refresh': 'commercial_access',
        },
      ).toString();
    }

    return Uri(
      scheme: kMobileCheckoutReturnScheme,
      host: kMobileCheckoutReturnHost,
      path: kMobileCheckoutReturnPath,
      queryParameters: {
        'checkout': checkout,
        if (_accessCheckoutSessionId.trim().isNotEmpty)
          'session_id': _accessCheckoutSessionId.trim(),
        'refresh': 'commercial_access',
      },
    ).toString();
  }

  String _buildCommercialAccessBackendReturnUrl(String checkout) {
    final baseUri = Uri.tryParse(ApiClient.instance.baseUrl);
    if (baseUri == null || baseUri.scheme.isEmpty || baseUri.host.isEmpty) {
      return _buildCommercialAccessReturnUrl(
        checkout,
        includeStripeSessionPlaceholder: true,
      );
    }

    final basePath = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    final normalizedCheckout = checkout == 'cancel' ? 'cancelled' : checkout;

    return Uri.parse(
          '${baseUri.origin}$basePath/client/access-payment/mobile-return',
        )
        .replace(
          queryParameters: {
            'checkout': normalizedCheckout,
            'session_id': '{CHECKOUT_SESSION_ID}',
            'refresh': 'commercial_access',
          },
        )
        .toString();
  }

  String _buildReservationPaymentBackendReturnUrl(String checkout) {
    return buildReservationPaymentBackendReturnUrl(
      baseUrl: ApiClient.instance.baseUrl,
      checkout: checkout,
      reservationId:
          _reservationCheckoutReservationId.isNotEmpty
              ? _reservationCheckoutReservationId
              : _effectiveReservationId(widget.request),
      flightRequestId:
          _reservationCheckoutFlightRequestId.isNotEmpty
              ? _reservationCheckoutFlightRequestId
              : _effectiveFlightRequestId(widget.request),
      scheme: kMobileCheckoutReturnScheme,
      host: kMobileCheckoutReturnHost,
      path: kMobileCheckoutReturnPath,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accessData = context.watch<AuthProvider>().accessData;
    final commercialState = resolveCommercialAccessState(accessData);
    final commercialAccessActive =
        widget.commercialAccessMode && commercialState.isConfirmedActive;
    final paymentBreakdown =
        commercialAccessActive
            ? const <PaymentBreakdownItem>[]
            : widget.commercialAccessMode
            ? _commercialAccessBreakdown(accessData, widget.request)
            : _reservationPaymentBreakdown(widget.request);
    final amount =
        commercialAccessActive
            ? 'Acceso activo'
            : widget.commercialAccessMode
            ? (_breakdownTotalLabel(paymentBreakdown) ?? 'USD \$115 / mes')
            : (_breakdownTotalLabel(paymentBreakdown) ??
                _amountLabel(widget.request));
    final route =
        widget.commercialAccessMode
            ? 'Activa el acceso comercial para reservar, firmar contrato y pagar vuelos.'
            : _routeLabel(widget.request);
    final passengerCount = (widget.request['passengers'] ?? '1').toString();
    final reservationPaymentConfirmed =
        !widget.commercialAccessMode &&
        _requestIndicatesPaymentConfirmed(widget.request);
    final reservationPaymentPending =
        !widget.commercialAccessMode &&
        !reservationPaymentConfirmed &&
        _requestHasStripeCheckoutSession(widget.request, includeLocal: false) &&
        _requestIndicatesPaymentPending(widget.request);
    final reservationCheckoutNeedsRegeneration =
        !widget.commercialAccessMode &&
        reservationPaymentPending &&
        _requestRequiresNewCheckoutSession(widget.request);
    final checkoutStatus =
        commercialAccessActive
            ? 'Acceso confirmado'
            : _waitingForReservationCheckoutReturn || _submitting
            ? 'Validando pago con Stripe'
            : reservationPaymentConfirmed
            ? 'Pago confirmado'
            : reservationCheckoutNeedsRegeneration
            ? 'Necesita un enlace nuevo'
            : reservationPaymentPending
            ? 'Pago pendiente de confirmacion'
            : 'Listo para abrir enlace seguro';
    final checkoutDescription =
        commercialAccessActive
            ? 'El backend ya confirmo tu acceso comercial. Ya puedes volver a cotizar o regresar al inicio.'
            : widget.commercialAccessMode && _waitingForCommercialAccessReturn
            ? 'Stripe ya regreso a la app. Estamos verificando el pago con el backend antes de habilitar tu acceso.'
            : reservationPaymentConfirmed
            ? 'El backend ya reflejo el pago. Tu reserva puede avanzar al siguiente paso operativo.'
            : reservationCheckoutNeedsRegeneration
            ? 'El checkout anterior de Stripe ya cerro o vencio. Generaremos un enlace nuevo y validaremos otra vez antes de avanzar.'
            : reservationPaymentPending
            ? 'Stripe recibio el checkout, pero el backend aun esta validando el pago. Actualizaremos la reserva al confirmarse.'
            : 'El cobro se completa fuera de la app en Stripe. Al terminar, volveras automaticamente para validar tu reserva.';
    final commercialHeadline =
        commercialAccessActive
            ? 'Acceso comercial activo'
            : commercialState.isExpired || commercialState.isSuspended
            ? 'Reactiva tu acceso comercial'
            : commercialState.isPastDue
            ? 'Actualiza tu pago'
            : 'Configura tu pago';
    final commercialSubheadline =
        commercialAccessActive
            ? (commercialState.expiresAtLabel.isNotEmpty
                ? 'Vigente hasta ${commercialState.expiresAtLabel}'
                : 'Tu pago fue confirmado')
            : commercialState.isExpired || commercialState.isSuspended
            ? (commercialState.expiresAtLabel.isNotEmpty
                ? 'Tu acceso vencio el ${commercialState.expiresAtLabel}'
                : 'Tu acceso comercial esta vencido')
            : commercialState.isPastDue
            ? 'Tu cuenta sigue operativa temporalmente mientras corriges el cobro.'
            : 'Acceso comercial premium';
    final commercialStatusCaption =
        commercialAccessActive
            ? 'Tu pago fue confirmado'
            : _waitingForCommercialAccessReturn ||
                _commercialAccessNeedsValidation
            ? 'Verificando pago con Stripe y backend'
            : commercialState.isExpired || commercialState.isSuspended
            ? 'Completa el pago mediante Stripe para volver a cotizar y reservar vuelos.'
            : commercialState.isPastDue
            ? 'Actualiza el metodo de pago en Stripe para mantener el acceso sin interrupciones.'
            : 'Renovacion mensual protegida con Stripe Checkout.';

    final ctaLabel =
        _openingReservationCheckout
            ? 'Abriendo Stripe Checkout...'
            : _showTripsShortcut
            ? 'Ir a Tus vuelos'
            : _reservationCheckoutNeedsRegeneration
            ? 'Generar nuevo enlace'
            : _reservationPaymentConfirmed
            ? 'Ir a Tus vuelos'
            : widget.commercialAccessMode && _submitting
            ? 'Procesando...'
            : _reservationCheckoutAwaitingCompletion
            ? 'Abrir Stripe Checkout'
            : _reservationRequiresValidation
            ? 'Validando pago...'
            : widget.commercialAccessMode && commercialAccessActive
            ? 'Continuar a cotizar'
            : widget.commercialAccessMode && _commercialAccessNeedsValidation
            ? 'Verificar pago'
            : widget.commercialAccessMode
            ? 'Continuar con Stripe'
            : 'Abrir Stripe Checkout';

    if (widget.commercialAccessMode) {
      return ClientAccessPaymentView(
        showBackButton: widget.showBackButton,
        hasCustomBack: widget.onBack != null,
        onBack: _handleBack,
        commercialAccessActive: commercialAccessActive,
        headline: commercialHeadline,
        subheadline: commercialSubheadline,
        statusCaption: commercialStatusCaption,
        amount: amount,
        paymentBreakdown: paymentBreakdown,
        checkoutDescription: checkoutDescription,
        checkoutStatus: checkoutStatus,
        paymentMethodSummaryLabel: _paymentMethodSummaryLabel(),
        showCommercialCardPaymentOption: _showCommercialCardPaymentOption,
        paymentMethod: _paymentMethod,
        cardPaymentPanel: _buildCardPaymentPanel(),
        linkPaymentPanel: _buildLinkPaymentPanel(),
        onSelectCard: () {
          setState(() {
            _paymentMethod = 'card';
            _inlineMessage = '';
          });
          unawaited(_ensureStripeCardReady());
        },
        onSelectLink: () {
          setState(() {
            _paymentMethod = 'link';
            _inlineMessage = '';
          });
        },
        inlineMessage: _inlineMessage,
        messageColor: _messageColor(),
        emailController: _emailController,
        ctaLabel: ctaLabel,
        onPrimaryAction: () => unawaited(_handlePrimaryAction()),
        isPrimaryEnabled: _resolvePrimaryAction(),
        isLoading: _submitting,
      );
    }

    return ClientFlightPaymentView(
      showBackButton: widget.showBackButton,
      hasCustomBack: widget.onBack != null,
      onBack: _handleBack,
      amount: amount,
      route: route,
      passengerCount: passengerCount,
      aircraftLabel: _paymentAircraftLabel(widget.request),
      departureLabel: _paymentDepartureLabel(widget.request),
      paymentBreakdown: paymentBreakdown,
      checkoutDescription: checkoutDescription,
      checkoutStatus: checkoutStatus,
      reservationPaymentConfirmed: reservationPaymentConfirmed,
      waitingForReservationCheckoutReturn: _waitingForReservationCheckoutReturn,
      submitting: _submitting,
      paymentMethod: _paymentMethod,
      inlineMessage: _inlineMessage,
      messageColor: _messageColor(),
      emailController: _emailController,
      cardPaymentPanel: _buildCardPaymentPanel(),
      linkPaymentPanel: _buildLinkPaymentPanel(),
      onSelectCard: () {
        setState(() {
          _paymentMethod = 'card';
          _inlineMessage = '';
        });
        unawaited(_ensureStripeCardReady());
      },
      onSelectLink: () {
        setState(() {
          _paymentMethod = 'link';
          _inlineMessage = '';
        });
      },
      showTripsShortcut: _showTripsShortcut,
      onOpenTrips: _openTripsView,
      ctaLabel: ctaLabel,
      onPrimaryAction: () => unawaited(_handlePrimaryAction()),
      isPrimaryEnabled: _resolvePrimaryAction(),
      isLoading: _openingReservationCheckout || _isValidatingPayment,
    );
  }

  String _paymentAircraftLabel(Map<String, dynamic> request) {
    final data = _asStringKeyMap(request['data']);
    final reservation = _asStringKeyMap(request['reservation']);
    final aircraft = _asStringKeyMap(request['aircraft']);
    final snapshot = _asStringKeyMap(request['aircraft_snapshot']);
    return _firstTextFromMaps(
          const [
            'aircraft_name',
            'aircraft_model',
            'assigned_aircraft_model',
            'model',
            'name',
          ],
          [request, data, reservation, aircraft, snapshot],
        ).trim().isNotEmpty
        ? _firstTextFromMaps(
          const [
            'aircraft_name',
            'aircraft_model',
            'assigned_aircraft_model',
            'model',
            'name',
          ],
          [request, data, reservation, aircraft, snapshot],
        )
        : 'Jet privado';
  }

  String _paymentDepartureLabel(Map<String, dynamic> request) {
    final data = _asStringKeyMap(request['data']);
    final reservation = _asStringKeyMap(request['reservation']);
    final raw = _firstTextFromMaps(
      const [
        'departure_datetime',
        'start_datetime',
        'departure_at',
        'scheduled_at',
        'date',
      ],
      [request, data, reservation],
    );
    if (raw.trim().isEmpty) return 'Salida por confirmar';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.day} ${months[parsed.month - 1]} · $hour:$minute $suffix';
  }

  Widget _buildCardPaymentPanel() {
    if (_stripeCardLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    if (!_stripeCardReady) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ClientThemeColors.brandNavy,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF29445A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Stripe aun no esta listo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _stripeCardError.isNotEmpty
                    ? _stripeCardError
                    : widget.commercialAccessMode
                    ? 'Estamos preparando el formulario seguro de tarjeta para activar tu acceso.'
                    : 'Estamos preparando el campo seguro de tarjeta.',
                style: const TextStyle(
                  color: Color(0xFFD5E2EE),
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed:
                    () => unawaited(_ensureStripeCardReady(forceRefresh: true)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF8BA4B8)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: ClientThemeColors.brandNavy,
            borderRadius: BorderRadius.circular(20),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final titleFontSize =
                  (maxWidth * 0.06).clamp(16.0, 20.0).toDouble();
              final subtitleFontSize =
                  (maxWidth * 0.038).clamp(12.0, 14.0).toDouble();
              final numberFontSize =
                  (maxWidth * 0.082).clamp(18.0, 28.0).toDouble();
              final chipFontSize =
                  (maxWidth * 0.034).clamp(11.0, 13.0).toDouble();
              final fieldFontSize =
                  (maxWidth * 0.042).clamp(14.0, 16.0).toDouble();
              final compactSpacing = maxWidth < 340;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tarjeta Corporativa',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Visa / Mastercard / Amex',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xFFD5E2EE),
                                fontWeight: FontWeight.w700,
                                fontSize: subtitleFontSize,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: compactSpacing ? 10 : 12,
                            vertical: compactSpacing ? 6 : 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _cardBrandLabel(),
                              maxLines: 1,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: chipFontSize,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compactSpacing ? 18 : 22),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: compactSpacing ? 14 : 16,
                      vertical: compactSpacing ? 16 : 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        CardBrandMark(brand: _cardBrand()),
                        SizedBox(width: compactSpacing ? 10 : 14),
                        Expanded(
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _cardProgressivePreview(),
                              maxLines: 1,
                              style: TextStyle(
                                color: const Color(0xFFF5B0A8),
                                fontWeight: FontWeight.w800,
                                fontSize: numberFontSize,
                                letterSpacing: compactSpacing ? 0.6 : 0.9,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compactSpacing ? 14 : 18),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: compactSpacing ? 12 : 14,
                      vertical: compactSpacing ? 16 : 18,
                    ),
                    child: CardField(
                      controller: _stripeCardController,
                      enablePostalCode: false,
                      // Se usa solo para renderizar la vista previa dinamica.
                      dangerouslyGetFullCardDetails: true,
                      cursorColor: const Color(0xFFF5B0A8),
                      numberHintText: '1234 5678 9012 3456',
                      expirationHintText: 'MM/AA',
                      cvcHintText: 'CVC',
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintStyle: TextStyle(
                          color: const Color(0xFF8FA1B3),
                          fontSize: fieldFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onCardChanged: (details) {
                        setState(() {
                          _cardDetails = details;
                          if ((details?.complete ?? false) &&
                              _inlineMessage.startsWith(
                                'Completa correctamente los datos',
                              )) {
                            _inlineMessage = '';
                          }
                        });
                      },
                      style: TextStyle(
                        color: const Color(0xFF17324A),
                        fontSize: fieldFontSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: compactSpacing ? 14 : 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: CardMetaItem(
                          label: 'Titular',
                          value: _cardHolderPreview(),
                          alignEnd: false,
                        ),
                      ),
                      SizedBox(width: compactSpacing ? 10 : 12),
                      Expanded(
                        child: CardMetaItem(
                          label: 'Vencimiento',
                          value: _expiryPreview(),
                          alignEnd: true,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLinkPaymentPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SizedBox(height: 12),
        Text(
          'Abrimos Stripe Checkout para que agregues tu tarjeta y actives la suscripcion mensual en un entorno seguro.',
          style: TextStyle(
            color: Color(0xFF625D55),
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  bool get _canSubmit {
    if (widget.commercialAccessMode) {
      if (_commercialAccessAlreadyActive) return true;
      if (_commercialAccessNeedsValidation) return true;
      if (!_hasValidContactEmail) return false;
      if (_paymentMethod == 'card') return _cardDetails?.complete ?? false;
      return true;
    }
    if (!_hasPaymentIdentity) return false;
    if (_paymentMethod == 'link') return true;
    if (_contactEmail.isNotEmpty && !_hasValidContactEmail) return false;
    if (_paymentMethod == 'card') {
      return _cardDetails?.complete ?? false;
    }
    return _wireReferenceController.text.trim().isNotEmpty;
  }

  bool get _reservationPaymentConfirmed =>
      !widget.commercialAccessMode &&
      _requestIndicatesPaymentConfirmed(widget.request);

  bool get _reservationPaymentPending =>
      !widget.commercialAccessMode &&
      !_reservationPaymentConfirmed &&
      _requestIndicatesPaymentPending(widget.request);

  bool get _reservationCheckoutNeedsRegeneration =>
      !widget.commercialAccessMode &&
      ((_requestIndicatesPaymentPending(widget.request) &&
              _requestRequiresNewCheckoutSession(widget.request)) ||
          _forceNewCheckoutAfterValidation);

  bool get _reservationCheckoutAwaitingCompletion =>
      !widget.commercialAccessMode &&
      _reservationPaymentPending &&
      _requestHasReusableStripeCheckoutSession(widget.request) &&
      _paymentIntentId(widget.request).trim().isEmpty &&
      !_waitingForReservationCheckoutReturn;

  bool get _reservationRequiresValidation =>
      !widget.commercialAccessMode &&
      (_isValidatingPayment ||
          (_waitingForReservationCheckoutReturn &&
              (_checkoutCompleted ||
                  _requestHasCheckoutReturnSuccess(widget.request) ||
                  _hasReservationPaymentIntent(widget.request) ||
                  _requestIndicatesPaymentConfirmed(widget.request))));

  bool get _shouldValidateReservationPaymentOnReturn =>
      !widget.commercialAccessMode &&
      _waitingForReservationCheckoutReturn &&
      (_requestHasCheckoutReturnSuccess(widget.request) ||
          _requestIndicatesPaymentConfirmed(widget.request) ||
          _hasReservationPaymentIntent(widget.request));

  bool _resolvePrimaryAction() {
    if (_submitting) return false;
    if (widget.commercialAccessMode && _commercialAccessAlreadyActive) {
      return true;
    }
    if (widget.commercialAccessMode) return _canSubmit;
    if (_showTripsShortcut) return true;
    if (_reservationCheckoutNeedsRegeneration) return _canSubmit;
    if (_reservationPaymentConfirmed) return true;
    if (_reservationCheckoutAwaitingCompletion) return true;
    if (_reservationRequiresValidation) return false;
    return _canSubmit;
  }

  Future<void> _handlePrimaryAction() async {
    if (!widget.commercialAccessMode && _showTripsShortcut) {
      _openTripsView();
      return;
    }
    if (!widget.commercialAccessMode && _reservationCheckoutNeedsRegeneration) {
      await _submitReservationCheckoutLink(forceRecreate: true);
      return;
    }
    if (!widget.commercialAccessMode && _reservationPaymentConfirmed) {
      _openTripsView();
      return;
    }
    if (!widget.commercialAccessMode &&
        _reservationCheckoutAwaitingCompletion) {
      await _openReservationExistingCheckout();
      return;
    }
    if (!widget.commercialAccessMode && _reservationRequiresValidation) {
      await _validateReservationCheckoutReturn();
      return;
    }
    await _submitPayment();
  }

  bool get _hasValidContactEmail {
    final email = _contactEmail;
    if (email.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  String get _contactEmail => _emailController.text.trim().toLowerCase();

  bool get _hasPaymentIdentity =>
      _flightRequestId(widget.request).isNotEmpty ||
      _reservationId(widget.request).isNotEmpty ||
      (widget.request['id']?.toString().trim().isNotEmpty ?? false);

  bool get _showCommercialCardPaymentOption => false;

  bool get _commercialAccessAlreadyActive {
    final state = resolveCommercialAccessState(
      context.read<AuthProvider>().accessData,
    );
    return state.isConfirmedActive;
  }

  bool get _commercialAccessNeedsValidation {
    if (!widget.commercialAccessMode) return false;
    if (_waitingForCommercialAccessReturn) return true;
    if (_accessCheckoutSessionId.trim().isNotEmpty) return true;
    final message = _inlineMessage.toLowerCase();
    return message.contains('stripe regreso') ||
        message.contains('validando acceso') ||
        message.contains('aun no confirma el acceso') ||
        message.contains('pago esta en validacion') ||
        message.contains('pago en validacion');
  }

  Future<void> _submitPayment() async {
    if (widget.commercialAccessMode) {
      if (_commercialAccessAlreadyActive) {
        widget.onPaymentComplete();
        return;
      }
      if (_paymentMethod == 'card') {
        await _submitCommercialAccessCardPayment();
      } else {
        if (_commercialAccessNeedsValidation) {
          await _validateCommercialAccessAfterCheckout();
        } else {
          await _submitCommercialAccessPayment();
        }
      }
      return;
    }
    if (_paymentMethod == 'link') {
      if (_waitingForReservationCheckoutReturn) {
        setState(() {
          _inlineMessage = 'Validando el regreso de Stripe...';
        });
        _showCheckoutFeedback('Validando el regreso de Stripe...');
        await _validateReservationCheckoutReturn();
      } else if (_requestIndicatesPaymentPending(widget.request) ||
          _reservationCheckoutAwaitingCompletion ||
          isStripeCheckoutSessionId(_reservationCheckoutSessionId)) {
        setState(() {
          _inlineMessage = 'Abriendo Stripe Checkout...';
        });
        _showCheckoutFeedback('Abriendo Stripe Checkout...');
        await _submitReservationCheckoutLink(forceRecreate: true);
      } else {
        setState(() {
          _inlineMessage = 'Preparando Stripe Checkout...';
        });
        _showCheckoutFeedback('Preparando Stripe Checkout...');
        await _submitReservationCheckoutLink();
      }
      return;
    }

    final flightRequestId = _flightRequestId(widget.request);
    final reservationId = _reservationId(widget.request);
    final customerName = _customerName(context);
    final reservationProvider = context.read<ReservationProvider>();
    if (flightRequestId.isEmpty) {
      setState(() {
        _inlineMessage = 'No encontramos la reserva para iniciar el pago.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _inlineMessage =
          _paymentMethod == 'wire'
              ? 'Generando referencia bancaria...'
              : 'Pago seguro...';
    });

    try {
      final effectiveReservationId = await _ensureReservationId(
        flightRequestId: flightRequestId,
        reservationId: reservationId,
        logPrefix: '[Pago]',
      );
      if (_paymentMethod == 'wire') {
        final payload = await ApiClient.instance.createClientWireIntent(
          flightRequestId: flightRequestId,
          paymentPayload: {
            'contact_email': _emailController.text.trim(),
            'payment_method': 'wire',
            'reference_note': _wireReferenceController.text.trim(),
            'reservation_id': effectiveReservationId,
          },
        );
        final instructions = _extractWireInstructions(payload);
        if (!mounted) return;
        setState(() {
          _inlineMessage =
              instructions.isEmpty
                  ? 'Transferencia preparada. El pago queda pendiente hasta validar el comprobante.'
                  : 'Transferencia preparada.\n${_wireInstructionText(instructions)}';
        });
        return;
      }

      if (_paymentMethod == 'card') {
        await _ensureStripeCardReady();
        if (!_stripeCardReady) {
          throw ApiException(
            _stripeCardError.isNotEmpty
                ? _stripeCardError
                : 'Stripe no esta listo para capturar la tarjeta.',
          );
        }
      }

      final intent =
          _paymentMethod == 'card' && _cardPaymentIntentSeed != null
              ? Map<String, dynamic>.from(_cardPaymentIntentSeed!)
              : await ApiClient.instance.createClientPaymentIntent(
                flightRequestId: flightRequestId,
                paymentPayload: {
                  'contact_email': _emailController.text.trim(),
                  'reservation_id': effectiveReservationId,
                },
              );
      var status = _paymentStatus(intent);
      final clientSecret = _clientSecret(intent);
      final publishableKey = _publishableKey(intent);

      if (!(_cardDetails?.complete ?? false)) {
        throw const ApiException(
          'Completa correctamente los datos de la tarjeta antes de continuar.',
        );
      }

      if (status != 'succeeded' &&
          status != 'paid' &&
          clientSecret.isNotEmpty) {
        if (publishableKey.isEmpty) {
          throw const ApiException(
            'El backend no devolvio la llave publica de Stripe para confirmar el pago.',
          );
        }

        Stripe.publishableKey = publishableKey;
        await Stripe.instance.applySettings();

        final paymentIntent = await Stripe.instance.confirmPayment(
          paymentIntentClientSecret: clientSecret,
          data: PaymentMethodParams.card(
            paymentMethodData: PaymentMethodData(
              billingDetails: BillingDetails(
                name: customerName,
                email: _emailController.text.trim(),
              ),
            ),
          ),
        );
        status = paymentIntent.status.name.toLowerCase();
      }

      if (status == 'succeeded' || status == 'paid') {
        await reservationProvider.loadClientWorkspaceData(force: true);
        final backendSnapshot = _matchingRequestFromProvider(
          reservationProvider,
        );
        if (!_requestIndicatesPaymentConfirmed(backendSnapshot)) {
          if (!mounted) return;
          setState(() {
            _inlineMessage =
                'Stripe recibio el pago. Esperando confirmacion final del backend.';
          });
          return;
        }
        if (!mounted) return;
        await _redirectToTripsAfterConfirmedReservation(
          message: 'Pago confirmado. Abriendo tus vuelos...',
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _inlineMessage =
            clientSecret.isEmpty
                ? 'El backend preparo el pago, pero no devolvio client_secret para abrir Stripe en movil.'
                : 'Stripe recibio el pago. Esperando confirmacion final.';
      });
    } on StripeException catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineMessage =
            error.error.localizedMessage ?? 'Stripe no pudo confirmar el pago.';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _inlineMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _inlineMessage = 'No fue posible procesar el pago: $error',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitCommercialAccessPayment() async {
    setState(() {
      _submitting = true;
      _inlineMessage = 'Preparando Stripe Checkout...';
    });

    try {
      final auth = context.read<AuthProvider>();
      final backendSuccessUrl = _buildCommercialAccessBackendReturnUrl(
        'success',
      );
      final backendCancelUrl = _buildCommercialAccessBackendReturnUrl('cancel');
      final payload = await ApiClient.instance.createClientAccessCheckout(
        paymentPayload: {
          'contact_email': _contactEmail,
          'customer_email': _contactEmail,
          'email': _contactEmail,
          'payment_method': 'stripe_checkout',
          'successUrl': backendSuccessUrl,
          'cancelUrl': backendCancelUrl,
        },
        successUrl: backendSuccessUrl,
        cancelUrl: backendCancelUrl,
        returnUrl: backendSuccessUrl,
      );

      auth.syncAccessState(payload);

      if (_accessIsActive(payload) ||
          _isTruthyValue(payload['already_active'])) {
        if (!mounted) return;
        setState(() {
          _waitingForCommercialAccessReturn = false;
          _inlineMessage = 'Acceso comercial activado.';
        });
        widget.onPaymentComplete();
        return;
      }

      _accessCheckoutSessionId = _firstText(payload, const [
        'session_id',
        'checkout_session_id',
        'checkoutSessionId',
      ]);

      final redirectUrl =
          (payload['management_url'] ??
                  payload['checkout_url'] ??
                  payload['managementUrl'] ??
                  payload['checkoutUrl'] ??
                  ((payload['data'] is Map)
                      ? (payload['data']['management_url'] ??
                          payload['data']['checkout_url'] ??
                          payload['data']['managementUrl'] ??
                          payload['data']['checkoutUrl'])
                      : null) ??
                  '')
              .toString()
              .trim();

      if (redirectUrl.isEmpty) {
        throw const ApiException(
          'El backend no devolvio la URL de Stripe para activar el acceso comercial.',
        );
      }

      final opened = await _openStripeCheckoutUrl(redirectUrl);

      if (!opened) {
        throw const ApiException('No fue posible abrir Stripe Checkout.');
      }

      if (!mounted) return;
      setState(() {
        _waitingForCommercialAccessReturn = true;
        _inlineMessage =
            'Stripe Checkout abierto. Cuando regreses a la app validaremos tu acceso comercial.';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _inlineMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(
        () =>
            _inlineMessage =
                'No fue posible iniciar el acceso comercial: $error',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitCommercialAccessCardPayment() async {
    setState(() {
      _submitting = true;
      _inlineMessage = 'Preparando tarjeta segura con Stripe...';
    });

    try {
      final customerName = _customerName(context);
      await _ensureStripeCardReady();
      final seed = _cardPaymentIntentSeed;
      if (!_stripeCardReady || seed == null) {
        final fallbackUrl = seed == null ? '' : _checkoutUrl(seed);
        if (fallbackUrl.isNotEmpty) {
          await _openCommercialAccessCheckoutUrl(fallbackUrl);
          return;
        }
        throw ApiException(
          _stripeCardError.isNotEmpty
              ? _stripeCardError
              : 'Stripe no esta listo para capturar la tarjeta.',
        );
      }

      if (!(_cardDetails?.complete ?? false)) {
        throw const ApiException(
          'Completa correctamente los datos de la tarjeta antes de continuar.',
        );
      }

      final intent = Map<String, dynamic>.from(seed);
      final clientSecret = _clientSecret(intent);
      final publishableKey = _publishableKey(intent);
      var status = _paymentStatus(intent);

      if (clientSecret.isEmpty) {
        final fallbackUrl = _checkoutUrl(intent);
        if (fallbackUrl.isNotEmpty) {
          await _openCommercialAccessCheckoutUrl(fallbackUrl);
          return;
        }
        throw const ApiException(
          'El backend no devolvio client_secret para confirmar el acceso comercial con tarjeta.',
        );
      }
      if (publishableKey.isEmpty) {
        throw const ApiException(
          'El backend no devolvio la llave publica de Stripe para confirmar la tarjeta.',
        );
      }

      if (status != 'succeeded' && status != 'paid') {
        Stripe.publishableKey = publishableKey;
        await Stripe.instance.applySettings();

        final paymentIntent = await Stripe.instance.confirmPayment(
          paymentIntentClientSecret: clientSecret,
          data: PaymentMethodParams.card(
            paymentMethodData: PaymentMethodData(
              billingDetails: BillingDetails(
                name: customerName,
                email: _contactEmail,
              ),
            ),
          ),
        );
        status = paymentIntent.status.name.toLowerCase();
      }

      if (status == 'succeeded' || status == 'paid') {
        final active = await _waitForCommercialAccessActivation();
        if (!mounted) return;
        if (active) {
          setState(() => _inlineMessage = 'Acceso comercial activado.');
          widget.onPaymentComplete();
          return;
        }

        setState(() {
          _inlineMessage =
              'Stripe confirmo la tarjeta, pero el backend aun no refleja el acceso. Intenta validar de nuevo en unos segundos.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _inlineMessage =
            'Stripe recibio la tarjeta. Esperando confirmacion final del acceso comercial.';
      });
    } on StripeException catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineMessage =
            error.error.localizedMessage ??
            'Stripe no pudo confirmar la tarjeta.';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _inlineMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineMessage = 'No fue posible activar el acceso con tarjeta: $error';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openCommercialAccessCheckoutUrl(String redirectUrl) async {
    final opened = await _openStripeCheckoutUrl(redirectUrl);

    if (!opened) {
      throw const ApiException('No fue posible abrir Stripe Checkout.');
    }

    if (!mounted) return;
    setState(() {
      _waitingForCommercialAccessReturn = true;
      _inlineMessage =
          'Stripe Checkout abierto. Cuando regreses a la app validaremos tu acceso comercial.';
    });
  }

  Future<void> _submitReservationCheckoutLink({
    bool forceRecreate = false,
  }) async {
    if (_reservationPaymentConfirmed) {
      setState(() {
        _inlineMessage =
            'La reserva ya fue pagada y confirmada. Ya no es necesario abrir Stripe Checkout nuevamente.';
      });
      return;
    }

    if (_reservationCheckoutAwaitingCompletion && !forceRecreate) {
      await _openReservationExistingCheckout();
      return;
    }

    final flightRequestId = _flightRequestId(widget.request);
    final reservationId = _reservationId(widget.request);
    final effectiveFlightRequestId =
        flightRequestId.isNotEmpty ? flightRequestId : reservationId;
    final reservationProvider = context.read<ReservationProvider>();
    if (effectiveFlightRequestId.isEmpty) {
      setState(() {
        _inlineMessage =
            'No encontramos la reserva para abrir el link de pago.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _openingReservationCheckout = true;
      _inlineMessage = 'Preparando link de pago...';
    });
    _scheduleReservationCheckoutOpeningTimeout();

    try {
      final effectiveReservationId =
          reservationId.isNotEmpty
              ? reservationId
              : await _ensureReservationId(
                flightRequestId: effectiveFlightRequestId,
                reservationId: reservationId,
                logPrefix: '[Pago]',
              );
      _reservationCheckoutFlightRequestId = effectiveFlightRequestId;
      _reservationCheckoutReservationId = effectiveReservationId;
      final paymentPayload = _reservationCheckoutPayload(
        reservationId: effectiveReservationId,
      );
      final authorizationQuery = <String, String>{
        'reservation_id': effectiveReservationId,
        if (effectiveFlightRequestId.trim().isNotEmpty)
          'flight_request_id': effectiveFlightRequestId.trim(),
      };
      debugPrint(
        '[Pago][PreCheckout] GET ${_apiLogUrl('/cliente/reservas/$effectiveReservationId/payment-authorization', query: authorizationQuery)} '
        'reservation_id=$effectiveReservationId '
        'flight_request_id=$effectiveFlightRequestId',
      );
      final authorizationPayload = await ApiClient.instance
          .getClientPaymentAuthorization(
            reservationId: effectiveReservationId,
            flightRequestId: effectiveFlightRequestId,
          );
      debugPrint(
        '[Pago][PreCheckout] GET /cliente/reservas/$effectiveReservationId/payment-authorization '
        'status=200 '
        'reservation_id=$effectiveReservationId '
        'flight_request_id=$effectiveFlightRequestId '
        'message=${_backendErrorMessage(authorizationPayload)}',
      );
      final authorization = PaymentAuthorizationState.fromBackend(
        authorizationPayload,
      );
      debugPrint(
        '[Pago][PreCheckout] authorized=${authorization.isAuthorized} '
        'can_pay=${authorization.canPay} '
        'aircraft_available=${authorization.aircraftAvailable} '
        'blocking_reasons=${jsonEncode(authorization.blockingReasons)}',
      );
      if (authorization.hasInconsistentAvailabilityPayload) {
        debugPrint(
          '[Pago][PreCheckout][Warning] Payload inconsistente: '
          'authorized=true, can_pay=true, aircraft_available=false',
        );
      }
      if (!authorization.isAuthorized ||
          !authorization.canPay ||
          authorization.blockingReasons.isNotEmpty) {
        if (authorization.blockingReasons.contains('AIRCRAFT_NOT_AVAILABLE')) {
          throw ApiException(
            authorization.message,
            statusCode: 409,
            payload: const {
              'code': 'AIRCRAFT_NOT_AVAILABLE',
              'source': 'local_validation',
            },
          );
        }
        throw ApiException(
          authorization.message,
          statusCode: 403,
          payload: const {
            'code': 'PAYMENT_NOT_AUTHORIZED',
            'source': 'local_validation',
          },
        );
      }
      debugPrint(
        '[Pago][PreCheckout] Autorizacion aprobada. Abriendo Stripe Checkout.',
      );
      _mergeRequestSnapshot(authorizationPayload);
      _debugStripeCheckoutState(
        label: 'antes_checkout',
        flightRequestId: effectiveFlightRequestId,
        reservationId: effectiveReservationId,
        endpoint:
            '/cliente/stripe/checkout/create, fallback '
            '/client/stripe/checkout/create, /stripe/checkout/create',
        body: {
          'flight_request_id': effectiveFlightRequestId,
          'booking_id': effectiveFlightRequestId,
          'success_url': _buildReservationPaymentBackendReturnUrl('success'),
          'cancel_url': _buildReservationPaymentBackendReturnUrl('cancel'),
          'return_url': _buildReservationPaymentBackendReturnUrl('success'),
          ...paymentPayload,
        },
      );
      final payload = await ApiClient.instance.createClientCheckout(
        flightRequestId: effectiveFlightRequestId,
        paymentPayload: paymentPayload,
        successUrl: _buildReservationPaymentBackendReturnUrl('success'),
        cancelUrl: _buildReservationPaymentBackendReturnUrl('cancel'),
        returnUrl: _buildReservationPaymentBackendReturnUrl('success'),
      );

      final redirectUrl = _checkoutUrl(payload);
      _reservationCheckoutSessionId = _firstText(payload, const [
        'session_id',
        'checkout_session_id',
        'checkoutSessionId',
      ]);
      _debugStripeCheckoutState(
        label: 'respuesta_checkout',
        flightRequestId: effectiveFlightRequestId,
        reservationId: effectiveReservationId,
        endpoint:
            '/cliente/stripe/checkout/create, fallback '
            '/client/stripe/checkout/create, /stripe/checkout/create',
        body: paymentPayload,
        response: payload,
        checkoutUrl: redirectUrl,
      );

      if (redirectUrl.isEmpty) {
        if (_requestIndicatesPaymentConfirmed(payload)) {
          _mergeRequestSnapshot(payload);
          if (!mounted) return;
          setState(() {
            _clearReservationCheckoutOpeningState();
            _inlineMessage = 'Pago confirmado. Redirigiendo a Tus Vuelos...';
          });
          await _redirectToTripsAfterConfirmedReservation(
            message: 'Pago confirmado. Redirigiendo a Tus Vuelos...',
          );
          return;
        }
        debugPrint(
          '[Pago][StripeCheckout] backend_sin_url=${jsonEncode(payload)}',
        );
        throw ApiException(
          _backendErrorMessage(payload).isNotEmpty
              ? _backendErrorMessage(payload)
              : 'El backend no devolvio una URL para el link de pago.',
        );
      }

      _clearReservationCheckoutOpeningState();
      final opened = await _openStripeCheckoutUrl(redirectUrl);

      if (!opened) {
        throw const ApiException(
          'No se pudo abrir Stripe Checkout. Intenta nuevamente.',
        );
      }

      reservationProvider.markPaymentPending(
        flightRequestId: effectiveFlightRequestId,
        reservationId: effectiveReservationId,
        checkoutSessionId: _reservationCheckoutSessionId,
      );

      if (!mounted) return;
      setState(() {
        _waitingForReservationCheckoutReturn = true;
        _inlineMessage =
            'Stripe Checkout abierto. Completa el pago y vuelve a la app; aqui validaremos el cobro antes de avanzar.';
      });
    } on ApiException catch (error) {
      final logScope =
          error.payload?['source'] == 'local_validation'
              ? '[Pago][PreCheckout][LocalValidation]'
              : '[Pago][PreCheckout][Backend]';
      debugPrint(
        '$logScope GET /cliente/reservas/${_reservationCheckoutReservationId.isNotEmpty ? _reservationCheckoutReservationId : reservationId}/payment-authorization '
        'status=${error.statusCode ?? 0} '
        'reservation_id=${_reservationCheckoutReservationId.isNotEmpty ? _reservationCheckoutReservationId : reservationId} '
        'flight_request_id=${_reservationCheckoutFlightRequestId.isNotEmpty ? _reservationCheckoutFlightRequestId : effectiveFlightRequestId} '
        'message=${error.message} '
        'payload=${jsonEncode(error.payload ?? const {})}',
      );
      if (!mounted) return;
      if (error.isAircraftNotAvailable) {
        context.read<ReservationProvider>().handleAircraftUnavailable(
          widget.request,
        );
        widget.onAircraftUnavailable?.call(widget.request);
      }
      setState(() {
        _clearReservationCheckoutOpeningState();
        _inlineMessage =
            error.isAircraftNotAvailable
                ? 'La aeronave ya no esta disponible. Conservamos tu solicitud para que elijas otra opcion.'
                : _isContractGateError(error)
                ? 'La firma ya fue enviada. Estamos sincronizando el estado de pago; vuelve a tocar Abrir Stripe Checkout en unos segundos.'
                : error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _clearReservationCheckoutOpeningState();
        _inlineMessage =
            'No se pudo abrir Stripe Checkout. Intenta nuevamente.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _isContractGateError(ApiException error) {
    final message =
        [
          error.message,
          error.payload?['message']?.toString() ?? '',
          error.payload?['error']?.toString() ?? '',
        ].join(' ').toLowerCase();

    return message.contains('firmar') ||
        message.contains('firma') ||
        message.contains('contrato') ||
        message.contains('contract') ||
        message.contains('sign');
  }

  Future<void> _validateReservationCheckoutReturn() async {
    if (_submitting || widget.commercialAccessMode) return;
    if (!_shouldValidateReservationPaymentOnReturn &&
        !_requestIndicatesPaymentConfirmed(widget.request)) {
      if (!mounted) return;
      setState(() {
        _isValidatingPayment = false;
        _checkoutCompleted = false;
        _showTripsShortcut = false;
        _forceNewCheckoutAfterValidation = false;
        _waitingForReservationCheckoutReturn = false;
        if (_reservationCheckoutAwaitingCompletion) {
          _inlineMessage =
              'Tu reserva esta pendiente de pago. Abre Stripe Checkout para capturar tu tarjeta y continuar.';
        }
      });
      return;
    }

    final reservationProvider = context.read<ReservationProvider>();
    var flightRequestId =
        _reservationCheckoutFlightRequestId.isNotEmpty
            ? _reservationCheckoutFlightRequestId
            : _effectiveFlightRequestId(widget.request);
    var reservationId =
        _reservationCheckoutReservationId.isNotEmpty
            ? _reservationCheckoutReservationId
            : _effectiveReservationId(widget.request);
    var sessionId = _effectiveCheckoutSessionId(widget.request);

    setState(() {
      _submitting = true;
      _isValidatingPayment = true;
      _showTripsShortcut = false;
      _forceNewCheckoutAfterValidation = false;
      _inlineMessage = 'Validando pago del vuelo...';
    });

    try {
      Map<String, dynamic>? successPayload;
      Map<String, dynamic> refreshedMatch = const <String, dynamic>{};
      const maxAttempts = 8;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (attempt > 0) {
          sessionId = _effectiveCheckoutSessionId(widget.request);
          reservationId = _effectiveReservationId(widget.request);
          flightRequestId = _effectiveFlightRequestId(widget.request);
        }
        debugPrint(
          '[Pago][PostCheckout] GET ${_apiLogUrl('/cliente/stripe/checkout/success', query: {if (sessionId.isNotEmpty) 'session_id': sessionId, if (sessionId.isNotEmpty) 'checkout_session_id': sessionId, if (sessionId.isNotEmpty) 'stripe_checkout_session_id': sessionId, if (reservationId.isNotEmpty) 'reservation_id': reservationId, if (reservationId.isNotEmpty) 'booking_id': reservationId, if (flightRequestId.isNotEmpty) 'flight_request_id': flightRequestId, if (flightRequestId.isNotEmpty) 'request_id': flightRequestId})} '
          'attempt=${attempt + 1} '
          'reservation_id=$reservationId '
          'flight_request_id=$flightRequestId',
        );
        if (sessionId.isNotEmpty) {
          try {
            successPayload = await ApiClient.instance.getClientCheckoutSuccess(
              sessionId: sessionId,
              reservationId: reservationId,
              flightRequestId: flightRequestId,
            );
            debugPrint(
              '[Pago][PostCheckout] GET /cliente/stripe/checkout/success '
              'status=200 '
              'reservation_id=$reservationId '
              'flight_request_id=$flightRequestId '
              'message=${_backendErrorMessage(successPayload)}',
            );
          } on ApiException catch (error) {
            debugPrint(
              '[Pago][PostCheckout] GET /cliente/stripe/checkout/success '
              'status=${error.statusCode ?? 0} '
              'reservation_id=$reservationId '
              'flight_request_id=$flightRequestId '
              'message=${error.message}',
            );
            successPayload = const <String, dynamic>{};
          }
        } else {
          successPayload = const <String, dynamic>{};
          debugPrint(
            '[Pago][StripeCheckout][validacion_intento_${attempt + 1}] '
            'sessionId_final_vacio, omitimos /checkout/success y refrescamos workspace.',
          );
        }
        debugPrint(
          '[Pago][StripeCheckout][success_payload_${attempt + 1}] '
          '${jsonEncode(successPayload)}',
        );

        if (successPayload.isNotEmpty &&
            _requestIndicatesPaymentConfirmed(successPayload)) {
          break;
        }

        refreshedMatch = await _refreshMatchingPaymentSnapshot(
          force: attempt == 0 || attempt.isOdd,
        );
        if (refreshedMatch.isNotEmpty) {
          _mergeRequestSnapshot(refreshedMatch);
          sessionId = _effectiveCheckoutSessionId(refreshedMatch);
          reservationId = _effectiveReservationId(refreshedMatch);
          flightRequestId = _effectiveFlightRequestId(refreshedMatch);
        }
        debugPrint(
          '[Pago][StripeCheckout][workspace_snapshot_${attempt + 1}] '
          '${jsonEncode(refreshedMatch)}',
        );
        if (refreshedMatch.isNotEmpty &&
            _requestIndicatesPaymentConfirmed(refreshedMatch)) {
          break;
        }

        if (attempt < maxAttempts - 1) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }

      if (successPayload != null && successPayload.isNotEmpty) {
        _mergeRequestSnapshot(successPayload);
      }

      if (refreshedMatch.isEmpty) {
        refreshedMatch = await _refreshMatchingPaymentSnapshot(force: true);
      }
      if (refreshedMatch.isNotEmpty) {
        _mergeRequestSnapshot(refreshedMatch);
      }

      final currentSnapshot =
          successPayload != null &&
                  successPayload.isNotEmpty &&
                  _requestIndicatesPaymentConfirmed(successPayload)
              ? successPayload
              : refreshedMatch.isNotEmpty &&
                  _requestIndicatesPaymentConfirmed(refreshedMatch)
              ? refreshedMatch
              : successPayload != null &&
                  successPayload.isNotEmpty &&
                  _requestIndicatesPaymentPending(successPayload)
              ? successPayload
              : refreshedMatch.isNotEmpty
              ? refreshedMatch
              : widget.request;
      debugPrint(
        '[Pago][StripeCheckout][snapshot_actual] ${jsonEncode(currentSnapshot)}',
      );

      if (_requestIndicatesPaymentConfirmed(currentSnapshot)) {
        await reservationProvider.loadClientWorkspaceData(force: true);
        if (!mounted) return;
        setState(() {
          _isValidatingPayment = false;
          _showTripsShortcut = false;
          _forceNewCheckoutAfterValidation = false;
          _waitingForReservationCheckoutReturn = false;
          _inlineMessage = 'Pago confirmado. Redirigiendo a Tus Vuelos...';
        });
        await _redirectToTripsAfterConfirmedReservation(
          message: 'Pago confirmado. Redirigiendo a Tus Vuelos...',
        );
        return;
      }

      if (_requestIndicatesPaymentPending(currentSnapshot)) {
        final requiresNewCheckout =
            shouldForceNewCheckoutAfterPendingValidation(
              hadCheckoutSuccessReturn:
                  _checkoutCompleted ||
                  _requestHasCheckoutReturnSuccess(currentSnapshot) ||
                  _requestHasCheckoutReturnSuccess(widget.request),
              paymentConfirmed: false,
              paymentPending: true,
              hasCheckoutSessionId:
                  _effectiveCheckoutSessionId(currentSnapshot).isNotEmpty ||
                  sessionId.isNotEmpty,
              hasPaymentIntentId:
                  _paymentIntentId(currentSnapshot).trim().isNotEmpty,
              hasExplicitNewCheckoutSignal: _requestRequiresNewCheckoutSession(
                currentSnapshot,
              ),
            );
        final effectiveReservationId =
            _effectiveReservationId(currentSnapshot).isNotEmpty
                ? _effectiveReservationId(currentSnapshot)
                : reservationId;

        reservationProvider.markPaymentPending(
          flightRequestId: flightRequestId,
          reservationId: effectiveReservationId,
          checkoutSessionId: sessionId,
        );
        if (!mounted) return;
        setState(() {
          _isValidatingPayment = false;
          _showTripsShortcut = !requiresNewCheckout;
          _forceNewCheckoutAfterValidation = requiresNewCheckout;
          _waitingForReservationCheckoutReturn = false;
          _inlineMessage =
              requiresNewCheckout
                  ? 'El enlace anterior de Stripe ya cerro o vencio. Genera un nuevo enlace para reintentar; si Stripe ya capturo el pago, el backend lo reconciliara antes de cobrar otra vez.'
                  : 'Seguimos validando tu pago. Puedes continuar en Tus Vuelos.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _isValidatingPayment = false;
        _showTripsShortcut = true;
        _forceNewCheckoutAfterValidation = false;
        _waitingForReservationCheckoutReturn = false;
        _reservationCheckoutSessionId = '';
        _inlineMessage =
            'Seguimos validando tu pago. Puedes continuar en Tus Vuelos.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isValidatingPayment = false;
        _showTripsShortcut = true;
        _forceNewCheckoutAfterValidation = false;
        _waitingForReservationCheckoutReturn = false;
        _reservationCheckoutSessionId = '';
        _inlineMessage =
            'No fue posible validar automaticamente el pago: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          if (!_waitingForReservationCheckoutReturn) {
            _isValidatingPayment = false;
          }
        });
      }
    }
  }

  Future<void> _validateCommercialAccessAfterCheckout() async {
    if (_submitting) return;

    final auth = context.read<AuthProvider>();

    setState(() {
      _submitting = true;
      _inlineMessage = 'Validando acceso comercial...';
    });

    try {
      Map<String, dynamic>? successPayload;
      var successIndicatesActive = false;
      for (var attempt = 0; attempt < 8; attempt++) {
        successPayload = await ApiClient.instance
            .getClientAccessPaymentSuccess(
              sessionId:
                  _accessCheckoutSessionId.isEmpty
                      ? null
                      : _accessCheckoutSessionId,
              contactEmail: _contactEmail.isEmpty ? null : _contactEmail,
            )
            .catchError((_) => <String, dynamic>{});

        if (successPayload.isNotEmpty) {
          auth.syncAccessState(successPayload);
        }

        if (_accessIsActive(successPayload)) {
          successIndicatesActive = true;
          break;
        }

        await auth.refreshCommercialAccessStatus().catchError((_) {});
        if (_accessIsActive(auth.accessData)) break;

        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }

      if (!mounted) return;
      if (successPayload != null && successPayload.isNotEmpty) {
        auth.syncAccessState(successPayload);
      }
      await auth.refreshCommercialAccessStatus();
      final accessState = resolveCommercialAccessState(auth.accessData);

      if (!mounted) return;

      if (successIndicatesActive || accessState.isConfirmedActive) {
        setState(() {
          _waitingForCommercialAccessReturn = false;
          _inlineMessage = 'Acceso comercial activado.';
        });
        widget.onPaymentComplete();
        return;
      }

      setState(() {
        _waitingForCommercialAccessReturn = false;
        _inlineMessage =
            'Stripe regreso a la app, pero el backend aun no confirma el acceso. Toca de nuevo cuando Stripe termine de validar.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _waitingForCommercialAccessReturn = false;
        _inlineMessage =
            'No fue posible validar automaticamente el acceso comercial: $error';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _bootstrapReservationPaymentState() async {
    if (_reservationPaymentConfirmed) {
      await _redirectToTripsAfterConfirmedReservation(
        message:
            'La reserva ya aparece como pagada y confirmada en el backend.',
      );
      return;
    }

    if (_waitingForReservationCheckoutReturn &&
        !_shouldValidateReservationPaymentOnReturn &&
        mounted) {
      setState(() {
        _isValidatingPayment = false;
        _checkoutCompleted = false;
        _showTripsShortcut = false;
        _waitingForReservationCheckoutReturn = false;
      });
    }

    if (_waitingForReservationCheckoutReturn) {
      await _validateReservationStateSilently();
      return;
    }

    if (_reservationCheckoutAwaitingCompletion && mounted) {
      setState(() {
        _isValidatingPayment = false;
        _checkoutCompleted = false;
        _showTripsShortcut = false;
        _inlineMessage =
            'Tu reserva esta pendiente de pago. Abre Stripe Checkout para capturar tu tarjeta y continuar.';
      });
    }
  }

  Future<void> _validateReservationStateSilently() async {
    if (!mounted || widget.commercialAccessMode || _submitting) return;

    try {
      final sessionId = _effectiveCheckoutSessionId(widget.request);
      final reservationId = _effectiveReservationId(widget.request);
      final flightRequestId = _effectiveFlightRequestId(widget.request);
      debugPrint(
        '[Pago][StripeCheckout][bootstrap] '
        'sessionId_final=$sessionId '
        'reservationId_final=$reservationId '
        'flightRequestId_final=$flightRequestId',
      );
      final successPayload =
          sessionId.isEmpty
              ? const <String, dynamic>{}
              : await ApiClient.instance
                  .getClientCheckoutSuccess(
                    sessionId: sessionId,
                    reservationId: reservationId,
                    flightRequestId: flightRequestId,
                  )
                  .catchError((_) => <String, dynamic>{});
      if (successPayload.isNotEmpty) {
        _mergeRequestSnapshot(successPayload);
      }

      final refreshedMatch = await _refreshMatchingPaymentSnapshot(force: true);
      if (refreshedMatch.isNotEmpty) {
        _mergeRequestSnapshot(refreshedMatch);
      }

      if (!mounted) return;
      if (_requestIndicatesPaymentConfirmed(widget.request)) {
        setState(() {
          _isValidatingPayment = false;
          _showTripsShortcut = false;
          _waitingForReservationCheckoutReturn = false;
        });
        await _redirectToTripsAfterConfirmedReservation(
          message:
              'La reserva ya aparece como pagada y confirmada en el backend.',
        );
        return;
      }

      if (_requestIndicatesPaymentPending(widget.request)) {
        setState(() {
          _isValidatingPayment = false;
          _checkoutCompleted = false;
          _showTripsShortcut = true;
          _waitingForReservationCheckoutReturn = false;
          _inlineMessage =
              _reservationCheckoutAwaitingCompletion
                  ? 'Tu reserva sigue pendiente de pago. Abre Stripe Checkout para continuar.'
                  : 'Detectamos un pago en validacion. Vuelve a esta pantalla despues de regresar de Stripe.';
        });
      }
    } catch (error) {
      debugPrint('[Pago][StripeCheckout][bootstrap_error] $error');
    }
  }

  bool _requestHasCheckoutReturnSuccess(Map<String, dynamic> request) {
    final data = _asStringKeyMap(request['data']);
    final reservation = _asStringKeyMap(request['reservation']);
    final dataReservation = _asStringKeyMap(data['reservation']);
    final frontendState = _asStringKeyMap(request['frontend_state']);
    final dataFrontendState = _asStringKeyMap(data['frontend_state']);

    return _isTruthyValue(request['checkout_return_success']) ||
        _isTruthyValue(request['checkoutCompleted']) ||
        _isTruthyValue(request['checkout_completed']) ||
        _isTruthyValue(data['checkout_return_success']) ||
        _isTruthyValue(data['checkoutCompleted']) ||
        _isTruthyValue(data['checkout_completed']) ||
        _isTruthyValue(reservation['checkout_return_success']) ||
        _isTruthyValue(reservation['checkoutCompleted']) ||
        _isTruthyValue(reservation['checkout_completed']) ||
        _isTruthyValue(dataReservation['checkout_return_success']) ||
        _isTruthyValue(dataReservation['checkoutCompleted']) ||
        _isTruthyValue(dataReservation['checkout_completed']) ||
        _isTruthyValue(frontendState['checkout_return_success']) ||
        _isTruthyValue(frontendState['checkoutCompleted']) ||
        _isTruthyValue(frontendState['checkout_completed']) ||
        _isTruthyValue(dataFrontendState['checkout_return_success']) ||
        _isTruthyValue(dataFrontendState['checkoutCompleted']) ||
        _isTruthyValue(dataFrontendState['checkout_completed']);
  }

  bool _hasReservationPaymentIntent(Map<String, dynamic> request) {
    return _paymentIntentId(request).trim().isNotEmpty ||
        _clientSecret(request).trim().isNotEmpty;
  }

  Future<void> _openReservationExistingCheckout() async {
    try {
      if (_requestRequiresNewCheckoutSession(widget.request)) {
        await _submitReservationCheckoutLink(forceRecreate: true);
        return;
      }

      if (mounted) {
        setState(() {
          _openingReservationCheckout = true;
          _inlineMessage = 'Abriendo Stripe Checkout...';
        });
      }
      _scheduleReservationCheckoutOpeningTimeout();

      final checkoutUrl = await _resolveReservationCheckoutUrl();
      if (checkoutUrl.isEmpty) {
        debugPrint(
          '[Pago][StripeCheckout] checkout_pendiente_sin_url, regenerando_sesion',
        );
        if (mounted) {
          setState(() {
            _clearReservationCheckoutOpeningState();
            _inlineMessage =
                'No encontramos el enlace anterior de Stripe. Regenerando uno nuevo...';
          });
        }
        await _submitReservationCheckoutLink(forceRecreate: true);
        return;
      }

      _clearReservationCheckoutOpeningState();
      final opened = await _openStripeCheckoutUrl(checkoutUrl);

      if (!opened) {
        throw const ApiException(
          'No se pudo abrir Stripe Checkout. Intenta nuevamente.',
        );
      }

      if (!mounted) return;
      setState(() {
        _inlineMessage =
            'Stripe Checkout abierto. Captura tu tarjeta y vuelve a la app cuando termines.';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _clearReservationCheckoutOpeningState();
        _inlineMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _clearReservationCheckoutOpeningState();
        _inlineMessage =
            'No se pudo abrir Stripe Checkout. Intenta nuevamente.';
      });
    }
  }

  void _scheduleReservationCheckoutOpeningTimeout() {
    _reservationCheckoutOpeningTimer?.cancel();
    _reservationCheckoutOpeningTimer = Timer(const Duration(seconds: 9), () {
      if (!mounted || !_openingReservationCheckout) return;
      setState(() {
        _openingReservationCheckout = false;
      });
    });
  }

  void _clearReservationCheckoutOpeningState() {
    _reservationCheckoutOpeningTimer?.cancel();
    _openingReservationCheckout = false;
  }

  void _showCheckoutFeedback(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _openStripeCheckoutUrl(String checkoutUrl) async {
    final trimmedUrl = checkoutUrl.trim();
    if (trimmedUrl.isEmpty) return false;

    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null) return false;

    debugPrint('[Pago][StripeCheckout][open_url] $trimmedUrl');
    final openedExternal = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (openedExternal) return true;

    return launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  Future<String> _resolveReservationCheckoutUrl() async {
    if (_requestRequiresNewCheckoutSession(widget.request)) {
      return '';
    }

    final directUrl = _checkoutUrl(widget.request);
    if (directUrl.isNotEmpty) return directUrl;

    final currentSessionId = _effectiveCheckoutSessionId(widget.request);
    final currentReservationId = _effectiveReservationId(widget.request);
    final currentFlightRequestId = _effectiveFlightRequestId(widget.request);

    if (currentSessionId.isNotEmpty) {
      try {
        final payload = await ApiClient.instance.getClientCheckoutSuccess(
          sessionId: currentSessionId,
          reservationId: currentReservationId,
          flightRequestId: currentFlightRequestId,
        );
        if (payload.isNotEmpty) {
          _mergeRequestSnapshot(payload);
          if (_requestRequiresNewCheckoutSession(payload)) {
            return '';
          }
          final recoveredUrl = _checkoutUrl(payload);
          if (recoveredUrl.isNotEmpty) return recoveredUrl;
        }
      } catch (error) {
        debugPrint('[Pago][StripeCheckout][recover_session_error] $error');
      }
    }

    try {
      final refreshedMatch = await _refreshMatchingPaymentSnapshot(force: true);
      if (refreshedMatch.isNotEmpty) {
        _mergeRequestSnapshot(refreshedMatch);
        if (_requestRequiresNewCheckoutSession(refreshedMatch)) {
          return '';
        }
        final recoveredUrl = _checkoutUrl(refreshedMatch);
        if (recoveredUrl.isNotEmpty) return recoveredUrl;
      }
    } catch (error) {
      debugPrint('[Pago][StripeCheckout][recover_workspace_error] $error');
    }

    return '';
  }

  Future<bool> _waitForCommercialAccessActivation() async {
    final auth = context.read<AuthProvider>();
    for (var attempt = 0; attempt < 5; attempt++) {
      Map<String, dynamic>? successPayload;
      try {
        successPayload = await ApiClient.instance.getClientAccessPaymentSuccess(
          sessionId:
              _accessCheckoutSessionId.isEmpty
                  ? null
                  : _accessCheckoutSessionId,
          contactEmail: _contactEmail.isEmpty ? null : _contactEmail,
        );
      } catch (_) {
        successPayload = null;
      }

      if (successPayload != null && successPayload.isNotEmpty) {
        auth.syncAccessState(successPayload);
      }

      await auth.refreshCommercialAccessStatus();
      final accessState = resolveCommercialAccessState(auth.accessData);
      if (_accessIsActive(successPayload) || accessState.isConfirmedActive) {
        return true;
      }

      await Future<void>.delayed(const Duration(milliseconds: 900));
    }

    return false;
  }

  String _routeLabel(Map<String, dynamic> request) {
    final data = _asStringKeyMap(request['data']);
    final reservation = _asStringKeyMap(request['reservation']);
    final dataReservation = _asStringKeyMap(data['reservation']);
    final flightRequest = _asStringKeyMap(request['flight_request']);
    final dataFlightRequest = _asStringKeyMap(data['flight_request']);
    final firstLeg = _firstLegMap([
      request,
      data,
      reservation,
      dataReservation,
      flightRequest,
      dataFlightRequest,
    ]);
    final origin =
        _firstTextFromMaps(
          const [
            'origin',
            'source_origin',
            'base_airport',
            'departure_airport',
            'from',
            'from_airport',
          ],
          [
            request,
            data,
            reservation,
            dataReservation,
            flightRequest,
            dataFlightRequest,
            firstLeg,
          ],
        ).trim();
    final destination =
        _firstTextFromMaps(
          const ['destination', 'arrival_airport', 'to', 'to_airport'],
          [
            request,
            data,
            reservation,
            dataReservation,
            flightRequest,
            dataFlightRequest,
            firstLeg,
          ],
        ).trim();

    if (origin.isNotEmpty && destination.isNotEmpty) {
      return '$origin -> $destination';
    }
    if (origin.isNotEmpty) return '$origin -> Destino por confirmar';
    if (destination.isNotEmpty) return 'Origen por confirmar -> $destination';
    return 'Ruta por confirmar';
  }

  String _amountLabel(Map<String, dynamic> request) {
    final data = _asStringKeyMap(request['data']);
    final reservation = _asStringKeyMap(request['reservation']);
    final dataReservation = _asStringKeyMap(data['reservation']);
    final pricingContext = _asStringKeyMap(request['pricing_context']);
    final dataPricingContext = _asStringKeyMap(data['pricing_context']);
    final reservationPricingContext = _asStringKeyMap(
      reservation['pricing_context'],
    );
    final aircraftSnapshot = _asStringKeyMap(request['aircraft_snapshot']);
    final dataAircraftSnapshot = _asStringKeyMap(data['aircraft_snapshot']);
    final paymentPreview = _reservationPaymentPreview(request);
    final sources = [
      request,
      data,
      reservation,
      dataReservation,
      pricingContext,
      dataPricingContext,
      reservationPricingContext,
      aircraftSnapshot,
      dataAircraftSnapshot,
      paymentPreview,
    ];
    final formatted = _firstTextFromMaps(const [
      'formatted_final_price',
      'final_price_display',
      'estimated_total_display',
      'total_display',
      'amount_display',
      'amount_due_display',
      'price_display',
    ], sources);
    if (formatted.isNotEmpty) return formatted;

    final currency = _reservationCurrency(
      request,
      pricingContext.isNotEmpty ? pricingContext : dataPricingContext,
      aircraftSnapshot.isNotEmpty ? aircraftSnapshot : dataAircraftSnapshot,
    );
    for (final source in sources) {
      final amount =
          _toAmount(
            source['total_amount'] ??
                source['amount_due'] ??
                source['final_price'] ??
                source['estimated_total'] ??
                source['total'] ??
                source['price'] ??
                source['selected_card_price'],
          ) ??
          0;
      if (amount > 0) return _formatCurrency(amount, currency);
    }

    return 'Monto por confirmar';
  }

  String _flightRequestId(Map<String, dynamic> request) {
    final reservation = _asStringKeyMap(request['reservation']);
    final flightRequest = _asStringKeyMap(request['flight_request']);
    final data = _asStringKeyMap(request['data']);
    final dataReservation = _asStringKeyMap(data['reservation']);
    final dataFlightRequest = _asStringKeyMap(data['flight_request']);
    final direct = _firstTextFromMaps(
      const [
        'flight_request_id',
        'flightRequestId',
        'request_id',
        'requestId',
        'solicitud_id',
      ],
      [request, reservation, data, dataReservation],
    );
    if (direct.isNotEmpty) return direct;

    final nested = _firstTextFromMaps(
      const ['id'],
      [flightRequest, dataFlightRequest],
    );
    if (nested.isNotEmpty) return nested;

    final hasReservationIdentity =
        _reservationId(request).isNotEmpty || reservation.isNotEmpty;
    final id = request['id']?.toString().trim() ?? '';
    return id.isNotEmpty && !hasReservationIdentity ? id : '';
  }

  String _reservationId(Map<String, dynamic> request) {
    final reservation = _asStringKeyMap(request['reservation']);
    final data = _asStringKeyMap(request['data']);
    final dataReservation = _asStringKeyMap(data['reservation']);
    final direct = _firstTextFromMaps(
      const ['reservation_id', 'reservationId', 'booking_id', 'bookingId'],
      [request, data],
    );
    if (direct.isNotEmpty) return direct;

    return _firstTextFromMaps(const ['id'], [reservation, dataReservation]);
  }

  String _effectiveFlightRequestId(Map<String, dynamic> request) {
    final direct = _flightRequestId(request).trim();
    if (direct.isNotEmpty) return direct;

    final reservation = _asStringKeyMap(request['reservation']);
    final data = _asStringKeyMap(request['data']);
    final dataReservation = _asStringKeyMap(data['reservation']);

    return _firstTextFromMaps(
      const ['flight_request_id', 'request_id', 'id'],
      [reservation, dataReservation, data],
    );
  }

  String _effectiveReservationId(Map<String, dynamic> request) {
    final direct = _reservationId(request).trim();
    if (direct.isNotEmpty) return direct;

    final reservation = _asStringKeyMap(request['reservation']);
    final data = _asStringKeyMap(request['data']);
    final dataReservation = _asStringKeyMap(data['reservation']);

    return _firstTextFromMaps(
      const ['id', 'reservation_id', 'booking_id'],
      [reservation, dataReservation, data, request],
    );
  }

  String _effectiveCheckoutSessionId(Map<String, dynamic> request) {
    final reservation = _asStringKeyMap(request['reservation']);
    final data = _asStringKeyMap(request['data']);
    final dataReservation = _asStringKeyMap(data['reservation']);
    final paymentOrder = _asStringKeyMap(request['payment_order']);
    final dataPaymentOrder = _asStringKeyMap(data['payment_order']);
    final payments = _paymentsFromRow(request);

    final direct = _firstTextFromMaps(
      const [
        'stripe_checkout_session_id',
        'checkout_session_id',
        'checkoutSessionId',
        'session_id',
        'sessionId',
      ],
      [
        request,
        reservation,
        data,
        dataReservation,
        paymentOrder,
        dataPaymentOrder,
      ],
    );
    if (direct.isNotEmpty) {
      _reservationCheckoutSessionId = direct;
      return direct;
    }

    for (final payment in payments) {
      final paymentSessionId = _firstTextFromMaps(
        const [
          'stripe_checkout_session_id',
          'checkout_session_id',
          'checkoutSessionId',
          'session_id',
        ],
        [payment],
      );
      if (paymentSessionId.isNotEmpty) {
        _reservationCheckoutSessionId = paymentSessionId;
        return paymentSessionId;
      }
    }

    return _reservationCheckoutSessionId.trim();
  }

  Map<String, dynamic> _firstLegMap(List<Map<String, dynamic>> sources) {
    for (final source in sources) {
      for (final key in const [
        'legs',
        'routes',
        'route',
        'flight_legs',
        'itinerary',
        'segments',
      ]) {
        final value = source[key];
        if (value is List) {
          for (final item in value) {
            if (item is Map) return Map<String, dynamic>.from(item);
          }
        }
        if (value is Map) return Map<String, dynamic>.from(value);
      }
    }
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _reservationPaymentPreview(
    Map<String, dynamic> request,
  ) {
    final data = _asStringKeyMap(request['data']);
    final reservation = _asStringKeyMap(request['reservation']);
    final dataReservation = _asStringKeyMap(data['reservation']);
    for (final candidate in [
      request['payment_preview'],
      request['paymentPreview'],
      data['payment_preview'],
      data['paymentPreview'],
      reservation['payment_preview'],
      reservation['paymentPreview'],
      dataReservation['payment_preview'],
      dataReservation['paymentPreview'],
    ]) {
      final map = _asStringKeyMap(candidate);
      if (map.isNotEmpty) return map;
    }
    return const <String, dynamic>{};
  }

  String _requestContactEmail(Map<String, dynamic> request) {
    final data = _asStringKeyMap(request['data']);
    final reservation = _asStringKeyMap(request['reservation']);
    final dataReservation = _asStringKeyMap(data['reservation']);
    final client = _asStringKeyMap(request['client']);
    final dataClient = _asStringKeyMap(data['client']);
    return _firstTextFromMaps(
      const ['contact_email', 'email', 'client_email', 'customer_email'],
      [request, data, reservation, dataReservation, client, dataClient],
    );
  }

  Future<String> _ensureReservationId({
    required String flightRequestId,
    required String reservationId,
    required String logPrefix,
  }) async {
    debugPrint(
      '$logPrefix flightRequestId=$flightRequestId reservationId=$reservationId',
    );
    final resolvedReservationId = await ApiClient.instance
        .ensureClientReservation(
          flightRequestId: flightRequestId,
          existingReservationId: reservationId,
        );
    if (reservationId.trim().isEmpty) {
      debugPrint('$logPrefix reservation creada: $resolvedReservationId');
    }
    widget.request['reservation_id'] = resolvedReservationId;
    widget.request['booking_id'] = resolvedReservationId;
    return resolvedReservationId;
  }

  Future<void> _refreshSignedContractState() async {
    _syncContractWarningVisibility();
    if (_contractAllowsPayment(widget.request)) return;
    final signed = await _resolveContractSignedState();
    if (!mounted || !signed) return;
    _syncContractWarningVisibility();
  }

  void _scheduleRefreshSignedContractState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshSignedContractState());
    });
  }

  void _syncContractWarningVisibility() {
    final shouldClear =
        _inlineMessage.toLowerCase().contains('firmar') &&
        _contractAllowsPayment(widget.request);
    if (!shouldClear) return;
    if (!mounted) return;
    if (_inlineMessage.isEmpty) return;
    setState(() => _inlineMessage = '');
  }

  Future<bool> _resolveContractSignedState({
    bool refreshWorkspace = false,
  }) async {
    if (_contractAllowsPayment(widget.request)) return true;

    final reservationProvider = context.read<ReservationProvider>();
    final localMatch = _matchingRequestFromProvider(reservationProvider);
    if (localMatch.isNotEmpty && _contractAllowsPayment(localMatch)) {
      _mergeRequestSnapshot(localMatch);
      return true;
    }

    final contractStatusId = _contractStatusEntityId(widget.request);
    if (contractStatusId.isNotEmpty) {
      try {
        final statusPayload = await ApiClient.instance.getClientContractStatus(
          contractStatusId,
        );
        if (_isContractSigned(statusPayload) ||
            _readyForPayment(statusPayload)) {
          _mergeRequestSnapshot(statusPayload);
          return true;
        }
      } catch (_) {
        // Conservamos el fallback al provider sincronizado.
      }
    }

    final directContractSnapshot = await _fetchDirectContractSnapshot();
    if (directContractSnapshot.isNotEmpty &&
        (_isContractSigned(directContractSnapshot) ||
            _readyForPayment(directContractSnapshot))) {
      _mergeRequestSnapshot(directContractSnapshot);
      return true;
    }

    if (refreshWorkspace || localMatch.isEmpty) {
      final refreshedMatch = await _refreshMatchingPaymentSnapshot(
        force: refreshWorkspace,
      );
      if (refreshedMatch.isNotEmpty && _contractAllowsPayment(refreshedMatch)) {
        _mergeRequestSnapshot(refreshedMatch);
        return true;
      }

      final refreshedContractSnapshot = await _fetchDirectContractSnapshot();
      if (refreshedContractSnapshot.isNotEmpty &&
          (_isContractSigned(refreshedContractSnapshot) ||
              _readyForPayment(refreshedContractSnapshot))) {
        _mergeRequestSnapshot(refreshedContractSnapshot);
        return true;
      }
    }

    return false;
  }

  Future<Map<String, dynamic>> _refreshMatchingPaymentSnapshot({
    bool force = false,
  }) async {
    final reservationProvider = context.read<ReservationProvider>();
    final now = DateTime.now();

    if (!force &&
        _lastLightweightPaymentRefreshAt != null &&
        now.difference(_lastLightweightPaymentRefreshAt!) <
            const Duration(seconds: 2)) {
      return _matchingRequestFromProvider(reservationProvider);
    }

    final inFlight = _lightweightPaymentRefreshFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _loadMatchingPaymentSnapshot();
    _lightweightPaymentRefreshFuture = future;
    try {
      final snapshot = await future;
      _lastLightweightPaymentRefreshAt = DateTime.now();
      return snapshot;
    } finally {
      if (identical(_lightweightPaymentRefreshFuture, future)) {
        _lightweightPaymentRefreshFuture = null;
      }
    }
  }

  Future<Map<String, dynamic>> _loadMatchingPaymentSnapshot() async {
    final reservationProvider = context.read<ReservationProvider>();
    final localMatch = _matchingRequestFromProvider(reservationProvider);
    if (_requestIndicatesPaymentConfirmed(localMatch)) {
      return localMatch;
    }

    try {
      final results = await Future.wait<List<Map<String, dynamic>>>([
        ApiClient.instance.getClientFlightRequests().catchError(
          (_) => <Map<String, dynamic>>[],
        ),
        ApiClient.instance.getReservations().catchError(
          (_) => <Map<String, dynamic>>[],
        ),
      ]);

      final remoteMatch = _matchingRequestFromRows([
        ...results[1],
        ...results[0],
      ]);
      if (remoteMatch.isNotEmpty) {
        return remoteMatch;
      }
    } catch (error) {
      debugPrint('[Pago][lightweight_refresh_error] $error');
    }

    return localMatch;
  }

  bool _contractAllowsPayment(Map<String, dynamic> payload) {
    return _isContractSigned(payload) || _readyForPayment(payload);
  }

  Future<Map<String, dynamic>> _fetchDirectContractSnapshot() async {
    final reservationId = _reservationId(widget.request);
    final flightRequestId = _flightRequestId(widget.request);

    if (reservationId.isEmpty && flightRequestId.isEmpty) {
      return const <String, dynamic>{};
    }

    try {
      return await ApiClient.instance.getClientContract(
        reservationId: reservationId,
        flightRequestId: flightRequestId,
      );
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  Map<String, dynamic> _matchingRequestFromProvider(
    ReservationProvider reservationProvider,
  ) {
    return _matchingRequestFromRows([
      ...reservationProvider.flightRequests,
      ...reservationProvider.reservations,
    ]);
  }

  Map<String, dynamic> _matchingRequestFromRows(
    List<Map<String, dynamic>> rows,
  ) {
    final flightRequestId = _flightRequestId(widget.request);
    final reservationId = _reservationId(widget.request);
    final requestId = widget.request['id']?.toString().trim() ?? '';

    bool matches(Map<String, dynamic> row) {
      final rowFlightRequestId = _flightRequestId(row);
      final rowReservationId = _reservationId(row);
      final rowId = row['id']?.toString().trim() ?? '';
      final rowSessionId = _effectiveCheckoutSessionId(row);
      return (flightRequestId.isNotEmpty &&
              rowFlightRequestId == flightRequestId) ||
          (reservationId.isNotEmpty && rowReservationId == reservationId) ||
          (_reservationCheckoutSessionId.isNotEmpty &&
              rowSessionId == _reservationCheckoutSessionId) ||
          (requestId.isNotEmpty && rowId == requestId);
    }

    for (final row in rows) {
      if (matches(row)) return Map<String, dynamic>.from(row);
    }
    return const <String, dynamic>{};
  }

  void _mergeRequestSnapshot(Map<String, dynamic> snapshot) {
    if (snapshot.isEmpty) return;
    widget.request.addAll(snapshot);
    final data = _asStringKeyMap(snapshot['data']);
    final reservation = {
      ..._asStringKeyMap(data['reservation']),
      ..._asStringKeyMap(snapshot['reservation']),
    };
    if (reservation.isNotEmpty) {
      final currentReservation = _asStringKeyMap(widget.request['reservation']);
      widget.request['reservation'] = {...currentReservation, ...reservation};
    }
    final contract = {
      ..._asStringKeyMap(data['contract']),
      ..._asStringKeyMap(snapshot['contract']),
    };
    if (contract.isNotEmpty) {
      final currentContract = _asStringKeyMap(widget.request['contract']);
      widget.request['contract'] = {...currentContract, ...contract};
    }
    final frontendState = {
      ..._asStringKeyMap(data['frontend_state']),
      ..._asStringKeyMap(snapshot['frontend_state']),
    };
    if (frontendState.isNotEmpty) {
      final currentState = _asStringKeyMap(widget.request['frontend_state']);
      widget.request['frontend_state'] = {...currentState, ...frontendState};
    }
  }

  String _contractStatusEntityId(Map<String, dynamic> request) {
    final reservation = _asStringKeyMap(request['reservation']);
    final contract = _asStringKeyMap(request['contract']);
    final frontendState = _asStringKeyMap(request['frontend_state']);
    final reservationFrontendState = _asStringKeyMap(
      reservation['frontend_state'],
    );
    final contractFrontendState = _asStringKeyMap(contract['frontend_state']);

    return _firstTextFromMaps(
      const [
        'contract_id',
        'contractId',
        'docusign_contract_id',
        'envelope_id',
        'docusign_envelope_id',
      ],
      [
        request,
        reservation,
        contract,
        frontendState,
        reservationFrontendState,
        contractFrontendState,
      ],
    );
  }

  bool _readyForPayment(Map<String, dynamic> payload) {
    final data = _asStringKeyMap(payload['data']);
    final contract = _asStringKeyMap(payload['contract']);
    final dataContract = _asStringKeyMap(data['contract']);
    return _hasCompletedDocuSignStatus([payload, data, contract, dataContract]);
  }

  bool _isContractSigned(Map<String, dynamic> request) {
    final contract = _asStringKeyMap(request['contract']);
    final reservation = _asStringKeyMap(request['reservation']);
    final data = _asStringKeyMap(request['data']);
    final dataContract = _asStringKeyMap(data['contract']);
    final dataReservation = _asStringKeyMap(data['reservation']);
    final frontendState = _asStringKeyMap(request['frontend_state']);
    final dataFrontendState = _asStringKeyMap(data['frontend_state']);
    final reservationFrontendState = _asStringKeyMap(
      reservation['frontend_state'],
    );
    final dataReservationFrontendState = _asStringKeyMap(
      dataReservation['frontend_state'],
    );
    final contractFrontendState = _asStringKeyMap(contract['frontend_state']);
    final dataContractFrontendState = _asStringKeyMap(
      dataContract['frontend_state'],
    );
    final statusSummary = _asStringKeyMap(request['status_summary']);
    final dataStatusSummary = _asStringKeyMap(data['status_summary']);

    return _hasCompletedDocuSignStatus([
      request,
      data,
      reservation,
      dataReservation,
      contract,
      dataContract,
      frontendState,
      dataFrontendState,
      reservationFrontendState,
      dataReservationFrontendState,
      contractFrontendState,
      dataContractFrontendState,
      statusSummary,
      dataStatusSummary,
    ]);
  }

  bool _hasCompletedDocuSignStatus(List<Map<String, dynamic>> sources) {
    return sources.any((source) {
      return const ['docusign_status', 'envelope_status'].any(
        (key) => source[key]?.toString().trim().toLowerCase() == 'completed',
      );
    });
  }

  Map<String, dynamic> _reservationCheckoutPayload({
    required String reservationId,
  }) {
    return {
      if (_contactEmail.isNotEmpty) 'contact_email': _contactEmail,
      'reservation_id': reservationId,
      'booking_id': reservationId,
      'payment_method': 'stripe_checkout',
    };
  }

  String _checkoutUrl(Map<String, dynamic> payload) {
    return extractStripeCheckoutUrl(payload);
  }

  String _apiLogUrl(String path, {Map<String, String>? query}) {
    final uri = Uri.parse('${ApiClient.instance.baseUrl}$path');
    if (query == null || query.isEmpty) return uri.toString();
    return uri
        .replace(queryParameters: {...uri.queryParameters, ...query})
        .toString();
  }

  String _backendErrorMessage(Map<String, dynamic> payload) {
    final data = _asStringKeyMap(payload['data']);
    final error = _asStringKeyMap(payload['error']);
    return _firstTextFromMaps(
      const ['message', 'error', 'detail', 'description'],
      [payload, data, error],
    );
  }

  void _debugStripeCheckoutState({
    required String label,
    String flightRequestId = '',
    String reservationId = '',
    String endpoint = '',
    Map<String, dynamic>? body,
    Map<String, dynamic>? response,
    String checkoutUrl = '',
  }) {
    debugPrint(
      '[Pago][StripeCheckout][$label] '
      'flightRequestId=$flightRequestId '
      'reservationId=$reservationId '
      'endpoint=$endpoint '
      'checkoutUrl=$checkoutUrl '
      'body=${body == null ? '{}' : jsonEncode(body)} '
      'response=${response == null ? '{}' : jsonEncode(response)}',
    );
  }

  Map<String, dynamic> _asStringKeyMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _firstTextFromMaps(
    List<String> keys,
    List<Map<String, dynamic>> sources,
  ) {
    for (final source in sources) {
      for (final key in keys) {
        final value = source[key]?.toString().trim() ?? '';
        if (value.isNotEmpty && value.toLowerCase() != 'null') {
          return value;
        }
      }
    }
    return '';
  }

  Map<String, dynamic> _extractWireInstructions(Map<String, dynamic> payload) {
    final direct = payload['wire_instructions'] ?? payload['instructions'];
    if (direct is Map) return Map<String, dynamic>.from(direct);

    final data = payload['data'];
    if (data is Map) return Map<String, dynamic>.from(data);

    return {
      if (payload['reference'] != null) 'reference': payload['reference'],
      if (payload['payment_reference'] != null)
        'reference': payload['payment_reference'],
      if (payload['amount'] != null) 'amount': payload['amount'],
    };
  }

  String _wireInstructionText(Map<String, dynamic> instructions) {
    final reference =
        instructions['reference']?.toString() ??
        instructions['payment_reference']?.toString() ??
        'Pendiente';
    final amount =
        instructions['amount']?.toString() ?? _amountLabel(widget.request);
    final bank =
        instructions['bank']?.toString() ??
        instructions['bank_name']?.toString();

    return [
      if (bank != null && bank.isNotEmpty) 'Banco: $bank',
      'Referencia: $reference',
      'Importe: $amount',
    ].join('\n');
  }

  String _paymentStatus(Map<String, dynamic> payload) {
    final data = payload['data'];
    final paymentIntent =
        payload['payment_intent'] ??
        (data is Map ? data['payment_intent'] : null);

    return (payload['status'] ??
            payload['payment_status'] ??
            (paymentIntent is Map ? paymentIntent['status'] : null) ??
            (data is Map ? data['status'] : null) ??
            '')
        .toString()
        .trim()
        .toLowerCase();
  }

  String _paymentIntentId(Map<String, dynamic> payload) {
    final data = payload['data'];
    final paymentIntent =
        payload['payment_intent'] ??
        (data is Map ? data['payment_intent'] : null);

    return (payload['payment_intent_id'] ??
            payload['id'] ??
            (paymentIntent is Map ? paymentIntent['id'] : null) ??
            (data is Map ? data['payment_intent_id'] : null) ??
            '')
        .toString();
  }

  String _clientSecret(Map<String, dynamic> payload) {
    final data = payload['data'];
    final paymentIntent =
        payload['payment_intent'] ??
        (data is Map ? data['payment_intent'] : null);

    return (payload['client_secret'] ??
            payload['payment_intent_client_secret'] ??
            (paymentIntent is Map ? paymentIntent['client_secret'] : null) ??
            (data is Map ? data['client_secret'] : null) ??
            '')
        .toString()
        .trim();
  }

  String _publishableKey(Map<String, dynamic> payload) {
    final data = payload['data'];

    return (payload['publishable_key'] ??
            payload['stripe_publishable_key'] ??
            (data is Map ? data['publishable_key'] : null) ??
            (data is Map ? data['stripe_publishable_key'] : null) ??
            '')
        .toString()
        .trim();
  }

  String _customerName(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final name = user?.name.trim() ?? '';
    if (name.isNotEmpty) return name;
    final company = user?.companyName.trim() ?? '';
    if (company.isNotEmpty) return company;
    return 'Cliente Red Aviation';
  }

  String _cardBrand() {
    final brand = _cardDetails?.brand?.trim().toLowerCase() ?? '';
    if (brand.isEmpty) return 'card';
    return brand;
  }

  String _cardBrandLabel() {
    final brand = _cardDetails?.brand?.trim() ?? '';
    if (brand.isEmpty) return 'Stripe';
    return brand[0].toUpperCase() + brand.substring(1);
  }

  String _paymentMethodSummaryLabel() {
    switch (_paymentMethod) {
      case 'card':
        return 'Tarjeta ${_cardBrandLabel()}';
      case 'wire':
        return 'Transferencia bancaria';
      case 'link':
      default:
        return 'Stripe Checkout externo';
    }
  }

  String _cardProgressivePreview() {
    final rawNumber = (_cardDetails?.number ?? '').trim();
    final digits = rawNumber.replaceAll(RegExp(r'\D'), '');
    if (!_isCardNumberComplete(digits)) {
      return _formatCardNumberPreview(digits);
    }

    return _formatMaskedCardNumber(digits);
  }

  String _formatCardNumberPreview(String digits) {
    final expectedLength = _expectedCardLength();
    final trimmed =
        digits.length > expectedLength
            ? digits.substring(0, expectedLength)
            : digits;
    final buffer = StringBuffer();
    for (var index = 0; index < expectedLength; index++) {
      if (index > 0 && index % 4 == 0) buffer.write(' ');
      buffer.write(index < trimmed.length ? trimmed[index] : '•');
    }
    return buffer.toString();
  }

  String _formatMaskedCardNumber(String digits) {
    final expectedLength = _expectedCardLength();
    final trimmed =
        digits.length > expectedLength
            ? digits.substring(0, expectedLength)
            : digits;
    final visibleDigits =
        trimmed.length >= 4 ? trimmed.substring(trimmed.length - 4) : trimmed;
    final hiddenCount = (expectedLength - visibleDigits.length).clamp(0, 99);
    final maskedDigits = '${'•' * hiddenCount}$visibleDigits';
    final buffer = StringBuffer();
    for (var index = 0; index < maskedDigits.length; index++) {
      if (index > 0 && index % 4 == 0) buffer.write(' ');
      buffer.write(maskedDigits[index]);
    }
    return buffer.toString();
  }

  int _expectedCardLength() {
    final brand = _cardBrand();
    if (brand.contains('amex') || brand.contains('american express')) {
      return 15;
    }
    return 16;
  }

  bool _isCardNumberComplete(String digits) {
    if (digits.length >= _expectedCardLength()) return true;
    return _cardDetails?.validNumber == CardValidationState.Valid;
  }

  String _cardHolderPreview() {
    final holder = _customerName(context).trim().toUpperCase();
    if (holder.isEmpty) return 'RED AVIATION';
    return holder;
  }

  String _expiryPreview() {
    final month = _cardDetails?.expiryMonth;
    final year = _cardDetails?.expiryYear;
    if (month == null || year == null) return 'MM/AA';
    final normalizedMonth = month.toString().padLeft(2, '0');
    final normalizedYear = (year % 100).toString().padLeft(2, '0');
    return '$normalizedMonth/$normalizedYear';
  }

  Color _messageColor() {
    final normalized = _inlineMessage.toLowerCase();
    if (normalized.contains('error') ||
        normalized.contains('no fue posible') ||
        normalized.contains('no encontramos')) {
      return const Color(0xFFFFB4B4);
    }
    if (normalized.contains('preparada') ||
        normalized.contains('activado') ||
        normalized.contains('abierto')) {
      return const Color(0xFF9BE7B0);
    }
    return const Color(0xFFD6E1EA);
  }

  bool _requestIndicatesPaymentConfirmed(Map<String, dynamic> request) {
    final data = _asStringKeyMap(request['data']);
    final contract = _asStringKeyMap(request['contract']);
    final reservation = _asStringKeyMap(request['reservation']);
    final dataReservation = _asStringKeyMap(data['reservation']);
    final dataContract = _asStringKeyMap(data['contract']);
    final paymentOrder = _asStringKeyMap(request['payment_order']);
    final dataPaymentOrder = _asStringKeyMap(data['payment_order']);
    final payment = _asStringKeyMap(request['payment']);
    final dataPayment = _asStringKeyMap(data['payment']);
    final checkoutSession = {
      ..._asStringKeyMap(request['checkout_session']),
      ..._asStringKeyMap(request['session']),
    };
    final dataCheckoutSession = {
      ..._asStringKeyMap(data['checkout_session']),
      ..._asStringKeyMap(data['session']),
    };
    final payments = _paymentsFromRow(request);
    final paymentIntent = _asStringKeyMap(
      request['payment_intent'] ?? data['payment_intent'],
    );

    final status =
        _firstTextFromMaps(
          const [
            'status',
            'workflow_status',
            'payment_status',
            'checkout_status',
            'booking_status',
            'reservation_status',
            'stripe_payment_status',
          ],
          [
            request,
            data,
            reservation,
            dataReservation,
            contract,
            dataContract,
            paymentOrder,
            dataPaymentOrder,
            payment,
            dataPayment,
            checkoutSession,
            dataCheckoutSession,
          ],
        ).toLowerCase();

    if (const {
      'payment_confirmed',
      'paid',
      'pagado',
      'pagada',
      'pago confirmado',
      'pago aprobado',
      'succeeded',
      'confirmed',
      'confirmada',
      'confirmado',
      'vuelo confirmado',
      'flight_confirmed',
    }.contains(status)) {
      return true;
    }

    if (_isTruthyValue(request['payment_completed']) ||
        _isTruthyValue(request['is_paid']) ||
        _isTruthyValue(data['payment_completed']) ||
        _isTruthyValue(data['is_paid']) ||
        _isTruthyValue(reservation['payment_completed']) ||
        _isTruthyValue(reservation['is_paid']) ||
        _isTruthyValue(dataReservation['payment_completed']) ||
        _isTruthyValue(dataReservation['is_paid']) ||
        _isTruthyValue(payment['paid']) ||
        _isTruthyValue(dataPayment['paid']) ||
        _isTruthyValue(checkoutSession['paid']) ||
        _isTruthyValue(dataCheckoutSession['paid'])) {
      return true;
    }

    final paymentIntentStatus =
        paymentIntent['status']?.toString().trim().toLowerCase() ?? '';
    if (const {'succeeded', 'paid'}.contains(paymentIntentStatus)) {
      return true;
    }

    final bookingStatus =
        _firstTextFromMaps(
          const ['booking_status', 'reservation_status', 'status'],
          [request, data, reservation, dataReservation],
        ).toLowerCase();
    if (const {
      'confirmed',
      'confirmada',
      'confirmado',
      'flight_confirmed',
      'vuelo confirmado',
    }.contains(bookingStatus)) {
      return true;
    }

    for (final payment in payments) {
      final paymentStatus = payment['status']?.toString().trim().toLowerCase();
      if (const {
        'paid',
        'succeeded',
        'payment_confirmed',
        'confirmed',
      }.contains(paymentStatus)) {
        return true;
      }
    }

    return false;
  }

  bool _requestIndicatesPaymentPending(Map<String, dynamic> request) {
    if (_requestIndicatesPaymentConfirmed(request)) return false;
    if (!_requestHasStripeCheckoutSession(request, includeLocal: false)) {
      return false;
    }

    final data = _asStringKeyMap(request['data']);
    final contract = _asStringKeyMap(request['contract']);
    final reservation = _asStringKeyMap(request['reservation']);
    final dataReservation = _asStringKeyMap(data['reservation']);
    final dataContract = _asStringKeyMap(data['contract']);
    final paymentOrder = _asStringKeyMap(request['payment_order']);
    final dataPaymentOrder = _asStringKeyMap(data['payment_order']);
    final payment = _asStringKeyMap(request['payment']);
    final dataPayment = _asStringKeyMap(data['payment']);
    final checkoutSession = {
      ..._asStringKeyMap(request['checkout_session']),
      ..._asStringKeyMap(request['session']),
    };
    final dataCheckoutSession = {
      ..._asStringKeyMap(data['checkout_session']),
      ..._asStringKeyMap(data['session']),
    };
    final payments = _paymentsFromRow(request);
    final paymentIntent = _asStringKeyMap(
      request['payment_intent'] ?? data['payment_intent'],
    );

    final status =
        _firstTextFromMaps(
          const [
            'status',
            'workflow_status',
            'payment_status',
            'checkout_status',
            'booking_status',
            'reservation_status',
            'stripe_payment_status',
          ],
          [
            request,
            data,
            reservation,
            dataReservation,
            contract,
            dataContract,
            paymentOrder,
            dataPaymentOrder,
            payment,
            dataPayment,
            checkoutSession,
            dataCheckoutSession,
          ],
        ).toLowerCase();

    if (const {
      'payment_pending',
      'pending_payment',
      'pending',
      'pago pendiente',
      'pendiente de pago',
      'checkout',
      'payment',
      'processing',
      'requires_payment_method',
      'requires_action',
    }.contains(status)) {
      return true;
    }

    final paymentIntentStatus =
        paymentIntent['status']?.toString().trim().toLowerCase() ?? '';
    if (const {
      'processing',
      'requires_payment_method',
      'requires_action',
    }.contains(paymentIntentStatus)) {
      return true;
    }

    for (final payment in payments) {
      final paymentStatus = payment['status']?.toString().trim().toLowerCase();
      if (const {
        'pending',
        'processing',
        'payment_pending',
        'requires_action',
      }.contains(paymentStatus)) {
        return true;
      }
    }

    return false;
  }

  bool _requestHasStripeCheckoutSession(
    Map<String, dynamic> request, {
    bool includeLocal = false,
  }) {
    if (includeLocal &&
        isStripeCheckoutSessionId(_reservationCheckoutSessionId)) {
      return true;
    }

    final data = _asStringKeyMap(request['data']);
    final reservation = _asStringKeyMap(request['reservation']);
    final dataReservation = _asStringKeyMap(data['reservation']);
    final paymentOrder = _asStringKeyMap(request['payment_order']);
    final dataPaymentOrder = _asStringKeyMap(data['payment_order']);
    final payment = _asStringKeyMap(request['payment']);
    final dataPayment = _asStringKeyMap(data['payment']);
    final checkoutSession = {
      ..._asStringKeyMap(request['checkout_session']),
      ..._asStringKeyMap(request['session']),
    };
    final dataCheckoutSession = {
      ..._asStringKeyMap(data['checkout_session']),
      ..._asStringKeyMap(data['session']),
    };

    final sessionId =
        _firstTextFromMaps(
          const [
            'stripe_checkout_session_id',
            'checkout_session_id',
            'checkoutSessionId',
            'session_id',
            'sessionId',
            'id',
          ],
          [
            request,
            data,
            reservation,
            dataReservation,
            paymentOrder,
            dataPaymentOrder,
            payment,
            dataPayment,
            checkoutSession,
            dataCheckoutSession,
          ],
        ).trim();

    if (isStripeCheckoutSessionId(sessionId)) return true;

    for (final item in _paymentsFromRow(request)) {
      final paymentSessionId =
          _firstTextFromMaps(
            const [
              'stripe_checkout_session_id',
              'checkout_session_id',
              'checkoutSessionId',
              'session_id',
              'sessionId',
            ],
            [item],
          ).trim();
      if (isStripeCheckoutSessionId(paymentSessionId)) return true;
    }

    return false;
  }

  bool _requestHasReusableStripeCheckoutSession(
    Map<String, dynamic> request, {
    bool includeLocal = false,
  }) {
    if (!_requestHasStripeCheckoutSession(
      request,
      includeLocal: includeLocal,
    )) {
      return false;
    }

    return stripeCheckoutSessionCanBeReused(request) &&
        !_requestRequiresNewCheckoutSession(request);
  }

  bool _requestRequiresNewCheckoutSession(Map<String, dynamic> request) {
    if (!_requestHasStripeCheckoutSession(request, includeLocal: true)) {
      return false;
    }

    return stripeCheckoutSessionRequiresNewCheckout(request);
  }

  List<Map<String, dynamic>> _paymentsFromRow(Map<String, dynamic> row) {
    final direct = row['payments'];
    if (direct is List) {
      return direct
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    final data = _asStringKeyMap(row['data']);
    final dataPayments = data['payments'];
    if (dataPayments is List) {
      return dataPayments
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    final reservation = _asStringKeyMap(row['reservation']);
    final nested = reservation['payments'];
    if (nested is List) {
      return nested
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    final dataReservation = _asStringKeyMap(data['reservation']);
    final nestedDataPayments = dataReservation['payments'];
    if (nestedDataPayments is List) {
      return nestedDataPayments
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return const [];
  }

  bool _isTruthyValue(Object? value) {
    if (value == true) return true;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return const {'1', 'true', 'yes', 'si'}.contains(normalized);
  }

  bool _accessIsActive(Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) return false;
    final state = resolveCommercialAccessState(payload);
    if (state.isConfirmedActive) {
      return true;
    }

    final data = _asStringKeyMap(payload['data']);
    final access = _asStringKeyMap(
      payload['access'] ?? payload['commercial_access'],
    );
    final dataAccess = _asStringKeyMap(
      data['access'] ?? data['commercial_access'],
    );
    for (final candidate in [data, access, dataAccess]) {
      if (candidate.isEmpty) continue;
      final nestedState = resolveCommercialAccessState(candidate);
      if (nestedState.isConfirmedActive) {
        return true;
      }
    }

    return false;
  }

  List<PaymentBreakdownItem> _commercialAccessBreakdown(
    Map<String, dynamic>? accessData,
    Map<String, dynamic> request,
  ) {
    final preview = _commercialAccessPaymentPreview(accessData, request);
    if (preview.isEmpty) return const [];

    final latestPayment = _commercialAccessLatestPayment(accessData, request);
    final currency = _commercialAccessCurrency(preview, latestPayment);
    final billingPlan = _asStringKeyMap(preview['billing_plan']);

    final baseAmount =
        _toAmount(
          latestPayment['base_amount'] ??
              preview['base_amount'] ??
              billingPlan['amount'],
        ) ??
        0;
    final stripeFee =
        _toAmount(latestPayment['stripe_fee'] ?? preview['stripe_fee']) ?? 0;
    final administrativeFee =
        _toAmount(
          latestPayment['administrative_fee'] ?? preview['administrative_fee'],
        ) ??
        0;
    final totalAmount =
        _toAmount(
          latestPayment['total_amount'] ??
              latestPayment['amount'] ??
              preview['total_amount'],
        ) ??
        0;

    return [
      if (baseAmount > 0)
        PaymentBreakdownItem(
          label: 'Precio base',
          value: _formatCurrency(baseAmount, currency),
        ),
      if (stripeFee > 0)
        PaymentBreakdownItem(
          label: 'Comision Stripe',
          value: _formatCurrency(stripeFee, currency),
        ),
      if (administrativeFee > 0)
        PaymentBreakdownItem(
          label: 'Cargo administrativo',
          value: _formatCurrency(administrativeFee, currency),
        ),
      if (totalAmount > 0)
        PaymentBreakdownItem(
          label: 'Total a pagar',
          value: _formatCurrency(totalAmount, currency),
          total: true,
        ),
    ];
  }

  List<PaymentBreakdownItem> _reservationPaymentBreakdown(
    Map<String, dynamic> request,
  ) {
    final data = _asStringKeyMap(request['data']);
    final reservation = _asStringKeyMap(request['reservation']);
    final dataReservation = _asStringKeyMap(data['reservation']);
    final pricingContext = _asStringKeyMap(request['pricing_context']);
    final dataPricingContext = _asStringKeyMap(data['pricing_context']);
    final reservationPricingContext = _asStringKeyMap(
      reservation['pricing_context'],
    );
    final snapshotRecord = _asStringKeyMap(request['aircraft_snapshot']);
    final dataSnapshotRecord = _asStringKeyMap(data['aircraft_snapshot']);
    final paymentPreview = _reservationPaymentPreview(request);
    final currency = _reservationCurrency(
      request,
      pricingContext.isNotEmpty ? pricingContext : dataPricingContext,
      snapshotRecord.isNotEmpty ? snapshotRecord : dataSnapshotRecord,
    );
    final flightCost =
        _toAmount(
          request['flight_cost'] ??
              data['flight_cost'] ??
              reservation['flight_cost'] ??
              dataReservation['flight_cost'] ??
              pricingContext['flight_cost'] ??
              dataPricingContext['flight_cost'] ??
              reservationPricingContext['flight_cost'] ??
              snapshotRecord['flight_cost'] ??
              dataSnapshotRecord['flight_cost'] ??
              paymentPreview['flight_cost'] ??
              request['base_amount'] ??
              data['base_amount'] ??
              pricingContext['base_amount'] ??
              dataPricingContext['base_amount'] ??
              snapshotRecord['base_amount'] ??
              paymentPreview['base_amount'],
        ) ??
        0;
    final stripeFee =
        _toAmount(
          request['stripe_fee'] ??
              data['stripe_fee'] ??
              reservation['stripe_fee'] ??
              pricingContext['stripe_fee'] ??
              dataPricingContext['stripe_fee'] ??
              snapshotRecord['stripe_fee'] ??
              paymentPreview['stripe_fee'],
        ) ??
        0;
    final administrativeFee =
        _toAmount(
          request['administrative_fee'] ??
              data['administrative_fee'] ??
              reservation['administrative_fee'] ??
              pricingContext['administrative_fee'] ??
              dataPricingContext['administrative_fee'] ??
              snapshotRecord['administrative_fee'] ??
              paymentPreview['administrative_fee'],
        ) ??
        0;
    final totalAmount =
        _toAmount(
          request['total_amount'] ??
              data['total_amount'] ??
              reservation['total_amount'] ??
              dataReservation['total_amount'] ??
              pricingContext['total_amount'] ??
              dataPricingContext['total_amount'] ??
              pricingContext['total_amount'] ??
              reservationPricingContext['total_amount'] ??
              snapshotRecord['total_amount'] ??
              dataSnapshotRecord['total_amount'] ??
              paymentPreview['total_amount'] ??
              paymentPreview['amount_due'] ??
              request['amount_due'] ??
              request['final_price'] ??
              request['estimated_total'] ??
              data['final_price'] ??
              data['estimated_total'] ??
              reservation['final_price'] ??
              dataReservation['final_price'] ??
              snapshotRecord['final_price'] ??
              snapshotRecord['estimated_total'],
        ) ??
        0;

    return [
      if (flightCost > 0)
        PaymentBreakdownItem(
          label: 'Costo del vuelo',
          value: _formatCurrency(flightCost, currency),
        ),
      if (stripeFee > 0)
        PaymentBreakdownItem(
          label: 'Comision Stripe',
          value: _formatCurrency(stripeFee, currency),
        ),
      if (administrativeFee > 0)
        PaymentBreakdownItem(
          label: 'Cargo administrativo',
          value: _formatCurrency(administrativeFee, currency),
        ),
      if (totalAmount > 0)
        PaymentBreakdownItem(
          label: 'Total a pagar',
          value: _formatCurrency(totalAmount, currency),
          total: true,
        ),
    ];
  }

  Map<String, dynamic> _commercialAccessPaymentPreview(
    Map<String, dynamic>? accessData,
    Map<String, dynamic> request,
  ) {
    final access = _asStringKeyMap(accessData);
    final accessCommercial = _asStringKeyMap(
      access['commercial_access'] ??
          access['commercialAccess'] ??
          access['access'],
    );
    final requestCommercial = _asStringKeyMap(request['commercial_access']);

    for (final candidate in [
      request['payment_preview'],
      requestCommercial['payment_preview'],
      access['payment_preview'],
      accessCommercial['payment_preview'],
    ]) {
      final map = _asStringKeyMap(candidate);
      if (map.isNotEmpty) return map;
    }

    return const <String, dynamic>{};
  }

  Map<String, dynamic> _commercialAccessLatestPayment(
    Map<String, dynamic>? accessData,
    Map<String, dynamic> request,
  ) {
    final access = _asStringKeyMap(accessData);
    final accessCommercial = _asStringKeyMap(
      access['commercial_access'] ??
          access['commercialAccess'] ??
          access['access'],
    );
    final requestCommercial = _asStringKeyMap(request['commercial_access']);

    for (final candidate in [
      request['latest_payment'],
      requestCommercial['latest_payment'],
      access['latest_payment'],
      accessCommercial['latest_payment'],
    ]) {
      final map = _asStringKeyMap(candidate);
      if (map.isNotEmpty) return map;
    }

    return const <String, dynamic>{};
  }

  String _commercialAccessCurrency(
    Map<String, dynamic> preview,
    Map<String, dynamic> latestPayment,
  ) {
    final billingPlan = _asStringKeyMap(preview['billing_plan']);
    final currency = _firstTextFromMaps(
      const ['currency'],
      [latestPayment, preview, billingPlan],
    );
    return currency.isEmpty ? 'USD' : currency.toUpperCase();
  }

  String _reservationCurrency(
    Map<String, dynamic> request,
    Map<String, dynamic> pricingContext,
    Map<String, dynamic> snapshotRecord,
  ) {
    final currency = _firstTextFromMaps(
      const ['currency'],
      [request, pricingContext, snapshotRecord],
    );
    return currency.isEmpty ? 'USD' : currency.toUpperCase();
  }

  String? _breakdownTotalLabel(List<PaymentBreakdownItem> items) {
    for (final item in items) {
      if (item.total) return item.value;
    }
    return null;
  }

  double? _toAmount(dynamic value) {
    if (value is num) return value.toDouble();
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    return double.tryParse(raw.replaceAll(',', ''));
  }

  String _formatCurrency(double amount, String currency) {
    final normalizedCurrency =
        currency.trim().isEmpty ? 'USD' : currency.trim().toUpperCase();
    final fixed = amount.toStringAsFixed(2);
    if (normalizedCurrency == 'USD' || normalizedCurrency == 'MXN') {
      return '$normalizedCurrency \$$fixed';
    }
    return '$normalizedCurrency $fixed';
  }

  String _firstText(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }

    final data = payload['data'];
    if (data is Map) {
      return _firstText(Map<String, dynamic>.from(data), keys);
    }

    return '';
  }
}
