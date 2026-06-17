import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/acceso_comercial_cliente.dart';
import '../../providers/proveedor_autenticacion.dart';
import '../../providers/proveedor_reservaciones.dart';
import '../reservation/pantalla_reservacion.dart';
import '../subscription/pantalla_centro_membresia.dart';
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
    extends State<ClientMobileWorkspaceScreen> {
  int _selectedIndex = 0;
  int _searchSession = 0;
  _TripsStage _tripsStage = _TripsStage.list;
  String? _selectedRequestId;
  Timer? _workspaceSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ReservationProvider>().loadClientWorkspaceData();
    });
    _workspaceSyncTimer = Timer.periodic(const Duration(seconds: 35), (_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (!auth.isAuthenticated) return;
      context.read<ReservationProvider>().loadClientWorkspaceData(force: true);
    });
  }

  @override
  void dispose() {
    _workspaceSyncTimer?.cancel();
    super.dispose();
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
      backgroundColor: const Color(0xFFF6F1E8),
      body: Column(
        children: [
          _MembershipPortalStatus(
            access: auth.accessData ?? const <String, dynamic>{},
            lastSyncAt: reservation.lastWorkspaceSyncAt,
            isSyncing: reservation.isLoadingWorkspace,
            onOpenMembership: () => _handleMembershipTap(auth),
            onRefresh: () {
              context.read<ReservationProvider>().loadClientWorkspaceData(
                force: true,
              );
              context.read<AuthProvider>().loadUserRole();
            },
          ),
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
          onPaymentComplete: () async {
            await context.read<ReservationProvider>().loadClientWorkspaceData(
              force: true,
            );
            if (!mounted) return;
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

  void _handleMembershipTap(AuthProvider auth) {
    final accessState = resolveCommercialAccessState(auth.accessData);
    if (accessState.requiresPayment) {
      _openCommercialAccessPayment();
      return;
    }

    setState(() {
      _selectedIndex = 3;
    });
  }

  void _openCommercialAccessPayment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ClientPaymentScreen(
              request: const {},
              commercialAccessMode: true,
              onPaymentComplete: () async {
                await context.read<AuthProvider>().refreshCommercialAccessStatus();
                if (!mounted) return;
                Navigator.of(context).pop();
                setState(() {
                  _selectedIndex = 3;
                });
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

class _MembershipPortalStatus extends StatelessWidget {
  const _MembershipPortalStatus({
    required this.access,
    required this.lastSyncAt,
    required this.isSyncing,
    required this.onOpenMembership,
    required this.onRefresh,
  });

  final Map<String, dynamic> access;
  final DateTime? lastSyncAt;
  final bool isSyncing;
  final VoidCallback onOpenMembership;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final commercialState = resolveCommercialAccessState(access);
    final subscription = access['subscription'];
    final plan =
        subscription is Map
            ? (subscription['plan_name'] ?? subscription['plan'])?.toString()
            : access['plan_name']?.toString();
    final hasAccess = commercialState.hasPaidAccess || commercialState.canReserve;
    final status = _statusLabel(access);
    final syncLabel =
        isSyncing
            ? 'Sincronizando'
            : lastSyncAt == null
            ? 'Sin sync'
            : '${lastSyncAt!.hour.toString().padLeft(2, '0')}:${lastSyncAt!.minute.toString().padLeft(2, '0')}';

    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        decoration: const BoxDecoration(
          color: Color(0xFF050505),
          border: Border(bottom: BorderSide(color: Color(0x22111111))),
        ),
        child: Row(
          children: [
            Icon(
              hasAccess ? Icons.verified_rounded : Icons.workspace_premium,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${plan?.isNotEmpty == true ? plan : 'Membresia cliente'} | $status | Sync $syncLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: onRefresh,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.sync_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            TextButton(
              onPressed: onOpenMembership,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Plan'),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(Map<String, dynamic> access) {
    return resolveCommercialAccessState(access).statusLabel;
  }
}
