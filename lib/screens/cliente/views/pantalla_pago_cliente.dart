import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/acceso_comercial_cliente.dart';
import '../../../core/cliente_api.dart';
import '../../../providers/proveedor_autenticacion.dart';
import '../../../providers/proveedor_reservaciones.dart';
import '../tema_cliente.dart';
import '../widgets/widgets_experiencia_cliente.dart';

const String kMobileCheckoutReturnScheme = 'redsky';
const String kMobileCheckoutReturnHost = 'cliente';
const String kMobileCheckoutReturnPath = '/pago';

class ClientPaymentScreen extends StatefulWidget {
  const ClientPaymentScreen({
    super.key,
    required this.request,
    required this.onPaymentComplete,
    this.onBack,
    this.commercialAccessMode = false,
    this.showBackButton = true,
    this.initialCheckoutReturnUri,
  });

  final Map<String, dynamic> request;
  final VoidCallback onPaymentComplete;
  final VoidCallback? onBack;
  final bool commercialAccessMode;
  final bool showBackButton;
  final Uri? initialCheckoutReturnUri;

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
  bool _waitingForCommercialAccessReturn = false;
  bool _waitingForReservationCheckoutReturn = false;
  bool _stripeCardReady = false;
  bool _stripeCardLoading = false;
  String _inlineMessage = '';
  String _accessCheckoutSessionId = '';
  String _reservationCheckoutSessionId = '';
  String _stripeCardError = '';
  String _lastHandledCheckoutReturnUri = '';
  Map<String, dynamic>? _cardPaymentIntentSeed;
  StreamSubscription<Uri>? _appLinkSubscription;

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
    final initialEmail = auth.user?.email.trim() ?? '';
    if (initialEmail.isNotEmpty) {
      _emailController.text = initialEmail;
    }
    _bindCheckoutReturnLinks();
    final initialReturnUri = widget.initialCheckoutReturnUri;
    if (initialReturnUri != null) {
      unawaited(_handleIncomingCheckoutUri(initialReturnUri));
    }
    _syncContractWarningVisibility();
    _scheduleRefreshSignedContractState();
    if (_paymentMethod == 'card') {
      unawaited(_ensureStripeCardReady());
    }
  }

  @override
  void didUpdateWidget(covariant ClientPaymentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.request, widget.request)) {
      _syncContractWarningVisibility();
      _scheduleRefreshSignedContractState();
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
      if (_waitingForReservationCheckoutReturn) {
        unawaited(_validateReservationCheckoutReturn());
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
    if (_lastHandledCheckoutReturnUri == uriKey) return;
    _lastHandledCheckoutReturnUri = uriKey;

    final checkoutResult =
        uri.queryParameters['checkout']?.trim().toLowerCase() ?? '';
    final sessionId =
        (uri.queryParameters['session_id'] ??
                uri.queryParameters['checkout_session_id'] ??
                uri.queryParameters['checkoutSessionId'] ??
                uri.queryParameters['sessionId'] ??
                '')
            .trim();

    if (sessionId.isNotEmpty) {
      if (widget.commercialAccessMode) {
        _accessCheckoutSessionId = sessionId;
      } else {
        _reservationCheckoutSessionId = sessionId;
      }
    }

    if (!mounted) return;

    if (!widget.commercialAccessMode) {
      if (checkoutResult == 'cancel' || checkoutResult == 'cancelled') {
        await ApiClient.instance
            .cancelClientCheckout(
              sessionId: sessionId.isEmpty ? null : sessionId,
            )
            .catchError((_) => <String, dynamic>{});
        setState(() {
          _waitingForReservationCheckoutReturn = false;
          _inlineMessage =
              'Stripe Checkout fue cancelado. Puedes intentarlo de nuevo cuando quieras.';
        });
        return;
      }

      setState(() {
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
    ).replace(
      queryParameters: {
        'checkout': normalizedCheckout,
        'session_id': '{CHECKOUT_SESSION_ID}',
        'refresh': 'commercial_access',
      },
    ).toString();
  }

  String _buildReservationPaymentBackendReturnUrl(String checkout) {
    final reservationId = _reservationId(widget.request);
    final flightRequestId = _flightRequestId(widget.request);

    final baseUri = Uri.tryParse(ApiClient.instance.baseUrl);
    if (baseUri == null || baseUri.scheme.isEmpty || baseUri.host.isEmpty) {
      return Uri(
        scheme: kMobileCheckoutReturnScheme,
        host: kMobileCheckoutReturnHost,
        path: kMobileCheckoutReturnPath,
        queryParameters: {
          'checkout': checkout,
          'session_id': '{CHECKOUT_SESSION_ID}',
          'refresh': 'flight_payment',
          'reservation_id': reservationId,
          'flight_request_id': flightRequestId,
        },
      ).toString();
    }

    final basePath = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    final normalizedCheckout = checkout == 'cancel' ? 'cancelled' : checkout;

    return Uri.parse(
      '${baseUri.origin}$basePath/client/flight-payment/mobile-return',
    ).replace(
      queryParameters: {
        'checkout': normalizedCheckout,
        'session_id': '{CHECKOUT_SESSION_ID}',
        'refresh': 'flight_payment',
        'reservation_id': reservationId,
        'flight_request_id': flightRequestId,
      },
    ).toString();
  }

  @override
  Widget build(BuildContext context) {
    final accessData = context.watch<AuthProvider>().accessData;
    final paymentBreakdown =
        widget.commercialAccessMode
            ? _commercialAccessBreakdown(accessData, widget.request)
            : _reservationPaymentBreakdown(widget.request);
    final amount =
        widget.commercialAccessMode
            ? (_breakdownTotalLabel(paymentBreakdown) ?? 'USD \$115 / mes')
            : (_breakdownTotalLabel(paymentBreakdown) ??
                _amountLabel(widget.request));
    final route =
        widget.commercialAccessMode
            ? 'Activa el acceso comercial para reservar, firmar contrato y pagar vuelos.'
            : _routeLabel(widget.request);
    final passengerCount = (widget.request['passengers'] ?? '1').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      bottomNavigationBar: _PaymentStickyFooter(
        totalLabel: amount,
        ctaLabel:
            _submitting
                ? 'Procesando...'
                : widget.commercialAccessMode
                ? 'Activar acceso comercial'
                : 'Abrir Stripe Checkout',
        onPressed: _canSubmit && !_submitting ? _submitPayment : null,
        isLoading: _submitting,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 170),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (widget.showBackButton || widget.onBack != null)
                    _PaymentRoundActionButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: _handleBack,
                    ),
                  if (widget.showBackButton || widget.onBack != null)
                    const SizedBox(width: 10),
                  const Spacer(),
                  const StatusBadge(
                    label: 'Checkout seguro',
                    color: Color(0xFF2D6A4F),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.commercialAccessMode
                    ? 'Configura tu pago'
                    : 'Pago de vuelo',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111111),
                  height: 0.98,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.commercialAccessMode
                        ? 'Acceso comercial premium'
                        : route,
                    style: const TextStyle(
                      color: Color(0xFF1E1E1E),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.commercialAccessMode
                        ? 'Renovacion mensual protegida'
                        : '$passengerCount ${passengerCount == '1' ? 'pasajero' : 'pasajeros'}',
                    style: const TextStyle(
                      color: Color(0xFF625D55),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFE5EAF0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140E2238),
                      blurRadius: 26,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        color: Color(0xFF7A6A53),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      amount,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.commercialAccessMode ? 'Acceso comercial' : route,
                      style: const TextStyle(
                        color: Color(0xFF3B3428),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (paymentBreakdown.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F3EB),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE6DDCE)),
                        ),
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < paymentBreakdown.length;
                              index++
                            )
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      index == paymentBreakdown.length - 1
                                          ? 0
                                          : 8,
                                ),
                                child: _PaymentRow(
                                  label: paymentBreakdown[index].label,
                                  value: paymentBreakdown[index].value,
                                  emphasize: paymentBreakdown[index].total,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: ClientThemeColors.brandNavy,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pago seguro',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tu reserva esta protegida mediante Stripe y validacion bancaria.',
                            style: TextStyle(
                              color: Color(0xFFD5E2EE),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GlassInfoCard(
                backgroundColor: ClientThemeColors.brandNavy,
                borderColor: const Color(0xFF29445A),
                shadowColor: const Color(0x1A102438),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RESERVA',
                      style: TextStyle(
                        color: Color(0xFFD6E1EA),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.commercialAccessMode
                          ? 'Acceso comercial premium'
                          : route,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PaymentRow(
                      label: 'Pasajeros',
                      value:
                          widget.commercialAccessMode
                              ? 'Membresia mensual'
                              : '$passengerCount ${passengerCount == '1' ? 'pasajero' : 'pasajeros'}',
                      onDark: true,
                    ),
                    _PaymentRow(
                      label: 'Metodo',
                      value:
                          widget.commercialAccessMode
                              ? _paymentMethodSummaryLabel()
                              : 'Stripe Checkout externo',
                      onDark: true,
                    ),
                    _PaymentRow(
                      label: 'Total',
                      value: amount,
                      emphasize: true,
                      onDark: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!widget.commercialAccessMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ExternalCheckoutCard(
                  title: 'Checkout externo',
                  description:
                      'El cobro se completa fuera de la app en Stripe. Al terminar, volveras automaticamente para validar tu reserva.',
                  status:
                      _waitingForReservationCheckoutReturn
                          ? 'Esperando regreso de Stripe'
                          : 'Listo para abrir enlace seguro',
                ),
              ),
            if (!widget.commercialAccessMode) const SizedBox(height: 12),
            if (widget.commercialAccessMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassInfoCard(
                  backgroundColor: ClientThemeColors.brandNavy,
                  borderColor: const Color(0xFF29445A),
                  shadowColor: const Color(0x1A102438),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Metodo de pago',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (widget.commercialAccessMode)
                      Column(
                        children: [
                          if (_showCommercialCardPaymentOption)
                            _CompactPaymentOption(
                              label: 'Tarjeta Corporativa',
                              subtitle: 'Visa • Mastercard • Amex',
                              selected: _paymentMethod == 'card',
                              expanded: _paymentMethod == 'card',
                              onTap: () {
                                setState(() {
                                  _paymentMethod = 'card';
                                  _inlineMessage = '';
                                });
                                unawaited(_ensureStripeCardReady());
                              },
                              child: _buildCardPaymentPanel(),
                            ),
                          if (_showCommercialCardPaymentOption)
                            const SizedBox(height: 10),
                          _CompactPaymentOption(
                            label: 'Agregar tarjeta con Stripe',
                            subtitle:
                                'Captura tu tarjeta en la pagina segura de Stripe',
                            selected: _paymentMethod == 'link',
                            expanded: _paymentMethod == 'link',
                            onTap: () {
                              setState(() {
                                _paymentMethod = 'link';
                                _inlineMessage = '';
                              });
                            },
                            child: _buildLinkPaymentPanel(),
                          ),
                        ],
                      )
                    else ...[
                      _CompactPaymentOption(
                        label: 'Tarjeta Corporativa',
                        subtitle: 'Visa • Mastercard • Amex',
                        selected: _paymentMethod == 'card',
                        expanded: _paymentMethod == 'card',
                        onTap: () {
                          setState(() {
                            _paymentMethod = 'card';
                            _inlineMessage = '';
                          });
                          unawaited(_ensureStripeCardReady());
                        },
                        child: _buildCardPaymentPanel(),
                      ),
                      const SizedBox(height: 10),
                      _CompactPaymentOption(
                        label: 'Link de Pago',
                        subtitle: 'Abrimos Stripe Checkout en un enlace seguro',
                        selected: _paymentMethod == 'link',
                        expanded: _paymentMethod == 'link',
                        onTap: () {
                          setState(() {
                            _paymentMethod = 'link';
                            _inlineMessage = '';
                          });
                        },
                        child: _buildLinkPaymentPanel(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GlassInfoCard(
                backgroundColor: ClientThemeColors.brandNavy,
                borderColor: const Color(0xFF29445A),
                shadowColor: const Color(0x1A102438),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Datos de contacto',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InputField(
                      controller: _emailController,
                      label: 'Correo electronico',
                      hint: 'cliente@empresa.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    if (_inlineMessage.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        _inlineMessage,
                        style: TextStyle(
                          color: _messageColor(),
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                              'Visa • Mastercard • Amex',
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
                        _CardBrandMark(brand: _cardBrand()),
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
                        child: _CardMetaItem(
                          label: 'Titular',
                          value: _cardHolderPreview(),
                          alignEnd: false,
                        ),
                      ),
                      SizedBox(width: compactSpacing ? 10 : 12),
                      Expanded(
                        child: _CardMetaItem(
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
    if (!_hasValidContactEmail) return false;
    if (widget.commercialAccessMode) {
      if (_paymentMethod == 'card') return _cardDetails?.complete ?? false;
      return true;
    }
    if (_paymentMethod == 'link') return true;
    if (_paymentMethod == 'card') {
      return _cardDetails?.complete ?? false;
    }
    return _wireReferenceController.text.trim().isNotEmpty;
  }

  bool get _hasValidContactEmail {
    final email = _contactEmail;
    if (email.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  String get _contactEmail => _emailController.text.trim().toLowerCase();

  bool get _showCommercialCardPaymentOption => false;

  Future<void> _submitPayment() async {
    if (widget.commercialAccessMode) {
      if (_paymentMethod == 'card') {
        await _submitCommercialAccessCardPayment();
      } else {
        await _submitCommercialAccessPayment();
      }
      return;
    }
    if (_paymentMethod == 'link') {
      await _submitReservationCheckoutLink();
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
      final responseReservationId = _responseReservationId(intent);
      final confirmedReservationId =
          responseReservationId.isNotEmpty
              ? responseReservationId
              : effectiveReservationId;

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
        reservationProvider.markPaymentConfirmed(
          flightRequestId: flightRequestId,
          reservationId: confirmedReservationId,
          paymentIntentId: _paymentIntentId(intent),
          brand: _cardBrand(),
        );
        try {
          await ApiClient.instance.confirmClientPaymentIntent(
            flightRequestId: flightRequestId,
            paymentPayload: {
              'reservation_id': confirmedReservationId,
              'flight_request_id': flightRequestId,
              'payment_intent_id': _paymentIntentId(intent),
              'brand': _cardBrand(),
              'status': 'payment_confirmed',
              'workflow_status': 'pago confirmado',
              'payment_status': 'paid',
            },
          );
        } on ApiException catch (error) {
          if (!_isMissingPaymentConfirmRoute(error)) rethrow;
        }
        if (confirmedReservationId.isNotEmpty) {
          try {
            await ApiClient.instance.confirmClientPayment(
              reservationId: confirmedReservationId,
              paymentPayload: {
                'reservation_id': confirmedReservationId,
                'flight_request_id': flightRequestId,
                'payment_intent_id': _paymentIntentId(intent),
                'brand': _cardBrand(),
                'status': 'payment_confirmed',
                'workflow_status': 'pago confirmado',
                'payment_status': 'paid',
              },
            );
          } on ApiException catch (error) {
            if (!_isMissingPaymentConfirmRoute(error)) rethrow;
          }
        }
        if (!mounted) return;
        widget.onPaymentComplete();
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
      final backendSuccessUrl = _buildCommercialAccessBackendReturnUrl(
        'success',
      );
      final backendCancelUrl = _buildCommercialAccessBackendReturnUrl('cancel');
      final payload = await ApiClient.instance.createClientAccessCheckout(
        paymentPayload: {
          'contact_email': _contactEmail,
          'successUrl': backendSuccessUrl,
          'cancelUrl': backendCancelUrl,
        },
        successUrl: backendSuccessUrl,
        cancelUrl: backendCancelUrl,
        returnUrl: backendSuccessUrl,
      );
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

      final opened = await launchUrl(
        Uri.parse(redirectUrl),
        mode: LaunchMode.externalApplication,
      );

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
    final opened = await launchUrl(
      Uri.parse(redirectUrl),
      mode: LaunchMode.externalApplication,
    );

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

  Future<void> _submitReservationCheckoutLink() async {
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
      _inlineMessage = 'Preparando link de pago...';
    });

    try {
      unawaited(_resolveContractSignedState(refreshWorkspace: true));
      final effectiveReservationId =
          reservationId.isNotEmpty
              ? reservationId
              : await _ensureReservationId(
                flightRequestId: effectiveFlightRequestId,
                reservationId: reservationId,
                logPrefix: '[Pago]',
              );
      final paymentPayload = _reservationCheckoutPayload(
        reservationId: effectiveReservationId,
      );
      await _syncReservationReadyForCheckout(
        reservationId: effectiveReservationId,
        flightRequestId: effectiveFlightRequestId,
      );
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
        debugPrint(
          '[Pago][StripeCheckout] backend_sin_url=${jsonEncode(payload)}',
        );
        throw ApiException(
          _backendErrorMessage(payload).isNotEmpty
              ? _backendErrorMessage(payload)
              : 'El backend no devolvio una URL para el link de pago.',
        );
      }

      final opened = await launchUrl(
        Uri.parse(redirectUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw const ApiException('No fue posible abrir el link de pago.');
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
            'Link de pago abierto. Completa el checkout seguro y vuelve a la app para continuar.';
      });
    } on ApiException catch (error) {
      debugPrint(
        '[Pago][StripeCheckout] error_backend=${error.message} payload=${jsonEncode(error.payload ?? const {})}',
      );
      if (!mounted) return;
      setState(() {
        _inlineMessage =
            _isContractGateError(error)
                ? 'La firma ya fue enviada. Estamos sincronizando el estado de pago; vuelve a tocar Abrir Stripe Checkout en unos segundos.'
                : error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineMessage = 'No fue posible abrir el link de pago: $error';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _syncReservationReadyForCheckout({
    required String reservationId,
    required String flightRequestId,
  }) async {
    final normalizedReservationId = reservationId.trim();
    if (normalizedReservationId.isEmpty) return;

    final payload = {
      'reservation_id': normalizedReservationId,
      'booking_id': normalizedReservationId,
      if (flightRequestId.trim().isNotEmpty)
        'flight_request_id': flightRequestId.trim(),
      'status': 'pending_payment',
      'workflow_status': 'pago pendiente',
      'contract_status': 'signed',
      'payment_status': 'pending',
      'frontend_state': {
        'ready_for_payment': true,
        'next_action': 'go_to_payment',
        'ui_status': 'completed',
      },
      'signed_at': DateTime.now().toIso8601String(),
    };

    try {
      final synced = await ApiClient.instance.signClientContract(
        reservationId: normalizedReservationId,
        contractPayload: payload,
      );
      _mergeRequestSnapshot(synced);
    } catch (error) {
      debugPrint('[Pago][ready_for_checkout_sync_ignored] $error');
    }
  }

  bool _isContractGateError(ApiException error) {
    final message = [
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

    final reservationProvider = context.read<ReservationProvider>();
    final flightRequestId = _flightRequestId(widget.request);
    final reservationId = _reservationId(widget.request);

    setState(() {
      _submitting = true;
      _inlineMessage = 'Validando pago del vuelo...';
    });

    try {
      Map<String, dynamic>? successPayload;
      Map<String, dynamic> refreshedMatch = const <String, dynamic>{};
      for (var attempt = 0; attempt < 5; attempt++) {
        successPayload = await ApiClient.instance
            .getClientCheckoutSuccess(
              sessionId:
                  _reservationCheckoutSessionId.isEmpty
                      ? null
                      : _reservationCheckoutSessionId,
            )
            .catchError((_) => <String, dynamic>{});

        if (successPayload.isNotEmpty &&
            (_requestIndicatesPaymentConfirmed(successPayload) ||
                _requestIndicatesPaymentPending(successPayload))) {
          break;
        }

        await reservationProvider.loadClientWorkspaceData(force: true);
        refreshedMatch = _matchingRequestFromProvider(reservationProvider);
        if (refreshedMatch.isNotEmpty &&
            (_requestIndicatesPaymentConfirmed(refreshedMatch) ||
                _requestIndicatesPaymentPending(refreshedMatch))) {
          break;
        }

        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }

      if (successPayload != null && successPayload.isNotEmpty) {
        _mergeRequestSnapshot(successPayload);
      }

      if (refreshedMatch.isEmpty) {
        await reservationProvider.loadClientWorkspaceData(force: true);
        refreshedMatch = _matchingRequestFromProvider(reservationProvider);
      }
      if (refreshedMatch.isNotEmpty) {
        _mergeRequestSnapshot(refreshedMatch);
      }

      final currentSnapshot =
          refreshedMatch.isNotEmpty ? refreshedMatch : widget.request;

      if (_requestIndicatesPaymentConfirmed(currentSnapshot)) {
        final effectiveReservationId =
            _reservationId(currentSnapshot).isNotEmpty
                ? _reservationId(currentSnapshot)
                : reservationId;
        reservationProvider.markPaymentConfirmed(
          flightRequestId: flightRequestId,
          reservationId: effectiveReservationId,
          paymentIntentId: _paymentIntentId(currentSnapshot),
          brand: _cardBrand(),
        );
        if (!mounted) return;
        setState(() {
          _waitingForReservationCheckoutReturn = false;
          _inlineMessage = 'Pago confirmado.';
        });
        widget.onPaymentComplete();
        return;
      }

      if (_requestIndicatesPaymentPending(currentSnapshot)) {
        final effectiveReservationId =
            _reservationId(currentSnapshot).isNotEmpty
                ? _reservationId(currentSnapshot)
                : reservationId;

        reservationProvider.markPaymentPending(
          flightRequestId: flightRequestId,
          reservationId: effectiveReservationId,
          checkoutSessionId: _reservationCheckoutSessionId,
        );
        if (!mounted) return;
        setState(() {
          _waitingForReservationCheckoutReturn = false;
          _inlineMessage =
              'Checkout completado. El pago esta en validacion y tu reserva ya quedo en seguimiento.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _waitingForReservationCheckoutReturn = false;
        _inlineMessage =
            'Stripe regreso a la app, pero el backend aun no confirma el pago. Revisa nuevamente en unos segundos.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _waitingForReservationCheckoutReturn = false;
        _inlineMessage =
            'No fue posible validar automaticamente el pago: $error';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
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
      for (var attempt = 0; attempt < 4; attempt++) {
        successPayload = await ApiClient.instance
            .getClientAccessPaymentSuccess(
              sessionId:
                  _accessCheckoutSessionId.isEmpty
                      ? null
                      : _accessCheckoutSessionId,
            )
            .catchError((_) => <String, dynamic>{});

        if (_accessIsActive(successPayload)) break;
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }

      if (!mounted) return;
      if (successPayload != null && successPayload.isNotEmpty) {
        auth.syncAccessState(successPayload);
      }
      await auth.refreshCommercialAccessStatus();
      final accessState = resolveCommercialAccessState(auth.accessData);

      if (!mounted) return;

      if (accessState.canReserve || accessState.hasPaidAccess) {
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
        );
      } catch (_) {
        successPayload = null;
      }

      if (successPayload != null && successPayload.isNotEmpty) {
        auth.syncAccessState(successPayload);
      }

      await auth.refreshCommercialAccessStatus();
      final accessState = resolveCommercialAccessState(auth.accessData);
      if (accessState.canReserve || accessState.hasPaidAccess) {
        return true;
      }

      await Future<void>.delayed(const Duration(milliseconds: 900));
    }

    return false;
  }

  String _routeLabel(Map<String, dynamic> request) {
    final origin =
        request['origin']?.toString() ??
        request['base_airport']?.toString() ??
        'Origen';
    final destination = request['destination']?.toString() ?? 'Destino';
    return '$origin -> $destination';
  }

  String _amountLabel(Map<String, dynamic> request) {
    return request['formatted_final_price']?.toString() ??
        request['final_price_display']?.toString() ??
        request['estimated_total']?.toString() ??
        request['final_price']?.toString() ??
        'Monto por confirmar';
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

    final nested = _firstTextFromMaps(const ['id'], [
      flightRequest,
      dataFlightRequest,
    ]);
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
      const [
        'reservation_id',
        'reservationId',
        'booking_id',
        'bookingId',
      ],
      [request, data],
    );
    if (direct.isNotEmpty) return direct;

    return _firstTextFromMaps(const ['id'], [reservation, dataReservation]);
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
    final signed = await _resolveContractSignedState(refreshWorkspace: true);
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
      await reservationProvider.loadClientWorkspaceData(force: true);
      final refreshedMatch = _matchingRequestFromProvider(reservationProvider);
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
    final flightRequestId = _flightRequestId(widget.request);
    final reservationId = _reservationId(widget.request);
    final requestId = widget.request['id']?.toString().trim() ?? '';

    bool matches(Map<String, dynamic> row) {
      final rowFlightRequestId = _flightRequestId(row);
      final rowReservationId = _reservationId(row);
      final rowId = row['id']?.toString().trim() ?? '';
      return (flightRequestId.isNotEmpty &&
              rowFlightRequestId == flightRequestId) ||
          (reservationId.isNotEmpty && rowReservationId == reservationId) ||
          (requestId.isNotEmpty && rowId == requestId);
    }

    for (final row in reservationProvider.flightRequests) {
      if (matches(row)) return Map<String, dynamic>.from(row);
    }
    for (final row in reservationProvider.reservations) {
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
    final state = _asStringKeyMap(payload['frontend_state']);
    final contract = _asStringKeyMap(payload['contract']);
    final reservation = _asStringKeyMap(payload['reservation']);
    final data = _asStringKeyMap(payload['data']);
    final dataState = _asStringKeyMap(data['frontend_state']);
    final dataContract = _asStringKeyMap(data['contract']);
    final dataReservation = _asStringKeyMap(data['reservation']);
    final reservationState = _asStringKeyMap(reservation['frontend_state']);
    final nestedState = _asStringKeyMap(contract['frontend_state']);
    final dataReservationState = _asStringKeyMap(
      dataReservation['frontend_state'],
    );
    final dataContractState = _asStringKeyMap(dataContract['frontend_state']);
    final statusSummary = _asStringKeyMap(payload['status_summary']);
    final dataStatusSummary = _asStringKeyMap(data['status_summary']);
    final nextAction = _firstTextFromMaps(
      const ['next_action', 'nextAction'],
      [
        payload,
        state,
        reservation,
        reservationState,
        contract,
        nestedState,
        data,
        dataState,
        dataReservation,
        dataReservationState,
        dataContract,
        dataContractState,
      ],
    ).toLowerCase();

    return _isTruthyValue(state['ready_for_payment']) ||
        _isTruthyValue(reservation['ready_for_payment']) ||
        _isTruthyValue(reservationState['ready_for_payment']) ||
        _isTruthyValue(contract['ready_for_payment']) ||
        _isTruthyValue(nestedState['ready_for_payment']) ||
        _isTruthyValue(data['ready_for_payment']) ||
        _isTruthyValue(dataState['ready_for_payment']) ||
        _isTruthyValue(dataReservation['ready_for_payment']) ||
        _isTruthyValue(dataReservationState['ready_for_payment']) ||
        _isTruthyValue(dataContract['ready_for_payment']) ||
        _isTruthyValue(dataContractState['ready_for_payment']) ||
        _isTruthyValue(statusSummary['payment_enabled']) ||
        _isTruthyValue(statusSummary['is_signed']) ||
        _isTruthyValue(dataStatusSummary['payment_enabled']) ||
        _isTruthyValue(dataStatusSummary['is_signed']) ||
        nextAction == 'go_to_payment' ||
        nextAction == 'go_to_history';
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

    final status =
        _firstTextFromMaps(
          const [
            'docusign_status',
            'contract_status',
            'signature_status',
            'ui_status',
            'status',
            'workflow_status',
            'envelope_status',
          ],
          [
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
          ],
        ).toLowerCase();

    if (const {
      'signed',
      'contract_signed',
      'completed',
      'complete',
      'approved',
      'firmado',
      'contrato firmado',
      'pago pendiente',
      'payment_pending',
      'payment_confirmed',
      'paid',
      'signing_complete',
      'signing_completed',
    }.contains(status)) {
      return true;
    }

    final signedPdf = _firstTextFromMaps(
      const [
        'signed_pdf_url',
        'signedPdfUrl',
        'contract_pdf_url',
        'contract_url',
        'contract_document_url',
      ],
      [
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
      ],
    );
    if (signedPdf.isNotEmpty) return true;

    return _isTruthyValue(request['contract_signed']) ||
        _isTruthyValue(request['contract_completed']) ||
        _isTruthyValue(request['contract_ready']) ||
        _isTruthyValue(data['contract_signed']) ||
        _isTruthyValue(data['contract_completed']) ||
        _isTruthyValue(data['contract_ready']) ||
        _isTruthyValue(reservation['contract_signed']) ||
        _isTruthyValue(reservation['contract_completed']) ||
        _isTruthyValue(reservation['contract_ready']) ||
        _isTruthyValue(dataReservation['contract_signed']) ||
        _isTruthyValue(dataReservation['contract_completed']) ||
        _isTruthyValue(dataReservation['contract_ready']) ||
        _isTruthyValue(contract['contract_signed']) ||
        _isTruthyValue(contract['contract_completed']) ||
        _isTruthyValue(contract['contract_ready']) ||
        _isTruthyValue(dataContract['contract_signed']) ||
        _isTruthyValue(dataContract['contract_completed']) ||
        _isTruthyValue(dataContract['contract_ready']) ||
        _isTruthyValue(frontendState['contract_signed']) ||
        _isTruthyValue(frontendState['contract_completed']) ||
        _isTruthyValue(frontendState['contract_ready']) ||
        _isTruthyValue(dataFrontendState['contract_signed']) ||
        _isTruthyValue(dataFrontendState['contract_completed']) ||
        _isTruthyValue(dataFrontendState['contract_ready']) ||
        _isTruthyValue(reservationFrontendState['contract_signed']) ||
        _isTruthyValue(reservationFrontendState['contract_completed']) ||
        _isTruthyValue(reservationFrontendState['contract_ready']) ||
        _isTruthyValue(dataReservationFrontendState['contract_signed']) ||
        _isTruthyValue(dataReservationFrontendState['contract_completed']) ||
        _isTruthyValue(dataReservationFrontendState['contract_ready']) ||
        _isTruthyValue(contractFrontendState['contract_signed']) ||
        _isTruthyValue(contractFrontendState['contract_completed']) ||
        _isTruthyValue(contractFrontendState['contract_ready']) ||
        _isTruthyValue(dataContractFrontendState['contract_signed']) ||
        _isTruthyValue(dataContractFrontendState['contract_completed']) ||
        _isTruthyValue(dataContractFrontendState['contract_ready']) ||
        _isTruthyValue(statusSummary['payment_enabled']) ||
        _isTruthyValue(statusSummary['is_signed']) ||
        _isTruthyValue(dataStatusSummary['payment_enabled']) ||
        _isTruthyValue(dataStatusSummary['is_signed']);
  }

  Map<String, dynamic> _reservationCheckoutPayload({
    required String reservationId,
  }) {
    return {
      'contact_email': _emailController.text.trim(),
      'reservation_id': reservationId,
      'booking_id': reservationId,
      'payment_method': 'stripe_checkout',
    };
  }

  String _checkoutUrl(Map<String, dynamic> payload) {
    final data = _asStringKeyMap(payload['data']);
    return _firstTextFromMaps(
      const [
        'checkout_url',
        'checkoutUrl',
        'management_url',
        'managementUrl',
        'url',
      ],
      [payload, data],
    );
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

  String _responseReservationId(Map<String, dynamic> payload) {
    final data = payload['data'];
    final reservation =
        payload['reservation'] ?? (data is Map ? data['reservation'] : null);

    return (payload['reservation_id'] ??
            payload['booking_id'] ??
            (reservation is Map ? reservation['id'] : null) ??
            (data is Map ? data['reservation_id'] : null) ??
            (data is Map ? data['reservationId'] : null) ??
            (data is Map ? data['booking_id'] : null) ??
            (data is Map ? data['bookingId'] : null) ??
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

  String _paymentMethodSummaryLabel() {
    if (widget.commercialAccessMode) {
      return _paymentMethod == 'card'
          ? 'Tarjeta corporativa'
          : 'Stripe Checkout';
    }
    return 'Stripe Checkout externo';
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

  bool _isMissingPaymentConfirmRoute(ApiException error) {
    final message = error.message.toLowerCase();
    return (error.statusCode == 404 || error.statusCode == 405) &&
        (message.contains('payment/confirm') ||
            message.contains('payments/confirm') ||
            message.contains('pago/confirmar') ||
            message.contains('could not be found') ||
            message.contains('not found'));
  }

  bool _requestIndicatesPaymentConfirmed(Map<String, dynamic> request) {
    final data = _asStringKeyMap(request['data']);
    final contract = _asStringKeyMap(request['contract']);
    final reservation = _asStringKeyMap(request['reservation']);
    final dataReservation = _asStringKeyMap(data['reservation']);
    final dataContract = _asStringKeyMap(data['contract']);
    final paymentOrder = _asStringKeyMap(request['payment_order']);
    final dataPaymentOrder = _asStringKeyMap(data['payment_order']);
    final payments = _paymentsFromRow(request);

    final status =
        _firstTextFromMaps(
          const [
            'status',
            'workflow_status',
            'payment_status',
            'checkout_status',
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
        _isTruthyValue(dataReservation['is_paid'])) {
      return true;
    }

    for (final payment in payments) {
      final paymentStatus = payment['status']?.toString().trim().toLowerCase();
      if (const {
        'paid',
        'succeeded',
        'payment_confirmed',
      }.contains(paymentStatus)) {
        return true;
      }
    }

    return false;
  }

  bool _requestIndicatesPaymentPending(Map<String, dynamic> request) {
    if (_requestIndicatesPaymentConfirmed(request)) return false;

    final data = _asStringKeyMap(request['data']);
    final contract = _asStringKeyMap(request['contract']);
    final reservation = _asStringKeyMap(request['reservation']);
    final dataReservation = _asStringKeyMap(data['reservation']);
    final dataContract = _asStringKeyMap(data['contract']);
    final paymentOrder = _asStringKeyMap(request['payment_order']);
    final dataPaymentOrder = _asStringKeyMap(data['payment_order']);
    final payments = _paymentsFromRow(request);

    final status =
        _firstTextFromMaps(
          const [
            'status',
            'workflow_status',
            'payment_status',
            'checkout_status',
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
    }.contains(status)) {
      return true;
    }

    for (final payment in payments) {
      final paymentStatus = payment['status']?.toString().trim().toLowerCase();
      if (const {
        'pending',
        'processing',
        'payment_pending',
      }.contains(paymentStatus)) {
        return true;
      }
    }

    return false;
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
    if (state.hasPaidAccess || state.canReserve) return true;

    final access = payload['access'];
    if (access is Map) {
      final nestedState = resolveCommercialAccessState(
        Map<String, dynamic>.from(access),
      );
      return nestedState.hasPaidAccess || nestedState.canReserve;
    }

    final payment = payload['payment'];
    if (payment is Map) {
      final status = payment['status']?.toString().trim().toLowerCase() ?? '';
      return const {
        'paid',
        'succeeded',
        'success',
        'complete',
        'completed',
        'pagado',
        'payment_confirmed',
      }.contains(status);
    }

    return false;
  }

  List<_PaymentBreakdownItem> _commercialAccessBreakdown(
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
        _PaymentBreakdownItem(
          label: 'Precio base',
          value: _formatCurrency(baseAmount, currency),
        ),
      if (stripeFee > 0)
        _PaymentBreakdownItem(
          label: 'Comision Stripe',
          value: _formatCurrency(stripeFee, currency),
        ),
      if (administrativeFee > 0)
        _PaymentBreakdownItem(
          label: 'Cargo administrativo',
          value: _formatCurrency(administrativeFee, currency),
        ),
      if (totalAmount > 0)
        _PaymentBreakdownItem(
          label: 'Total a pagar',
          value: _formatCurrency(totalAmount, currency),
          total: true,
        ),
    ];
  }

  List<_PaymentBreakdownItem> _reservationPaymentBreakdown(
    Map<String, dynamic> request,
  ) {
    final pricingContext = _asStringKeyMap(request['pricing_context']);
    final snapshotRecord = _asStringKeyMap(request['aircraft_snapshot']);
    final currency = _reservationCurrency(
      request,
      pricingContext,
      snapshotRecord,
    );
    final flightCost =
        _toAmount(
          request['flight_cost'] ??
              pricingContext['flight_cost'] ??
              snapshotRecord['flight_cost'] ??
              request['base_amount'] ??
              pricingContext['base_amount'] ??
              snapshotRecord['base_amount'],
        ) ??
        0;
    final stripeFee =
        _toAmount(
          request['stripe_fee'] ??
              pricingContext['stripe_fee'] ??
              snapshotRecord['stripe_fee'],
        ) ??
        0;
    final administrativeFee =
        _toAmount(
          request['administrative_fee'] ??
              pricingContext['administrative_fee'] ??
              snapshotRecord['administrative_fee'],
        ) ??
        0;
    final totalAmount =
        _toAmount(
          request['total_amount'] ??
              pricingContext['total_amount'] ??
              snapshotRecord['total_amount'],
        ) ??
        0;

    return [
      if (flightCost > 0)
        _PaymentBreakdownItem(
          label: 'Costo del vuelo',
          value: _formatCurrency(flightCost, currency),
        ),
      if (stripeFee > 0)
        _PaymentBreakdownItem(
          label: 'Comision Stripe',
          value: _formatCurrency(stripeFee, currency),
        ),
      if (administrativeFee > 0)
        _PaymentBreakdownItem(
          label: 'Cargo administrativo',
          value: _formatCurrency(administrativeFee, currency),
        ),
      if (totalAmount > 0)
        _PaymentBreakdownItem(
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

  String? _breakdownTotalLabel(List<_PaymentBreakdownItem> items) {
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

class _PaymentBreakdownItem {
  const _PaymentBreakdownItem({
    required this.label,
    required this.value,
    this.total = false,
  });

  final String label;
  final String value;
  final bool total;
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      cursorColor: ClientThemeColors.brandNavy,
      style: const TextStyle(
        color: Color(0xFF102438),
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(
          color: Color(0xFF6C7680),
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF102438),
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF9AA5AF),
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _PaymentRoundActionButton extends StatelessWidget {
  const _PaymentRoundActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE4EAF0)),
        ),
        child: Icon(icon, color: ClientThemeColors.brandNavy, size: 20),
      ),
    );
  }
}

class _CardBrandMark extends StatelessWidget {
  const _CardBrandMark({required this.brand});

  final String brand;

  @override
  Widget build(BuildContext context) {
    final normalized = brand.trim().toLowerCase();
    if (normalized.contains('master')) {
      return Container(
        width: 40,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: const [
            Positioned(
              left: 9,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: Color(0xFFEB001B),
              ),
            ),
            Positioned(
              right: 9,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: Color(0xFFF79E1B),
              ),
            ),
          ],
        ),
      );
    }
    if (normalized.contains('visa')) {
      return _CardBrandTextBadge(label: 'VISA');
    }
    if (normalized.contains('amex')) {
      return _CardBrandTextBadge(label: 'AMEX');
    }
    return Container(
      width: 40,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.credit_card_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}

class _CardBrandTextBadge extends StatelessWidget {
  const _CardBrandTextBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 40, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _CardMetaItem extends StatelessWidget {
  const _CardMetaItem({
    required this.label,
    required this.value,
    required this.alignEnd,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF8FA4B8),
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.onDark = false,
  });

  final String label;
  final String value;
  final bool emphasize;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color:
                    onDark
                        ? (emphasize ? Colors.white : const Color(0xFFD6E1EA))
                        : (emphasize
                            ? const Color(0xFF111111)
                            : const Color(0xFF625D55)),
                fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: onDark ? Colors.white : const Color(0xFF111111),
                fontWeight: emphasize ? FontWeight.w900 : FontWeight.w800,
                fontSize: emphasize ? 18 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactPaymentOption extends StatelessWidget {
  const _CompactPaymentOption({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.expanded,
    required this.onTap,
    required this.child,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final bool expanded;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF7FAFD) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              selected ? ClientThemeColors.brandNavy : ClientThemeColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color:
                        selected
                            ? ClientThemeColors.brandNavy
                            : const Color(0xFF9DA8B3),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF625D55),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF625D55),
                  ),
                ],
              ),
              if (expanded) child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ExternalCheckoutCard extends StatelessWidget {
  const _ExternalCheckoutCard({
    required this.title,
    required this.description,
    required this.status,
  });

  final String title;
  final String description;
  final String status;

  @override
  Widget build(BuildContext context) {
    return GlassInfoCard(
      backgroundColor: ClientThemeColors.brandNavy,
      borderColor: const Color(0xFF29445A),
      shadowColor: const Color(0x1A102438),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: const Icon(
                  Icons.open_in_new_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      status,
                      style: const TextStyle(
                        color: Color(0xFFF5B0A8),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFFD5E2EE),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No capturamos ni guardamos tu tarjeta dentro de la app.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentStickyFooter extends StatelessWidget {
  const _PaymentStickyFooter({
    required this.totalLabel,
    required this.ctaLabel,
    required this.onPressed,
    required this.isLoading,
  });

  final String totalLabel;
  final String ctaLabel;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5EAF0))),
          boxShadow: [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 22,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total',
              style: TextStyle(
                color: Color(0xFF7A6A53),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              totalLabel,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: ClientThemeColors.brandNavy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD4DAE1),
                  disabledForegroundColor: const Color(0xFF5E6A77),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child:
                    isLoading
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Text(
                          ctaLabel.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
