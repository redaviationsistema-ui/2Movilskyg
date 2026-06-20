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
            await context.read<ReservationProvider>().loadClientWorkspaceData(
              force: true,
            );
            if (!mounted) return;
            setState(() {
              _tripsStage = _TripsStage.payment;
            });
          },
        );
      case _TripsStage.payment:
        return ClientPaymentScreen(
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
}

enum _TripsStage { list, contract, payment, confirmation }
