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

  static bool get hasActiveCommercialAccessHandler =>
      _activeCommercialAccessHandlers > 0;

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
  bool _stripeCardReady = false;
  bool _stripeCardLoading = false;
  String _inlineMessage = '';
  String _accessCheckoutSessionId = '';
  String _stripeCardError = '';
  String _lastHandledCheckoutReturnUri = '';
  Map<String, dynamic>? _cardPaymentIntentSeed;
  Map<String, dynamic>? _wireInstructions;
  StreamSubscription<Uri>? _appLinkSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.commercialAccessMode) {
      ClientPaymentScreen._activeCommercialAccessHandlers++;
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
    if (_paymentMethod == 'card') {
      unawaited(_ensureStripeCardReady());
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
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
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
    if (!widget.commercialAccessMode) return;
    if (uri.scheme != kMobileCheckoutReturnScheme) return;
    if (uri.host != kMobileCheckoutReturnHost) return;
    if (uri.path != kMobileCheckoutReturnPath) return;
    final uriKey = uri.toString();
    if (_lastHandledCheckoutReturnUri == uriKey) return;
    _lastHandledCheckoutReturnUri = uriKey;

    final checkoutResult =
        uri.queryParameters['checkout']?.trim().toLowerCase() ?? '';
    final sessionId = uri.queryParameters['session_id']?.trim() ?? '';

    if (sessionId.isNotEmpty) {
      _accessCheckoutSessionId = sessionId;
    }

    if (!mounted) return;

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
      return '$kMobileCheckoutReturnScheme://$kMobileCheckoutReturnHost'
          '$kMobileCheckoutReturnPath'
          '?checkout=$checkout'
          '&session_id={CHECKOUT_SESSION_ID}'
          '&refresh=commercial_access';
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
    final normalizedCheckout =
        checkout == 'cancel' ? 'cancelled' : checkout;

    return '${baseUri.origin}$basePath/client/access-payment/mobile-return'
        '?checkout=$normalizedCheckout'
        '&session_id={CHECKOUT_SESSION_ID}';
  }

  @override
  Widget build(BuildContext context) {
    final amount =
        widget.commercialAccessMode
            ? 'USD \$115 / mes'
            : _amountLabel(widget.request);
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
                : _paymentMethod == 'card'
                ? 'Pagar ahora'
                : _paymentMethod == 'wire'
                ? 'Generar referencia bancaria'
                : 'Pagar ahora',
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
              child: const Text(
                'Configura tu pago',
                style: TextStyle(
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
                      value: _paymentMethodSummaryLabel(),
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
                            _wireInstructions = null;
                            _inlineMessage = '';
                          });
                          unawaited(_ensureStripeCardReady());
                        },
                        child: _buildCardPaymentPanel(),
                      ),
                      const SizedBox(height: 10),
                      _CompactPaymentOption(
                        label: 'Transferencia Bancaria',
                        subtitle: 'Validacion manual del comprobante',
                        selected: _paymentMethod == 'wire',
                        expanded: _paymentMethod == 'wire',
                        onTap: () {
                          setState(() {
                            _paymentMethod = 'wire';
                            _inlineMessage = '';
                          });
                        },
                        child: _buildWirePaymentPanel(),
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
                            _wireInstructions = null;
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ClientThemeColors.brandNavy,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tarjeta Corporativa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _cardBrandLabel(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Visa • Mastercard • Amex',
                style: TextStyle(
                  color: Color(0xFFD5E2EE),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD8E0E8)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 18,
                ),
                child: CardField(
                  controller: _stripeCardController,
                  enablePostalCode: false,
                  dangerouslyGetFullCardDetails: false,
                  cursorColor: ClientThemeColors.brandNavy,
                  numberHintText: '1234 5678 9012 3456',
                  expirationHintText: 'MM/AA',
                  cvcHintText: 'CVC',
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
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
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const _SecurityBullet(label: 'Pago seguro con Stripe'),
              const SizedBox(height: 8),
              const _SecurityBullet(label: 'Datos cifrados'),
              const SizedBox(height: 8),
              const _SecurityBullet(label: 'Sin almacenamiento local'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWirePaymentPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _InputField(
          controller: _wireReferenceController,
          label: 'Referencia bancaria',
          hint: 'Folio o comprobante',
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFEFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEADFCE)),
          ),
          child: const Text(
            'Generamos referencia bancaria y el pago queda pendiente hasta validar comprobante.',
            style: TextStyle(color: Color(0xFF3B3428), height: 1.4),
          ),
        ),
        if (_wireInstructions != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4FAF6),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD9EFE1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Referencia generada',
                  style: TextStyle(
                    color: Color(0xFF1F5F3C),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_wireInstructionText(_wireInstructions!)),
              ],
            ),
          ),
        ],
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
    if (!_isContractSigned(widget.request)) {
      _debugStripeCheckoutState(
        label: 'bloqueado_por_contrato',
        flightRequestId: flightRequestId,
        reservationId: reservationId,
      );
      setState(() {
        _inlineMessage = 'Primero debes firmar el contrato';
      });
      return;
    }
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
          _wireInstructions = instructions;
          _inlineMessage =
              'Transferencia preparada. El pago queda pendiente hasta validar el comprobante.';
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
                name: _customerName(context),
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
    if (!_isContractSigned(widget.request)) {
      _debugStripeCheckoutState(
        label: 'bloqueado_por_contrato',
        flightRequestId: flightRequestId,
        reservationId: reservationId,
      );
      setState(() {
        _inlineMessage = 'Primero debes firmar el contrato';
      });
      return;
    }
    if (flightRequestId.isEmpty) {
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
      final effectiveReservationId = await _ensureReservationId(
        flightRequestId: flightRequestId,
        reservationId: reservationId,
        logPrefix: '[Pago]',
      );
      final paymentPayload = _reservationCheckoutPayload(
        reservationId: effectiveReservationId,
      );
      _debugStripeCheckoutState(
        label: 'antes_checkout',
        flightRequestId: flightRequestId,
        reservationId: effectiveReservationId,
        endpoint:
            '/cliente/stripe/checkout/create, fallback /stripe/checkout/create',
        body: {
          'flight_request_id': flightRequestId,
          'booking_id': flightRequestId,
          'success_url': _buildCommercialAccessReturnUrl(
            'success',
            includeStripeSessionPlaceholder: true,
          ),
          'cancel_url': _buildCommercialAccessReturnUrl('cancel'),
          'return_url': _buildCommercialAccessReturnUrl(
            'success',
            includeStripeSessionPlaceholder: true,
          ),
          ...paymentPayload,
        },
      );
      final payload = await ApiClient.instance.createClientCheckout(
        flightRequestId: flightRequestId,
        paymentPayload: paymentPayload,
        successUrl: _buildCommercialAccessReturnUrl(
          'success',
          includeStripeSessionPlaceholder: true,
        ),
        cancelUrl: _buildCommercialAccessReturnUrl('cancel'),
        returnUrl: _buildCommercialAccessReturnUrl(
          'success',
          includeStripeSessionPlaceholder: true,
        ),
      );

      final redirectUrl = _checkoutUrl(payload);
      _debugStripeCheckoutState(
        label: 'respuesta_checkout',
        flightRequestId: flightRequestId,
        reservationId: effectiveReservationId,
        endpoint:
            '/cliente/stripe/checkout/create, fallback /stripe/checkout/create',
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

      if (!mounted) return;
      setState(() {
        _inlineMessage =
            'Link de pago abierto. Completa el checkout seguro y vuelve a la app para continuar.';
      });
    } on ApiException catch (error) {
      debugPrint(
        '[Pago][StripeCheckout] error_backend=${error.message} payload=${jsonEncode(error.payload ?? const {})}',
      );
      if (!mounted) return;
      setState(() => _inlineMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineMessage = 'No fue posible abrir el link de pago: $error';
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
    return request['flight_request_id']?.toString().trim().isNotEmpty == true
        ? request['flight_request_id'].toString().trim()
        : request['request_id']?.toString().trim().isNotEmpty == true
        ? request['request_id'].toString().trim()
        : request['id']?.toString().trim().isNotEmpty == true &&
            (request['reservation_id']?.toString().trim().isEmpty ?? true)
        ? request['id'].toString().trim()
        : '';
  }

  String _reservationId(Map<String, dynamic> request) {
    return request['reservation_id']?.toString().trim().isNotEmpty == true
        ? request['reservation_id'].toString().trim()
        : request['booking_id']?.toString().trim().isNotEmpty == true
        ? request['booking_id'].toString().trim()
        : (request['reservation'] is Map &&
            (request['reservation']['id']?.toString().trim().isNotEmpty ??
                false))
        ? request['reservation']['id'].toString().trim()
        : '';
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

  bool _isContractSigned(Map<String, dynamic> request) {
    final contract = _asStringKeyMap(request['contract']);
    final frontendState = _asStringKeyMap(request['frontend_state']);
    final contractFrontendState = _asStringKeyMap(contract['frontend_state']);

    final status =
        _firstTextFromMaps(
          const [
            'contract_status',
            'signature_status',
            'status',
            'workflow_status',
          ],
          [request, contract, frontendState, contractFrontendState],
        ).toLowerCase();

    if (const {
      'signed',
      'contract_signed',
      'completed',
      'complete',
      'firmado',
      'contrato firmado',
      'pago pendiente',
      'payment_pending',
      'payment_confirmed',
      'paid',
    }.contains(status)) {
      return true;
    }

    final signedPdf = _firstTextFromMaps(
      const ['signed_pdf_url', 'signedPdfUrl', 'contract_pdf_url'],
      [request, contract, frontendState, contractFrontendState],
    );
    if (signedPdf.isNotEmpty) return true;

    return request['contract_signed'] == true ||
        request['contract_completed'] == true ||
        contract['contract_signed'] == true ||
        contract['contract_completed'] == true ||
        frontendState['contract_signed'] == true ||
        frontendState['contract_completed'] == true ||
        contractFrontendState['contract_signed'] == true ||
        contractFrontendState['contract_completed'] == true;
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
    if (widget.commercialAccessMode) {
      return _paymentMethod == 'card'
          ? 'Tarjeta corporativa'
          : 'Stripe Checkout';
    }
    switch (_paymentMethod) {
      case 'wire':
        return 'Transferencia bancaria';
      case 'link':
        return 'Link de pago';
      case 'card':
      default:
        return 'Tarjeta corporativa';
    }
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
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
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

class _SecurityBullet extends StatelessWidget {
  const _SecurityBullet({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: ClientThemeColors.accent,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
