import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
                await context
                    .read<AuthProvider>()
                    .refreshCommercialAccessStatus();
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
    final hasAccess =
        commercialState.hasPaidAccess || commercialState.canReserve;
    final expiryLabel = _expiryLabel(subscription, commercialState);

    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        decoration: const BoxDecoration(
          color: Color(0xFF050505),
          border: Border(bottom: BorderSide(color: Color(0x22111111))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x26FFFFFF)),
              ),
              alignment: Alignment.center,
              child: Icon(
                hasAccess ? Icons.verified_rounded : Icons.workspace_premium,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasAccess ? 'Membresia activa' : 'Acceso comercial',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    expiryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFD8D8D8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: onRefresh,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(
                Icons.sync_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
            TextButton(
              onPressed: onOpenMembership,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                backgroundColor: const Color(0x14FFFFFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: const BorderSide(color: Color(0x22FFFFFF)),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ver plan',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _expiryLabel(
    dynamic subscription,
    CommercialAccessState commercialState,
  ) {
    final rawDate =
        subscription is Map
            ? subscription['current_period_end'] ??
                subscription['expires_at'] ??
                subscription['renewal_date']
            : null;
    final parsed =
        rawDate == null ? null : DateTime.tryParse(rawDate.toString());
    if (parsed != null) {
      return 'Vence el ${DateFormat('dd MMM yyyy', 'es_MX').format(parsed).toLowerCase()}';
    }
    if (commercialState.expiresAtLabel.isNotEmpty) {
      return 'Vence el ${commercialState.expiresAtLabel}';
    }
    return hasAccessLabel(commercialState);
  }

  String hasAccessLabel(CommercialAccessState state) {
    if (state.hasPaidAccess || state.canReserve) {
      return 'Membresia disponible';
    }
    return state.statusLabel;
  }
}
