import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/proveedor_autenticacion.dart';
import '../../providers/proveedor_reservaciones.dart';
import '../reservation/pantalla_reservacion.dart';
import '../subscription/pantalla_centro_membresia.dart';
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
  int _selectedIndex = 0;
  int _searchSession = 0;
  _TripsStage _tripsStage = _TripsStage.list;
  String? _selectedRequestId;
  Timer? _workspaceSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ReservationProvider>().loadClientWorkspaceData();
    });
    _workspaceSyncTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (!auth.isAuthenticated) return;
      context.read<ReservationProvider>().loadClientWorkspaceData(force: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _workspaceSyncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    unawaited(auth.refreshCommercialAccessStatus());
    unawaited(
      context.read<ReservationProvider>().loadClientWorkspaceData(force: true),
    );
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
      const ClientLiveProfileScreen(showBackButton: false),
      const MembershipCenterScreen(audience: MembershipAudience.client),
    ];

    return Scaffold(
      backgroundColor: context.clientPalette.background,
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
          });
        },
      ),
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
  }

  void _openReservationConfirmation(String? requestId) {
    setState(() {
      _selectedIndex = 1;
      _tripsStage = _TripsStage.confirmation;
      _selectedRequestId = requestId;
    });
    Navigator.of(context).pop();
  }

  Widget _buildTripsScreen(Map<String, dynamic>? activeRequest) {
    switch (_tripsStage) {
      case _TripsStage.contract:
        return ClientContractScreen(
          request: activeRequest ?? const {},
          showBackButton: false,
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
              _selectedRequestId = _preferredRequestId(refreshedRequest);
              _tripsStage = _TripsStage.payment;
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
          onPaymentComplete: () async {
            final flightRequestId =
                activeRequest?['flight_request_id']?.toString() ??
                activeRequest?['request_id']?.toString() ??
                activeRequest?['id']?.toString() ??
                '';
            final reservationId =
                activeRequest?['reservation_id']?.toString() ??
                activeRequest?['booking_id']?.toString() ??
                '';
            await context.read<ReservationProvider>().loadClientWorkspaceData(
              force: true,
            );
            if (!mounted) return;
            context.read<ReservationProvider>().markPaymentConfirmed(
              flightRequestId: flightRequestId,
              reservationId: reservationId,
            );
            setState(() {
              _tripsStage = _TripsStage.confirmation;
            });
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
              _selectedRequestId = request['id']?.toString();
              _tripsStage = _TripsStage.contract;
            });
          },
          onOpenPayment: (request) {
            setState(() {
              _selectedRequestId = request['id']?.toString();
              _tripsStage = _TripsStage.payment;
            });
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
                    _selectedIndex = 3;
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
    final requests = reservation.flightRequests;
    if (requests.isEmpty) return null;
    if (requestId == null || requestId.isEmpty) {
      return requests.first;
    }

    for (final request in requests) {
      final id = request['id']?.toString();
      final flightRequestId = request['flight_request_id']?.toString();
      final reservationId = request['reservation_id']?.toString();
      final requestRecordId = request['request_id']?.toString();
      if (id == requestId ||
          flightRequestId == requestId ||
          reservationId == requestId ||
          requestRecordId == requestId) {
        return request;
      }
    }

    return requests.first;
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
}

enum _TripsStage { list, contract, payment, confirmation }
