import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/proveedor_autenticacion.dart';
import '../../providers/proveedor_reservaciones.dart';
import '../../services/servicio_persistencia_flujo_cliente.dart';
import '../../services/servicio_notificaciones.dart';
import '../../core/cliente_api.dart';
import '../../core/client_request_matcher.dart';
import '../reservation/pantalla_reservacion.dart';
import 'tema_cliente.dart';
import 'views/pantalla_confirmacion_reserva_cliente.dart';
import 'views/pantalla_contrato_cliente.dart';
import 'views/pantalla_historial_cliente.dart';
import 'views/pantalla_perfil_en_vivo_cliente.dart';
import 'views/pantalla_pago_cliente.dart';
import 'views/pantalla_resultados_cliente.dart';
import 'widgets/widgets_flujo_movil_cliente.dart';

class ClientMobileWorkspaceScreen extends StatefulWidget {
  const ClientMobileWorkspaceScreen({super.key});

  @override
  State<ClientMobileWorkspaceScreen> createState() =>
      _ClientMobileWorkspaceScreenState();
}

class _ClientMobileWorkspaceScreenState
    extends State<ClientMobileWorkspaceScreen>
    with WidgetsBindingObserver {
  static const Duration _tripsAutoRefreshInterval = Duration(seconds: 12);
  int _selectedIndex = 0;
  int _searchSession = 0;
  _TripsStage _tripsStage = _TripsStage.list;
  String? _selectedRequestId;
  Timer? _workspaceSyncTimer;
  final ClientFlowPersistenceService _flowPersistence =
      ClientFlowPersistenceService();
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        unawaited(auth.refreshCommercialAccessStatus());
      }
      unawaited(_restorePersistedFlow());
    });
    _workspaceSyncTimer = Timer.periodic(_tripsAutoRefreshInterval, (_) {
      unawaited(_refreshTripsWorkspaceIfVisible(force: true));
    });
    _notificationSubscription = PushNotificationsService.openedMessages.listen((
      payload,
    ) {
      unawaited(_openReservationFromNotification(payload));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _workspaceSyncTimer?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    unawaited(auth.refreshCommercialAccessStatus());
    unawaited(_refreshTripsWorkspaceIfVisible(force: true));
    unawaited(_persistCurrentFlow());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final reservation = context.watch<ReservationProvider>();
    final userInitial = _userInitial(auth.displayName);
    final activeRequest = _findRequestById(reservation, _selectedRequestId);

    final screens = [
      ReservationScreen(
        key: ValueKey('reservation-$_searchSession'),
        userInitial: userInitial,
        onQuoteReady: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => ClientResultsScreen(
                    userInitial: userInitial,
                    onBackToSearch: _resetSearchFlow,
                    onReservationCreated: _openReservationConfirmation,
                    onCommercialAccessRequired: _openCommercialAccessPayment,
                  ),
            ),
          );
        },
      ),
      _buildTripsScreen(activeRequest),
      ClientLiveProfileScreen(
        showBackButton: false,
        onCommercialAccessTap: _openCommercialAccessPayment,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF07111D),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: screens),
          ),
        ],
      ),
      bottomNavigationBar: ClientMobileBottomNav(
        currentIndex: _selectedIndex,
        onSelect: (index) {
          setState(() {
            _selectedIndex = index;
            if (index == 1) {
              _tripsStage = _TripsStage.list;
            }
          });
          if (index == 1) {
            unawaited(_refreshTripsWorkspaceIfVisible(force: true));
          }
        },
      ),
    );
  }

  Future<void> _refreshTripsWorkspaceIfVisible({required bool force}) async {
    if (!mounted || _selectedIndex != 1) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    await context.read<ReservationProvider>().loadClientWorkspaceData(
      force: force,
    );
  }

  String _userInitial(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return 'C';
    return trimmed.substring(0, 1).toUpperCase();
  }

  void _resetSearchFlow() {
    context.read<ReservationProvider>().resetForm();
    setState(() {
      _searchSession++;
      _selectedIndex = 0;
    });
    Navigator.of(context).pop();
    unawaited(_persistCurrentFlow());
  }

  void _openReservationConfirmation(String? requestId) {
    setState(() {
      _selectedIndex = 1;
      _tripsStage = _TripsStage.confirmation;
      _selectedRequestId = requestId;
    });
    Navigator.of(context).pop();
    unawaited(_persistCurrentFlow());
  }

  void _openAvailabilityAlternatives() {
    setState(() {
      _selectedIndex = 0;
      _tripsStage = _TripsStage.list;
    });
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ClientResultsScreen(
              userInitial: _userInitial(
                context.read<AuthProvider>().displayName,
              ),
              onBackToSearch: _resetSearchFlow,
              onReservationCreated: _openReservationConfirmation,
              onCommercialAccessRequired: _openCommercialAccessPayment,
            ),
      ),
    );
  }

  Widget _buildTripsScreen(Map<String, dynamic>? activeRequest) {
    if (_tripsStage != _TripsStage.list && activeRequest == null) {
      return _MissingClientRequestScreen(
        onBack: () {
          setState(() {
            _selectedRequestId = null;
            _tripsStage = _TripsStage.list;
          });
        },
      );
    }
    switch (_tripsStage) {
      case _TripsStage.contract:
        return ClientContractScreen(
          request: activeRequest ?? const {},
          showBackButton: false,
          onAircraftUnavailable: _openAvailabilityAlternatives,
          onOpenTrips: () {
            setState(() {
              _tripsStage = _TripsStage.list;
            });
          },
          onConfirm: () async {
            final reservationProvider = context.read<ReservationProvider>();
            await reservationProvider.loadClientWorkspaceData(force: true);
            if (!mounted) return;
            final refreshedRequest = _resolveLatestRequest(
              reservationProvider,
              activeRequest,
            );
            setState(() {
              _selectedIndex = 1;
              _selectedRequestId = _preferredRequestId(refreshedRequest);
              _tripsStage = _TripsStage.list;
            });
          },
        );
      case _TripsStage.payment:
        return ClientPaymentScreen(
          key: ValueKey(_paymentScreenKey(activeRequest)),
          request: activeRequest ?? const {},
          showBackButton: false,
          onBack: () {
            setState(() {
              _tripsStage = _TripsStage.contract;
            });
          },
          onOpenTrips: () {
            setState(() {
              _selectedIndex = 1;
              _tripsStage = _TripsStage.list;
            });
          },
          onPaymentComplete: () async {
            final reservationProvider = context.read<ReservationProvider>();
            await reservationProvider.loadClientWorkspaceData(force: true);
            if (!mounted) return;
            final refreshedRequest = _resolveLatestRequest(
              reservationProvider,
              activeRequest,
            );
            setState(() {
              _selectedRequestId = _preferredRequestId(refreshedRequest);
              _selectedIndex = 1;
              _tripsStage = _TripsStage.list;
            });
          },
          onAircraftUnavailable: (_) {
            _openAvailabilityAlternatives();
          },
        );
      case _TripsStage.confirmation:
        return ClientBookingConfirmationScreen(
          request: activeRequest ?? const {},
          showBackButton: false,
          onOpenTrips: () {
            setState(() {
              _tripsStage = _TripsStage.list;
            });
          },
        );
      case _TripsStage.list:
        return ClientHistoryScreen(
          showBackButton: false,
          onOpenSearch: () {
            setState(() {
              _selectedIndex = 0;
            });
          },
          onOpenContract: (request) {
            setState(() {
              _selectedRequestId = _preferredRequestId(request);
              _tripsStage = _TripsStage.contract;
            });
            unawaited(_persistCurrentFlow(request: request));
          },
          onOpenPayment: (request) {
            setState(() {
              _selectedRequestId = _preferredRequestId(request);
              _tripsStage = _TripsStage.payment;
            });
            unawaited(_persistCurrentFlow(request: request));
          },
          onCommercialAccessRequired: _openCommercialAccessPayment,
        );
    }
  }

  void _openCommercialAccessPayment({bool openMembershipAfter = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ClientPaymentScreen(
              request: const {},
              commercialAccessMode: true,
              onPaymentComplete: () async {
                await context
                    .read<AuthProvider>()
                    .refreshCommercialAccessStatus();
                if (!mounted) return;
                Navigator.of(context).pop();
                await context
                    .read<ReservationProvider>()
                    .loadClientWorkspaceData(force: true);
                if (!mounted) return;
                if (openMembershipAfter) {
                  setState(() {
                    _selectedIndex = 2;
                  });
                }
              },
            ),
      ),
    );
  }

  Map<String, dynamic>? _findRequestById(
    ReservationProvider reservation,
    String? requestId,
  ) {
    return findClientRequestByExactId(reservation.flightRequests, requestId);
  }

  Map<String, dynamic>? _resolveLatestRequest(
    ReservationProvider reservation,
    Map<String, dynamic>? currentRequest,
  ) {
    final currentId = _preferredRequestId(currentRequest);
    if (currentId != null && currentId.isNotEmpty) {
      final byId = _findRequestById(reservation, currentId);
      if (byId != null) return byId;
    }

    if (currentRequest == null || currentRequest.isEmpty) return null;

    for (final request in reservation.flightRequests) {
      if (_sameRequest(request, currentRequest)) return request;
    }

    return currentRequest;
  }

  String? _preferredRequestId(Map<String, dynamic>? request) {
    if (request == null || request.isEmpty) return null;
    return request['id']?.toString() ??
        request['flight_request_id']?.toString() ??
        request['request_id']?.toString() ??
        request['reservation_id']?.toString() ??
        request['booking_id']?.toString();
  }

  bool _sameRequest(Map<String, dynamic> left, Map<String, dynamic> right) {
    final leftIds = {
      left['id']?.toString(),
      left['flight_request_id']?.toString(),
      left['request_id']?.toString(),
      left['reservation_id']?.toString(),
      left['booking_id']?.toString(),
    }..removeWhere((value) => value == null || value.isEmpty);
    final rightIds = {
      right['id']?.toString(),
      right['flight_request_id']?.toString(),
      right['request_id']?.toString(),
      right['reservation_id']?.toString(),
      right['booking_id']?.toString(),
    }..removeWhere((value) => value == null || value.isEmpty);
    return leftIds.any(rightIds.contains);
  }

  String _paymentScreenKey(Map<String, dynamic>? request) {
    if (request == null || request.isEmpty) return 'payment-empty';
    final id = _preferredRequestId(request) ?? 'no-id';
    final workflow = request['workflow_status']?.toString() ?? '';
    final contract = request['contract_status']?.toString() ?? '';
    final signed = request['contract_signed'] == true ? 'signed' : 'unsigned';
    return 'payment-$id-$workflow-$contract-$signed';
  }

  Future<void> _restorePersistedFlow() async {
    final reservationProvider = context.read<ReservationProvider>();
    final persisted = await _flowPersistence.load();
    await reservationProvider.loadClientWorkspaceData(force: true);
    if (!mounted) return;
    reservationProvider.restoreSearchDraft(
      persisted['search_draft'] is Map
          ? Map<String, dynamic>.from(persisted['search_draft'] as Map)
          : const {},
    );

    final stageName = persisted['stage']?.toString() ?? '';
    final restoredStage = _TripsStage.values.where(
      (stage) => stage.name == stageName,
    );
    setState(() {
      final persistedRequestId =
          persisted['current_request_id']?.toString().trim() ?? '';
      final persistedReservationId =
          persisted['current_reservation_id']?.toString().trim() ?? '';
      _selectedRequestId =
          persistedRequestId.isNotEmpty
              ? persistedRequestId
              : persistedReservationId.isNotEmpty
              ? persistedReservationId
              : null;
      _tripsStage =
          restoredStage.isEmpty ? _TripsStage.list : restoredStage.first;
      _selectedIndex =
          _tripsStage == _TripsStage.list && _selectedRequestId == null ? 0 : 1;
    });
    for (final payload
        in PushNotificationsService.takePendingOpenedMessages()) {
      if (!mounted) return;
      await _openReservationFromNotification(payload);
    }
  }

  Future<void> _persistCurrentFlow({Map<String, dynamic>? request}) async {
    final active =
        request ??
        _findRequestById(
          context.read<ReservationProvider>(),
          _selectedRequestId,
        );
    await _flowPersistence.save({
      'current_request_id': _preferredRequestId(active) ?? _selectedRequestId,
      'current_reservation_id':
          active?['reservation_id']?.toString() ??
          (active?['reservation'] is Map
              ? (active!['reservation'] as Map)['id']?.toString()
              : null),
      'selected_aircraft_id':
          context.read<ReservationProvider>().selectedAircraft?.id ??
          active?['aircraft_id']?.toString(),
      'stage': _tripsStage.name,
      'search_draft': context.read<ReservationProvider>().exportSearchDraft(),
    });
  }

  Future<void> _openReservationFromNotification(
    Map<String, dynamic> payload,
  ) async {
    final reservationId =
        payload['reservation_id']?.toString().trim() ??
        payload['reservationId']?.toString().trim() ??
        '';
    if (reservationId.isEmpty || !mounted) return;

    final auth = context.read<AuthProvider>();
    final provider = context.read<ReservationProvider>();
    try {
      final verified = await ApiClient.instance.getAuthorizedClientReservation(
        reservationId,
      );
      if (!clientOwnsReservationPayload(verified, auth.user?.id ?? '')) {
        throw const ApiException(
          'La reservacion de la notificacion no pertenece al usuario actual.',
          statusCode: 403,
        );
      }

      await provider.loadClientWorkspaceData(force: true);
      if (!mounted) return;
      final exactRequest = _findRequestById(provider, reservationId);
      if (exactRequest == null) {
        throw const ApiException(
          'La reservacion no esta disponible para el usuario actual.',
          statusCode: 404,
        );
      }
      setState(() {
        _selectedRequestId = reservationId;
        _selectedIndex = 1;
        _tripsStage = _TripsStage.confirmation;
      });
      await _persistCurrentFlow(request: exactRequest);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

enum _TripsStage { list, contract, payment, confirmation }

class _MissingClientRequestScreen extends StatelessWidget {
  const _MissingClientRequestScreen({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.clientPalette.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'No encontramos una solicitud que coincida exactamente con este enlace. Por seguridad no abrimos contrato ni pago.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onBack,
                  child: const Text('Volver a Tus vuelos'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
