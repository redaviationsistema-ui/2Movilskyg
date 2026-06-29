import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/acceso_comercial_cliente.dart';
import '../../../core/app_theme.dart';
import '../../../core/client_workflow_status.dart';
import '../../../core/media_utils.dart';
import '../../../models/aeronave.dart';
import '../../../providers/proveedor_autenticacion.dart';
import '../../../providers/proveedor_reservaciones.dart';
import '../tema_cliente.dart';
import '../views/pantalla_detalle_aeronave_cliente.dart';
import '../views/pantalla_concierge_cliente.dart';
import 'widgets_experiencia_cliente.dart';

class ClientFlightsList extends StatefulWidget {
  const ClientFlightsList({
    super.key,
    required this.heading,
    required this.description,
    this.showBackButton = true,
    this.onOpenSearch,
    this.onOpenContract,
    this.onOpenPayment,
    this.onCommercialAccessRequired,
    this.includeUpcomingTab = true,
  });

  final String heading;
  final String description;
  final bool showBackButton;
  final VoidCallback? onOpenSearch;
  final ValueChanged<Map<String, dynamic>>? onOpenContract;
  final ValueChanged<Map<String, dynamic>>? onOpenPayment;
  final VoidCallback? onCommercialAccessRequired;
  final bool includeUpcomingTab;

  @override
  State<ClientFlightsList> createState() => _ClientFlightsListState();
}

class _ClientFlightsListState extends State<ClientFlightsList>
    with WidgetsBindingObserver {
  static const Duration _autoRefreshInterval = Duration(seconds: 35);

  late _TripTab _activeTab;
  Timer? _autoRefreshTimer;
  bool _showOnlyActionRequired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _activeTab = _TripTab.upcoming;
    final provider = context.read<ReservationProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      provider.loadClientWorkspaceData();
    });

    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      _refreshFlights(force: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _refreshFlights(force: true);
  }

  Future<void> _refreshFlights({required bool force}) async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    await context.read<ReservationProvider>().loadClientWorkspaceData(
      force: force,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final provider = context.watch<ReservationProvider>();
    final allRequests = provider.flightRequests;
    final tabRequests = _filterRequests(allRequests);
    final filteredRequests =
        _showOnlyActionRequired
            ? tabRequests.where(_needsClientAttention).toList()
            : tabRequests;
    final upcomingRequests = _filterRequestsForTab(
      allRequests,
      _TripTab.upcoming,
    );
    final attentionCount = allRequests.where(_needsClientAttention).length;
    final nextFlight = upcomingRequests.isEmpty ? null : upcomingRequests.first;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ClientExperienceShell(
      title: 'Mis vuelos',
      subtitle: 'Reservas y seguimiento.',
      showBackButton: widget.showBackButton,
      child: RefreshIndicator(
        color: palette.primary,
        backgroundColor: palette.surface,
        onRefresh: () => provider.loadClientWorkspaceData(force: true),
        child: ListView(
          padding: EdgeInsets.fromLTRB(18, 10, 18, 136 + bottomInset),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    widget.heading,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: palette.textPrimary,
                      height: 1,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                StatusBadge(
                  label: '${allRequests.length} vuelos',
                  color: ClientThemeColors.accent,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.description,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            _FlightsOverviewPanel(
              totalFlights: allRequests.length,
              visibleFlights: tabRequests.length,
              attentionCount: attentionCount,
              nextFlight: nextFlight,
              loading: provider.isLoadingWorkspace,
              lastSyncAt: provider.lastWorkspaceSyncAt,
              onRefresh: () => provider.loadClientWorkspaceData(force: true),
              onOpenSearch: widget.onOpenSearch,
            ),
            const SizedBox(height: 12),
            _FlightExperienceStrip(
              attentionCount: attentionCount,
              upcomingCount: upcomingRequests.length,
              onOpenSearch: widget.onOpenSearch,
            ),
            if (provider.isLoadingWorkspace ||
                _shouldShowWorkspaceAlert(provider.workspaceMessage)) ...[
              const SizedBox(height: 14),
              _WorkspaceAlert(
                message: provider.workspaceMessage,
                loading: provider.isLoadingWorkspace,
                onRefresh: () => provider.loadClientWorkspaceData(force: true),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  _availableTabs
                      .map(
                        (tab) => _TripTabButton(
                          label: _tabLabel(tab),
                          active: _activeTab == tab,
                          onTap: () => setState(() => _activeTab = tab),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 12),
            _AttentionFilterBar(
              active: _showOnlyActionRequired,
              count: attentionCount,
              onChanged:
                  (value) => setState(() {
                    _showOnlyActionRequired = value;
                  }),
            ),
            const SizedBox(height: 16),
            if (provider.isLoadingWorkspace && allRequests.isEmpty)
              const _MinimalLoadingCard()
            else if (filteredRequests.isEmpty)
              _EmptyFlightsPanel(
                label: _activeTabLabel,
                onOpenSearch: widget.onOpenSearch,
              )
            else
              ...filteredRequests.asMap().entries.map(
                (entry) => TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 260 + entry.key * 35),
                  curve: Curves.easeOutCubic,
                  builder:
                      (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 18 * (1 - value)),
                          child: child,
                        ),
                      ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MinimalFlightCard(
                      request: entry.value,
                      aircraftFleet: provider.aircraftFleet,
                      onTap: () => _showFlightSheet(provider, entry.value),
                      onOpenAircraft:
                          () => _openAircraft(provider, entry.value),
                      onOpenContract: () => _handleOpenContract(entry.value),
                      onOpenPayment: () => _handleOpenPayment(entry.value),
                      onOpenConcierge: () => _openConcierge(entry.value),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_TripTab> get _availableTabs {
    return const [_TripTab.upcoming, _TripTab.history, _TripTab.cancelled];
  }

  String get _activeTabLabel => _tabLabel(_activeTab);
  List<Map<String, dynamic>> _filterRequests(
    List<Map<String, dynamic>> requests,
  ) {
    return _filterRequestsForTab(requests, _activeTab);
  }

  List<Map<String, dynamic>> _filterRequestsForTab(
    List<Map<String, dynamic>> requests,
    _TripTab tab,
  ) {
    final filtered =
        requests.where((request) {
          final status = _statusMeta(request);
          final departure = _departureDate(request);
          final isFuture =
              departure != null && departure.isAfter(DateTime.now());

          switch (tab) {
            case _TripTab.upcoming:
              return !status.isClosed || isFuture;

            case _TripTab.history:
              return status.isClosed && status.tone != _WorkflowTone.cancelled;

            case _TripTab.cancelled:
              return status.tone == _WorkflowTone.cancelled;
          }
        }).toList();

    filtered.sort((a, b) {
      final firstDate = _departureDate(a);
      final secondDate = _departureDate(b);

      if (firstDate == null && secondDate == null) return 0;
      if (firstDate == null) return 1;
      if (secondDate == null) return -1;

      if (tab == _TripTab.history || tab == _TripTab.cancelled) {
        return secondDate.compareTo(firstDate);
      }

      return firstDate.compareTo(secondDate);
    });

    return filtered;
  }

  DateTime? _departureDate(Map<String, dynamic> request) {
    final raw =
        request['departure_datetime']?.toString() ??
        request['start_datetime']?.toString() ??
        request['departure_at']?.toString() ??
        request['scheduled_at']?.toString() ??
        request['date']?.toString() ??
        request['created_at']?.toString();

    if (raw == null || raw.isEmpty) return null;

    return DateTime.tryParse(raw);
  }

  void _openConcierge([Map<String, dynamic>? request]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientConciergeScreen(request: request),
      ),
    );
  }

  void _openAircraft(
    ReservationProvider provider,
    Map<String, dynamic> request,
  ) {
    final aircraft = _resolveAircraft(provider, request);

    if (aircraft == null) {
      _showActionMessage(
        'Aeronave disponible cuando el proveedor la confirme.',
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ClientAircraftDetailScreen(
              aircraft: aircraft,
              request: request,
            ),
      ),
    );
  }

  Aircraft? _resolveAircraft(
    ReservationProvider provider,
    Map<String, dynamic> request,
  ) {
    final aircraftId =
        request['assigned_aircraft_id']?.toString() ??
        request['aircraft_id']?.toString() ??
        '';

    final aircraftName =
        request['aircraft']?.toString() ??
        request['aircraft_model']?.toString() ??
        request['assigned_aircraft_model']?.toString() ??
        '';

    for (final aircraft in provider.aircraftFleet) {
      if (aircraftId.isNotEmpty && aircraft.id == aircraftId) {
        return aircraft;
      }

      if (aircraftName.isNotEmpty &&
          (aircraft.name.toLowerCase() == aircraftName.toLowerCase() ||
              aircraft.aircraftType.toLowerCase() ==
                  aircraftName.toLowerCase())) {
        return aircraft;
      }
    }

    if (aircraftName.isEmpty) return null;

    return Aircraft.fromJson({
      'id': aircraftId.isEmpty ? 'request-aircraft' : aircraftId,
      'name': aircraftName,
      'model': aircraftName,
      'aircraft_type':
          request['aircraft_category']?.toString() ??
          request['cabin']?.toString() ??
          'Jet privado',
      'capacity':
          int.tryParse(request['aircraft_capacity']?.toString() ?? '') ??
          int.tryParse(request['capacity']?.toString() ?? '') ??
          0,
      'hourly_rate': 0,
      'speed_kmh': 650,
      'base_airport':
          request['source_origin']?.toString() ??
          request['origin']?.toString() ??
          '',
      'city':
          request['source_origin']?.toString() ??
          request['origin']?.toString() ??
          '',
      'minimum_hours': 1,
      'crew_overnight_usd': 0,
      'national_expenses_usd': 0,
      'international_expenses_usd': 0,
    });
  }

  void _showFlightSheet(
    ReservationProvider provider,
    Map<String, dynamic> request,
  ) {
    final meta = _statusMeta(request);
    final workflowId = _workflowStageId(_resolvedWorkflowStage(request));
    final contractEnabled = _contractActionEnabled(request, workflowId);
    final paymentEnabled = _paymentActionEnabled(request, workflowId);
    final conciergeEnabled = _conciergeActionEnabled(request, workflowId);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.clientPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder:
          (_) => SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      final palette = context.clientPalette;
                      return Text(
                        _routeLabel(request),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: palette.textPrimary,
                          height: 1,
                          letterSpacing: -0.8,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _MinimalStatusPill(meta: meta),
                  const SizedBox(height: 18),
                  _DetailRow(label: 'Fecha', value: _departureCopy(request)),
                  _DetailRow(label: 'Aeronave', value: _aircraftLabel(request)),
                  _DetailRow(
                    label: 'Pasajeros',
                    value: '${_passengerCount(request)} pasajeros',
                  ),
                  _DetailRow(label: 'Reserva', value: _requestCode(request)),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.clientPalette.surfaceSoft,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: context.clientPalette.border),
                    ),
                    child: Text(
                      meta.nextAction,
                      style: TextStyle(
                        color: context.clientPalette.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _SheetButton(
                          label: 'Concierge',
                          icon: Icons.support_agent_rounded,
                          onTap:
                              conciergeEnabled
                                  ? () => _openConcierge(request)
                                  : null,
                          visualState: _actionVisualState(
                            meta: meta,
                            stepIndex: 5,
                            enabled: conciergeEnabled,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SheetButton(
                          label: 'Aeronave',
                          icon: Icons.flight_rounded,
                          onTap: () => _openAircraft(provider, request),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _SheetButton(
                          label: 'Contrato',
                          icon: Icons.description_outlined,
                          onTap:
                              contractEnabled
                                  ? () => _handleOpenContract(request)
                                  : null,
                          visualState: _actionVisualState(
                            meta: meta,
                            stepIndex: 2,
                            enabled: contractEnabled,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SheetButton(
                          label: 'Pago',
                          icon: Icons.credit_card_rounded,
                          onTap:
                              paymentEnabled
                                  ? () => _handleOpenPayment(request)
                                  : null,
                          visualState: _actionVisualState(
                            meta: meta,
                            stepIndex: 3,
                            enabled: paymentEnabled,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showActionMessage(String message) {
    _showClientSnackBar(context, message);
  }

  void _handleOpenContract(Map<String, dynamic> request) {
    if (widget.onOpenContract != null) {
      widget.onOpenContract!(request);
      return;
    }

    _showActionMessage('Firma de contrato disponible pronto.');
  }

  void _handleOpenPayment(Map<String, dynamic> request) {
    final accessState = resolveCommercialAccessState(
      context.read<AuthProvider>().accessData,
    );
    if (!accessState.canReserve) {
      _showActionMessage(accessState.reservationBlockedMessage);
      widget.onCommercialAccessRequired?.call();
      return;
    }

    if (widget.onOpenPayment != null) {
      widget.onOpenPayment!(request);
      return;
    }

    _showActionMessage('Checkout seguro disponible pronto.');
  }
}

bool _shouldShowWorkspaceAlert(String? message) {
  if (message == null || message.trim().isEmpty) return false;
  final normalized = message.toLowerCase();
  return normalized.contains('no fue posible') ||
      normalized.contains('sin conexion') ||
      normalized.contains('inicia sesion') ||
      normalized.contains('sincronizada en');
}

bool _needsClientAttention(Map<String, dynamic> request) {
  final meta = _statusMeta(request);
  if (meta.isClosed) return false;
  final workflowId = _workflowStageId(_resolvedWorkflowStage(request));
  return _contractActionEnabled(request, workflowId) ||
      _paymentActionEnabled(request, workflowId) ||
      meta.tone == _WorkflowTone.pending;
}

void _showClientSnackBar(BuildContext context, String message) {
  final palette = context.clientPalette;
  final isError =
      message.toLowerCase().contains('no fue posible') ||
      message.toLowerCase().contains('error');
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              color:
                  isError
                      ? Theme.of(context).colorScheme.onError
                      : palette.accent,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color:
                      isError
                          ? Theme.of(context).colorScheme.onError
                          : palette.textPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

class _WorkspaceAlert extends StatelessWidget {
  const _WorkspaceAlert({
    required this.message,
    required this.loading,
    required this.onRefresh,
  });

  final String? message;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final text = loading ? 'Actualizando reservas...' : message?.trim() ?? '';
    final isError =
        text.toLowerCase().contains('no fue posible') ||
        text.toLowerCase().contains('sin conexion');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color:
            isError
                ? Theme.of(context).colorScheme.errorContainer
                : palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isError
                  ? Theme.of(context).colorScheme.error.withValues(alpha: 0.35)
                  : palette.border,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child:
                loading
                    ? CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.accent,
                    )
                    : Icon(
                      isError
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_rounded,
                      color:
                          isError
                              ? Theme.of(context).colorScheme.error
                              : palette.accent,
                      size: 22,
                    ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    isError
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : palette.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Actualizar',
            onPressed: loading ? null : onRefresh,
            icon: Icon(Icons.refresh_rounded, color: palette.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _FlightsOverviewPanel extends StatelessWidget {
  const _FlightsOverviewPanel({
    required this.totalFlights,
    required this.visibleFlights,
    required this.attentionCount,
    required this.nextFlight,
    required this.loading,
    required this.lastSyncAt,
    required this.onRefresh,
    required this.onOpenSearch,
  });

  final int totalFlights;
  final int visibleFlights;
  final int attentionCount;
  final Map<String, dynamic>? nextFlight;
  final bool loading;
  final DateTime? lastSyncAt;
  final VoidCallback onRefresh;
  final VoidCallback? onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final isDark = context.isDarkMode;
    final hasNextFlight = nextFlight != null;
    final nextRoute =
        hasNextFlight ? _routeLabel(nextFlight!) : 'Sin vuelo activo';
    final nextDate =
        hasNextFlight ? _departureCopy(nextFlight!) : 'Cotiza una nueva ruta';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.accentBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.surfaceStrong,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.accentBorder),
                ),
                child: Icon(
                  loading ? Icons.sync_rounded : Icons.flight_takeoff_rounded,
                  color: palette.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasNextFlight
                          ? 'Proximo vuelo'
                          : 'Planea tu siguiente vuelo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.heroTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      nextRoute,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.heroTextPrimary,
                        fontSize: 20,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar vuelos',
                onPressed: loading ? null : onRefresh,
                icon: Icon(Icons.refresh_rounded, color: palette.accent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OverviewChip(
                icon: Icons.calendar_month_rounded,
                label: nextDate,
              ),
              _OverviewChip(
                icon: Icons.notifications_active_outlined,
                label:
                    attentionCount == 1
                        ? '1 accion pendiente'
                        : '$attentionCount acciones pendientes',
                highlighted: attentionCount > 0,
              ),
              _OverviewChip(
                icon: Icons.view_list_rounded,
                label: '$visibleFlights visibles de $totalFlights',
              ),
              _OverviewChip(
                icon: Icons.schedule_rounded,
                label: _syncCopy(lastSyncAt),
              ),
            ],
          ),
          if (!hasNextFlight && onOpenSearch != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onOpenSearch,
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: ClientThemeColors.textOnAccent,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.search_rounded),
              label: const Text(
                'Buscar vuelo',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _syncCopy(DateTime? date) {
    if (date == null) return 'Sin sincronizar';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return 'Actualizado $day/$month $hour:$minute';
  }
}

class _OverviewChip extends StatelessWidget {
  const _OverviewChip({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? palette.accentSoft : palette.surfaceStrong,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.accentBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color:
                highlighted ? ClientThemeColors.textOnAccent : palette.accent,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    highlighted
                        ? ClientThemeColors.textOnAccent
                        : palette.heroTextPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionFilterBar extends StatelessWidget {
  const _AttentionFilterBar({
    required this.active,
    required this.count,
    required this.onChanged,
  });

  final bool active;
  final int count;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 10, 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(
            count > 0
                ? Icons.notification_important_outlined
                : Icons.check_circle_outline_rounded,
            color: count > 0 ? palette.accent : const Color(0xFF1B8F4D),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              count > 0
                  ? 'Mostrar solo vuelos que necesitan accion'
                  : 'Sin acciones pendientes por ahora',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Switch.adaptive(
            value: active,
            onChanged: count == 0 ? null : onChanged,
            activeColor: palette.accent,
          ),
        ],
      ),
    );
  }
}

class _FlightExperienceStrip extends StatelessWidget {
  const _FlightExperienceStrip({
    required this.attentionCount,
    required this.upcomingCount,
    required this.onOpenSearch,
  });

  final int attentionCount;
  final int upcomingCount;
  final VoidCallback? onOpenSearch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final tiles = [
          _ExperienceTileData(
            icon: Icons.touch_app_rounded,
            title: 'Acciones guiadas',
            subtitle:
                attentionCount > 0
                    ? '$attentionCount pendientes'
                    : 'Todo al dia',
          ),
          _ExperienceTileData(
            icon: Icons.timeline_rounded,
            title: 'Seguimiento claro',
            subtitle:
                upcomingCount == 1
                    ? '1 vuelo activo'
                    : '$upcomingCount vuelos activos',
          ),
          _ExperienceTileData(
            icon: Icons.add_circle_outline_rounded,
            title: 'Nueva ruta',
            subtitle: 'Cotizar vuelo',
            onTap: onOpenSearch,
          ),
        ];

        if (compact) {
          return SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tiles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder:
                  (context, index) => SizedBox(
                    width: 190,
                    child: _ExperienceTile(data: tiles[index]),
                  ),
            ),
          );
        }

        return Row(
          children:
              tiles
                  .map(
                    (tile) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _ExperienceTile(data: tile),
                      ),
                    ),
                  )
                  .toList(),
        );
      },
    );
  }
}

class _ExperienceTileData {
  const _ExperienceTileData({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
}

class _ExperienceTile extends StatelessWidget {
  const _ExperienceTile({required this.data});

  final _ExperienceTileData data;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(data.icon, color: palette.accent, size: 22),
            const SizedBox(height: 10),
            Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              data.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TripTab { upcoming, history, cancelled }

String _tabLabel(_TripTab tab) {
  switch (tab) {
    case _TripTab.upcoming:
      return 'Proximos';
    case _TripTab.history:
      return 'Historial';
    case _TripTab.cancelled:
      return 'Cancelados';
  }
}

enum _WorkflowTone { searching, info, pending, confirmed, completed, cancelled }

class _WorkflowMeta {
  const _WorkflowMeta({
    required this.label,
    required this.tone,
    required this.progress,
    required this.activeStep,
    required this.nextAction,
    required this.isClosed,
    required this.providerConfirmed,
    required this.contractReady,
    required this.paymentReady,
    required this.flightReady,
    required this.trackingReady,
  });

  final String label;
  final _WorkflowTone tone;
  final int progress;
  final int activeStep;
  final String nextAction;
  final bool isClosed;
  final bool providerConfirmed;
  final bool contractReady;
  final bool paymentReady;
  final bool flightReady;
  final bool trackingReady;
}

enum _StepState { done, active, todo }

enum _ActionVisualState { inactive, available, active }

class _ItinerarySegment {
  const _ItinerarySegment({
    required this.order,
    required this.origin,
    required this.destination,
    this.departure = '',
  });

  final int order;
  final String origin;
  final String destination;
  final String departure;
}

class _TripTabButton extends StatelessWidget {
  const _TripTabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final isDark = context.isDarkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: active && isDark ? palette.surfaceStrong : palette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isDark ? palette.accentBorder : palette.border,
          ),
          boxShadow:
              active
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                active
                    ? (isDark ? palette.accent : palette.primary)
                    : palette.textSecondary,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

class _MinimalFlightCard extends StatelessWidget {
  const _MinimalFlightCard({
    required this.request,
    required this.aircraftFleet,
    required this.onTap,
    required this.onOpenAircraft,
    required this.onOpenContract,
    required this.onOpenPayment,
    required this.onOpenConcierge,
  });

  final Map<String, dynamic> request;
  final List<Aircraft> aircraftFleet;
  final VoidCallback onTap;
  final VoidCallback onOpenAircraft;
  final VoidCallback onOpenContract;
  final VoidCallback onOpenPayment;
  final VoidCallback onOpenConcierge;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final isDark = context.isDarkMode;
    final meta = _statusMeta(request);
    final workflowId = _workflowStageId(_resolvedWorkflowStage(request));
    final contractEnabled = _contractActionEnabled(request, workflowId);
    final paymentEnabled = _paymentActionEnabled(request, workflowId);
    final flightEnabled = _flightActionEnabled(request, workflowId);
    final conciergeEnabled = _conciergeActionEnabled(request, workflowId);
    final imageUrl = _aircraftImageUrl(request, aircraftFleet);
    final aircraftName = _aircraftLabel(request);
    final capacity = _aircraftCapacityLabel(request, aircraftFleet);
    final category = _aircraftCategoryLabel(request);
    final supportLines = _workflowSupportLines(request, meta);
    final contractVisualState = _actionVisualState(
      meta: meta,
      stepIndex: 2,
      enabled: contractEnabled,
    );
    final paymentVisualState = _actionVisualState(
      meta: meta,
      stepIndex: 3,
      enabled: paymentEnabled,
    );
    final flightVisualState = _actionVisualState(
      meta: meta,
      stepIndex: 4,
      enabled: flightEnabled,
    );
    final conciergeVisualState = _actionVisualState(
      meta: meta,
      stepIndex: 5,
      enabled: conciergeEnabled,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? palette.accentBorder : palette.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.08),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    _requestCode(request).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? palette.accent : palette.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(meta: meta),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _routeLabel(request),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.02,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MetaChip(
                  icon: Icons.calendar_month_rounded,
                  label: _departureCopy(request),
                ),
                _MetaChip(
                  icon: Icons.groups_rounded,
                  label:
                      '${_passengerCount(request)} ${_passengerCount(request) == 1 ? 'pasajero' : 'pasajeros'}',
                ),
                _MetaChip(icon: Icons.flight_rounded, label: aircraftName),
              ],
            ),
            const SizedBox(height: 8),
            _ProgressSummary(meta: meta),
            const SizedBox(height: 6),
            _ProgressSteps(meta: meta),
            const SizedBox(height: 8),
            _ExecutiveAircraftPanel(
              imageUrl: imageUrl,
              aircraftName: aircraftName,
              capacity: capacity,
              category: category,
              onOpenAircraft: onOpenAircraft,
            ),
            const SizedBox(height: 6),
            _NextStepPanel(lines: supportLines),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _CardActionButton(
                    label: 'Contrato',
                    icon: Icons.description_outlined,
                    enabled: contractEnabled,
                    visualState: contractVisualState,
                    onTap: onOpenContract,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _CardActionButton(
                    label: 'Pago',
                    icon: Icons.credit_card_rounded,
                    enabled: paymentEnabled,
                    visualState: paymentVisualState,
                    onTap: onOpenPayment,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _CardActionButton(
                    label: _flightActionLabel(meta),
                    icon: Icons.flight_takeoff_rounded,
                    enabled: flightEnabled,
                    visualState: flightVisualState,
                    onTap: onTap,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _CardActionButton(
                    label: 'Concierge',
                    icon: Icons.support_agent_rounded,
                    enabled: conciergeEnabled,
                    visualState: conciergeVisualState,
                    onTap: onOpenConcierge,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.meta});

  final _WorkflowMeta meta;

  @override
  Widget build(BuildContext context) {
    final colors = _toneColors(meta.tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_toneIcon(meta.tone), size: 14, color: colors.$2),
          const SizedBox(width: 6),
          Text(
            meta.label,
            style: TextStyle(
              color: colors.$2,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.textSecondary),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({required this.meta});

  final _WorkflowMeta meta;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (meta.progress.clamp(0, 100)) / 100,
              minHeight: 7,
              backgroundColor: palette.accentSoft,
              valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${meta.progress}%',
          style: TextStyle(
            color: palette.heroTextPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ProgressSteps extends StatelessWidget {
  const _ProgressSteps({required this.meta});

  final _WorkflowMeta meta;

  @override
  Widget build(BuildContext context) {
    final allSteps = const [
      (label: 'Reserva', icon: Icons.event_available_rounded),
      (label: 'Proveedor', icon: Icons.verified_user_rounded),
      (label: 'Contrato', icon: Icons.description_rounded),
      (label: 'Pago', icon: Icons.payments_rounded),
      (label: 'Vuelo', icon: Icons.flight_takeoff_rounded),
      (label: 'Tracking', icon: Icons.radar_rounded),
    ];
    final visibleCount = (meta.activeStep + 2).clamp(3, allSteps.length);
    final steps = allSteps.take(visibleCount).toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var index = 0; index < steps.length; index++)
          _StepPill(
            label: steps[index].label,
            icon: steps[index].icon,
            state: _stepState(meta, index),
          ),
      ],
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.label,
    required this.icon,
    required this.state,
  });

  final String label;
  final IconData icon;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final colors = switch (state) {
      _StepState.done => (
        const Color(0xFFE8FAEE),
        const Color(0xFF14673A),
        const Color(0xFFA8D7B8),
      ),
      _StepState.active => (
        const Color(0xFFFFF0CC),
        const Color(0xFF8A5A00),
        const Color(0xFFE4C172),
      ),
      _StepState.todo => (
        context.isDarkMode ? palette.surfaceStrong : palette.surfaceSoft,
        context.isDarkMode ? const Color(0xFFE3EDF5) : palette.textSecondary,
        context.isDarkMode ? const Color(0xFF31536D) : palette.border,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.$3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            state == _StepState.done ? Icons.check_rounded : icon,
            size: 13,
            color: colors.$2,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: colors.$2,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutiveAircraftPanel extends StatelessWidget {
  const _ExecutiveAircraftPanel({
    required this.imageUrl,
    required this.aircraftName,
    required this.capacity,
    required this.category,
    required this.onOpenAircraft,
  });

  final String imageUrl;
  final String aircraftName;
  final String capacity;
  final String category;
  final VoidCallback onOpenAircraft;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.isDarkMode ? palette.surfaceStrong : palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.isDarkMode ? palette.accentBorder : palette.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _AircraftHeroMedia(imageUrl: imageUrl),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  aircraftName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                if (capacity.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    capacity,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (category.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    category,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onOpenAircraft,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            color: palette.textPrimary,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Ver aeronave',
          ),
        ],
      ),
    );
  }
}

class _AircraftHeroMedia extends StatelessWidget {
  const _AircraftHeroMedia({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final hasImage = imageUrl.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 72,
        height: 54,
        color: palette.primary,
        child:
            hasImage
                ? Image.network(
                  imageUrl,
                  width: 72,
                  height: 54,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _AircraftHeroFallback(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const _AircraftHeroFallback();
                  },
                )
                : const _AircraftHeroFallback(),
      ),
    );
  }
}

class _AircraftHeroFallback extends StatelessWidget {
  const _AircraftHeroFallback();

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Center(
      child: Text(
        'Jet privado',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: palette.heroTextPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _NextStepPanel extends StatelessWidget {
  const _NextStepPanel({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.isDarkMode ? palette.surfaceStrong : palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDarkMode ? palette.accentBorder : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Siguiente paso',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          for (final line in lines.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.visualState = _ActionVisualState.inactive,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final _ActionVisualState visualState;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final isActive = visualState == _ActionVisualState.active;
    final isAvailable = visualState == _ActionVisualState.available;
    final background =
        isActive
            ? (context.isDarkMode ? const Color(0xFF1A3D58) : palette.primary)
            : isAvailable
            ? palette.accentSoft
            : (enabled
                ? (context.isDarkMode
                    ? const Color(0xFF173246)
                    : palette.surface)
                : (context.isDarkMode ? palette.surfaceSoft : palette.surface));
    final foreground =
        isActive
            ? palette.heroTextPrimary
            : isAvailable
            ? palette.textOnAccent
            : (enabled
                ? (context.isDarkMode
                    ? const Color(0xFFF0F6FB)
                    : palette.textPrimary)
                : palette.textSecondary);

    return SizedBox(
      height: 34,
      child: FilledButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 14),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor:
              context.isDarkMode ? palette.surfaceSoft : palette.surface,
          disabledForegroundColor: palette.textSecondary,
          side: BorderSide(
            color:
                isActive
                    ? (context.isDarkMode
                        ? const Color(0xFF4D7796)
                        : palette.primary)
                    : isAvailable
                    ? palette.accentBorder
                    : (context.isDarkMode
                        ? const Color(0xFF2C4A60)
                        : palette.border),
          ),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MinimalStatusPill extends StatelessWidget {
  const _MinimalStatusPill({required this.meta});

  final _WorkflowMeta meta;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final isConfirmed =
        meta.tone == _WorkflowTone.confirmed ||
        meta.tone == _WorkflowTone.completed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            isConfirmed
                ? palette.primary
                : (context.isDarkMode ? palette.surfaceSoft : palette.surface),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isConfirmed ? palette.primary : palette.border,
        ),
      ),
      child: Text(
        meta.label,
        style: TextStyle(
          color: isConfirmed ? palette.heroTextPrimary : palette.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.visualState = _ActionVisualState.inactive,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final _ActionVisualState visualState;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final isActive = visualState == _ActionVisualState.active;
    final isAvailable = visualState == _ActionVisualState.available;
    final background =
        isActive
            ? palette.primary
            : isAvailable
            ? palette.accentSoft
            : (context.isDarkMode ? palette.surfaceSoft : palette.surface);
    final foreground =
        isActive
            ? palette.heroTextPrimary
            : isAvailable
            ? palette.textOnAccent
            : (onTap != null ? palette.textPrimary : palette.textSecondary);

    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledForegroundColor: palette.textSecondary,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(
          color:
              isActive
                  ? palette.primary
                  : isAvailable
                  ? palette.accentBorder
                  : palette.border,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _MinimalLoadingCard extends StatelessWidget {
  const _MinimalLoadingCard();

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.accentBorder),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: palette.accent,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Cargando vuelos...',
            style: TextStyle(
              color: palette.heroTextPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFlightsPanel extends StatelessWidget {
  const _EmptyFlightsPanel({required this.label, this.onOpenSearch});

  final String label;
  final VoidCallback? onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final isUpcoming = label == 'Proximos';
    final isDark = context.isDarkMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? palette.accentBorder : palette.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: palette.surfaceStrong,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.accentBorder),
            ),
            child: Icon(
              isUpcoming
                  ? Icons.flight_takeoff_rounded
                  : Icons.inventory_2_outlined,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isUpcoming
                ? 'Aun no tienes reservas activas'
                : 'Sin vuelos en $label',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isUpcoming
                ? 'Cuando cotices un vuelo aparecera aqui con contrato, pago y seguimiento.'
                : 'Cuando tengas movimientos en esta seccion apareceran aqui.',
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          if (isUpcoming) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onOpenSearch,
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.search_rounded),
              label: const Text(
                'Buscar vuelo',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyFlightsCardLegacy extends StatelessWidget {
  const EmptyFlightsCardLegacy({
    super.key,
    required this.label,
    this.onOpenSearch,
  });

  final String label;
  final VoidCallback? onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final isUpcoming = label == 'Próximos';
    final isDark = context.isDarkMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? palette.accentBorder : palette.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.10),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: palette.surfaceStrong,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.accentBorder),
            ),
            child: Icon(Icons.flight_takeoff_rounded, color: palette.accent),
          ),
          const SizedBox(height: 18),
          Text(
            isUpcoming
                ? 'Aún no tienes reservas activas'
                : 'Sin vuelos en $label',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isUpcoming
                ? 'Cuando cotices un vuelo aparecerá aquí.'
                : 'Cuando tengas movimientos en esta sección aparecerán aquí.',
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          if (isUpcoming) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onOpenSearch,
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.search_rounded),
              label: const Text(
                'Buscar vuelo',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

_WorkflowMeta _statusMeta(Map<String, dynamic> request) {
  final workflowId = _resolvedWorkflowStage(request);
  return _metaFromBackendStage(
    workflowId,
    label: _backendWorkflowLabel(request, workflowId),
    nextAction: _backendNextStep(request, workflowId),
    progress: _backendProgress(request, workflowId),
  );
}

String _resolvedWorkflowStage(Map<String, dynamic> request) {
  return resolveClientWorkflowStage(request);
}

String _workflowStageId(String workflow) {
  final stageId = resolveClientWorkflowStageIdFromValue(workflow);
  return stageId.isEmpty ? workflow : stageId;
}

_WorkflowMeta _metaFromBackendStage(
  String workflowId, {
  required String label,
  required String nextAction,
  required int progress,
}) {
  final tone = _toneForStage(workflowId);
  final activeStep = _activeStepForStage(workflowId);
  final isClosed = const [
    'completed',
    'cancelled',
    'rejected',
  ].contains(workflowId);
  final providerConfirmed =
      activeStep >= 1 &&
      !const [
        'provider_pending',
        'reserved',
        'draft',
        'quoted',
        'package_selected',
      ].contains(workflowId);
  final contractReady = const [
    'contract_signed',
    'payment_pending',
    'payment_confirmed',
    'flight_confirmed',
    'tracking_live',
    'completed',
  ].contains(workflowId);
  final paymentReady = const [
    'payment_confirmed',
    'flight_confirmed',
    'tracking_live',
    'completed',
  ].contains(workflowId);
  final flightReady = const [
    'flight_confirmed',
    'tracking_live',
    'completed',
  ].contains(workflowId);
  final trackingReady = const [
    'tracking_live',
    'completed',
  ].contains(workflowId);

  return _WorkflowMeta(
    label: label,
    tone: tone,
    progress: progress.clamp(0, 100),
    activeStep: activeStep,
    nextAction: nextAction,
    isClosed: isClosed,
    providerConfirmed: providerConfirmed,
    contractReady: contractReady,
    paymentReady: paymentReady,
    flightReady: flightReady,
    trackingReady: trackingReady,
  );
}

String _backendWorkflowLabel(Map<String, dynamic> request, String workflowId) {
  final explicitLabel = _firstText([
    request['workflow_label'],
    request['workflow_status_label'],
    request['status_label'],
  ]);
  if (explicitLabel.isNotEmpty) return explicitLabel;

  final rawWorkflow = _firstText([
    request['workflow_status'],
    request['workflow'],
    request['status'],
  ]);
  final rawStageId = resolveClientWorkflowStageIdFromValue(rawWorkflow);
  if (rawWorkflow.isNotEmpty && rawStageId.isEmpty) {
    return _sentenceCase(rawWorkflow);
  }

  return clientWorkflowLabelForStage(workflowId, fallback: 'Reserva');
}

String _backendNextStep(Map<String, dynamic> request, String workflowId) {
  final direct = _firstText([
    request['next_step'],
    request['next_action'],
    request['nextStep'],
    request['action_required'],
  ]);
  if (direct.isNotEmpty) return direct;
  return _workflowActionCopy(workflowId).detail;
}

int _backendProgress(Map<String, dynamic> request, String workflowId) {
  final raw =
      request['progress'] ??
      request['workflow_progress'] ??
      request['progress_percent'];
  final parsed = _asProgressInt(raw);
  if (parsed != null) {
    return parsed.clamp(0, 100);
  }
  return _defaultProgressForStage(workflowId);
}

_WorkflowTone _toneForStage(String workflowId) {
  switch (workflowId) {
    case 'provider_pending':
      return _WorkflowTone.searching;
    case 'draft':
    case 'quoted':
    case 'package_selected':
    case 'reserved':
      return _WorkflowTone.info;
    case 'contract_pending':
    case 'payment_pending':
      return _WorkflowTone.pending;
    case 'completed':
      return _WorkflowTone.completed;
    case 'cancelled':
    case 'rejected':
      return _WorkflowTone.cancelled;
    default:
      return _WorkflowTone.confirmed;
  }
}

int _defaultProgressForStage(String workflowId) {
  switch (workflowId) {
    case 'draft':
      return 8;
    case 'quoted':
      return 14;
    case 'package_selected':
      return 22;
    case 'reserved':
      return 28;
    case 'provider_pending':
      return 36;
    case 'provider_accepted':
      return 44;
    case 'contract_pending':
      return 58;
    case 'contract_signed':
      return 66;
    case 'payment_pending':
      return 78;
    case 'payment_confirmed':
      return 86;
    case 'flight_confirmed':
      return 93;
    case 'tracking_live':
      return 97;
    case 'completed':
    case 'cancelled':
    case 'rejected':
      return 100;
    default:
      return 8;
  }
}

int _activeStepForStage(String workflowId) {
  switch (workflowId) {
    case 'provider_pending':
    case 'provider_accepted':
      return 1;
    case 'contract_pending':
    case 'contract_signed':
      return 2;
    case 'payment_pending':
    case 'payment_confirmed':
      return 3;
    case 'flight_confirmed':
      return 4;
    case 'tracking_live':
    case 'completed':
    case 'cancelled':
    case 'rejected':
      return 5;
    default:
      return 0;
  }
}

bool _matchesAny(String value, List<String> patterns) {
  for (final pattern in patterns) {
    if (value.contains(pattern)) return true;
  }
  return false;
}

String _sentenceCase(String value) {
  final normalized = value.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return normalized;
  final lower = normalized.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

(Color, Color) _toneColors(_WorkflowTone tone) {
  return switch (tone) {
    _WorkflowTone.searching => (
      const Color(0xFFE8F1FF),
      const Color(0xFF2351A8),
    ),
    _WorkflowTone.info => (const Color(0xFFEEF4FF), const Color(0xFF355DA8)),
    _WorkflowTone.pending => (const Color(0xFFFFF2D8), const Color(0xFF9A6500)),
    _WorkflowTone.confirmed => (
      const Color(0xFFE5F7EA),
      const Color(0xFF14673A),
    ),
    _WorkflowTone.completed => (
      const Color(0xFFDDF7E6),
      const Color(0xFF0D6A34),
    ),
    _WorkflowTone.cancelled => (
      const Color(0xFFFFE6E2),
      const Color(0xFFA13622),
    ),
  };
}

IconData _toneIcon(_WorkflowTone tone) {
  return switch (tone) {
    _WorkflowTone.searching => Icons.search_rounded,
    _WorkflowTone.info => Icons.info_outline_rounded,
    _WorkflowTone.pending => Icons.schedule_rounded,
    _WorkflowTone.confirmed => Icons.verified_rounded,
    _WorkflowTone.completed => Icons.task_alt_rounded,
    _WorkflowTone.cancelled => Icons.block_rounded,
  };
}

_StepState _stepState(_WorkflowMeta meta, int index) {
  if (meta.isClosed && meta.tone == _WorkflowTone.completed) {
    return _StepState.done;
  }
  if (meta.isClosed && meta.tone == _WorkflowTone.cancelled) {
    return index == meta.activeStep ? _StepState.active : _StepState.todo;
  }
  if (index < meta.activeStep) return _StepState.done;
  if (index == meta.activeStep) return _StepState.active;
  return _StepState.todo;
}

_ActionVisualState _actionVisualState({
  required _WorkflowMeta meta,
  required int stepIndex,
  required bool enabled,
}) {
  if (!enabled) return _ActionVisualState.inactive;
  if (meta.activeStep == stepIndex) return _ActionVisualState.active;
  if (stepIndex == 5 && meta.trackingReady) return _ActionVisualState.active;
  if (meta.activeStep > stepIndex) return _ActionVisualState.available;
  return _ActionVisualState.available;
}

String _flightActionLabel(_WorkflowMeta meta) {
  if (meta.tone == _WorkflowTone.completed) return 'Buen viaje';
  if (meta.trackingReady) return 'Tracking';
  if (meta.flightReady) return 'Vuelo listo';
  if (meta.paymentReady) return 'Liberacion';
  return 'Vuelo';
}

bool _contractActionEnabled(Map<String, dynamic> request, String workflowId) {
  return const ['provider_accepted', 'contract_pending'].contains(workflowId);
}

bool _paymentActionEnabled(Map<String, dynamic> request, String workflowId) {
  if (!_isReservationRecord(request)) return false;
  return const ['contract_signed', 'payment_pending'].contains(workflowId);
}

bool _hasPaymentValidationSignals(Map<String, dynamic> request) {
  final paymentOrder = request['payment_order'];
  final reservation = request['reservation'];
  final data = request['data'];

  if (_hasValue(request['checkout_session_id']) ||
      _hasValue(request['stripe_checkout_session_id']) ||
      _hasValue(request['stripe_payment_intent_id']) ||
      _hasValue(request['payment_intent_id'])) {
    return true;
  }

  if (paymentOrder is Map &&
      (_hasValue(paymentOrder['checkout_session_id']) ||
          _hasValue(paymentOrder['stripe_session_id']) ||
          _hasValue(paymentOrder['status']))) {
    return true;
  }

  if (reservation is Map &&
      (_hasValue(reservation['checkout_session_id']) ||
          _hasValue(reservation['payment_intent_id']))) {
    return true;
  }

  if (data is Map &&
      (_hasValue(data['checkout_session_id']) ||
          _hasValue(data['payment_intent_id']))) {
    return true;
  }

  final payments = request['payments'];
  if (payments is List) {
    return payments.any((payment) {
      if (payment is! Map) return false;
      final status = payment['status']?.toString().trim().toLowerCase() ?? '';
      return status == 'pending' ||
          status == 'processing' ||
          _hasValue(payment['checkout_session_id']) ||
          _hasValue(payment['payment_intent_id']);
    });
  }

  return false;
}

bool _flightActionEnabled(Map<String, dynamic> request, String workflowId) {
  return const [
    'payment_confirmed',
    'flight_confirmed',
    'tracking_live',
    'completed',
  ].contains(workflowId);
}

bool _conciergeActionEnabled(Map<String, dynamic> request, String workflowId) {
  return const [
    'reserved',
    'provider_pending',
    'provider_accepted',
    'contract_pending',
    'contract_signed',
    'payment_pending',
    'payment_confirmed',
    'flight_confirmed',
    'tracking_live',
    'completed',
  ].contains(workflowId);
}

bool _isReservationRecord(Map<String, dynamic> request) {
  final explicit = request['is_reservation'];
  if (explicit is bool) return explicit;
  if (_asBool(explicit)) return true;

  return _hasValue(request['reservation_id']) ||
      _hasValue(request['booking_id']) ||
      _hasValue(request['operation_id']) ||
      _hasValue(request['contract_id']) ||
      _hasValue(request['contract_status']) ||
      _hasValue(request['payment_status']);
}

List<String> _workflowSupportLines(
  Map<String, dynamic> request,
  _WorkflowMeta meta,
) {
  final stage = _workflowStageId(_resolvedWorkflowStage(request));
  final title = _workflowActionCopy(stage).title;
  return [
    title,
    meta.nextAction,
  ].where((line) => line.trim().isNotEmpty).toList();
}

String _requestCode(Map<String, dynamic> request) {
  final explicitCode = _firstText([
    request['folio'],
    request['booking_code'],
    request['reservation_code'],
    request['code'],
  ]);
  if (explicitCode.isNotEmpty) {
    final normalized = explicitCode.trim().toUpperCase();
    return normalized.startsWith('RESERVA ')
        ? normalized
        : 'RESERVA $normalized';
  }

  final rawId = _firstText([
    request['reservation_id'],
    request['booking_id'],
    request['id'],
  ]);
  final normalizedRawId = rawId.trim();
  final numericId = int.tryParse(normalizedRawId);
  final suffix =
      numericId != null
          ? numericId.toString().padLeft(4, '0')
          : (normalizedRawId.isNotEmpty ? normalizedRawId : '0000');
  return 'RESERVA SKY-$suffix';
}

class _WorkflowActionCopy {
  const _WorkflowActionCopy({required this.title, required this.detail});

  final String title;
  final String detail;
}

_WorkflowActionCopy _workflowActionCopy(String stageId) {
  switch (stageId) {
    case 'draft':
      return const _WorkflowActionCopy(
        title: 'Información pendiente',
        detail:
            'Se requiere información complementaria para continuar con la gestión de su operación.',
      );

    case 'quoted':
      return const _WorkflowActionCopy(
        title: 'Propuesta disponible',
        detail:
            'Su propuesta está lista. Seleccione la opción que mejor se adapte a sus requerimientos para continuar.',
      );

    case 'package_selected':
      return const _WorkflowActionCopy(
        title: 'Confirmación de operación',
        detail:
            'La propuesta seleccionada ha sido registrada y está lista para su confirmación.',
      );

    case 'reserved':
      return const _WorkflowActionCopy(
        title: 'Validación operativa',
        detail:
            'La operación ha sido enviada para revisión y validación operativa.',
      );

    case 'provider_pending':
      return const _WorkflowActionCopy(
        title: 'Revisión operativa',
        detail:
            'Nos encontramos verificando disponibilidad, aeronave, tripulación y condiciones de operación.',
      );

    case 'provider_accepted':
      return const _WorkflowActionCopy(
        title: 'Documentación contractual',
        detail:
            'La operación ha sido aprobada y avanza a la etapa de formalización contractual.',
      );

    case 'contract_pending':
      return const _WorkflowActionCopy(
        title: 'Firma de documentación',
        detail:
            'La documentación contractual se encuentra en proceso de revisión y firma.',
      );

    case 'contract_signed':
      return const _WorkflowActionCopy(
        title: 'Validación financiera',
        detail:
            'La documentación ha sido completada. Procedemos con la validación financiera de la operación.',
      );

    case 'payment_pending':
      return const _WorkflowActionCopy(
        title: 'Confirmación de pago',
        detail:
            'El pago se encuentra en proceso de validación para continuar con la liberación operativa.',
      );

    case 'payment_confirmed':
      return const _WorkflowActionCopy(
        title: 'Coordinación de vuelo',
        detail:
            'Pago confirmado. Nuestro equipo coordina todos los aspectos operativos y logísticos de su vuelo.',
      );

    case 'flight_confirmed':
      return const _WorkflowActionCopy(
        title: 'Operación confirmada',
        detail:
            'La aeronave, tripulación y programación han sido confirmadas exitosamente.',
      );

    case 'tracking_live':
      return const _WorkflowActionCopy(
        title: 'Operación en curso',
        detail:
            'Su vuelo se encuentra en ejecución y bajo supervisión continua de nuestro equipo.',
      );

    case 'completed':
      return const _WorkflowActionCopy(
        title: 'Operación finalizada',
        detail:
            'La operación ha concluido satisfactoriamente. Agradecemos su confianza en nuestros servicios.',
      );

    case 'cancelled':
      return const _WorkflowActionCopy(
        title: 'Operación cancelada',
        detail:
            'La operación fue cancelada. Nuestro equipo permanece disponible para asistirle con una nueva solicitud.',
      );

    case 'rejected':
      return const _WorkflowActionCopy(
        title: 'Alternativa en gestión',
        detail:
            'La opción seleccionada no pudo ser confirmada. Estamos evaluando alternativas equivalentes.',
      );

    default:
      return const _WorkflowActionCopy(
        title: 'Operación registrada',
        detail:
            'Su solicitud ha sido registrada y se encuentra avanzando dentro del proceso operativo.',
      );
  }
}

bool _hasValue(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isNotEmpty && text.toLowerCase() != 'null';
}

bool _asBool(dynamic value) {
  if (value is bool) return value;

  final text = value?.toString().trim().toLowerCase() ?? '';

  return text == 'true' || text == '1' || text == 'yes' || text == 'si';
}

String? _nestedText(dynamic value, String key) {
  if (value is Map && value[key] != null) {
    final text = value[key].toString().trim();

    if (text.isNotEmpty) return text;
  }

  return null;
}

String _routeLabel(Map<String, dynamic> request) {
  final segments = _itinerarySegments(request);
  if (segments.isNotEmpty) {
    final points = <String>[];
    for (final segment in segments) {
      if (points.isEmpty) {
        points.add(segment.origin);
      } else if (points.last != segment.origin) {
        points.add(segment.origin);
      }
      if (segment.destination.isNotEmpty &&
          points.last != segment.destination) {
        points.add(segment.destination);
      }
    }
    if (points.isNotEmpty) {
      return points.join(' → ');
    }
  }

  final origin = request['origin']?.toString() ?? '';
  final destination = request['destination']?.toString() ?? '';

  if (origin.isNotEmpty || destination.isNotEmpty) {
    return '$origin → $destination';
  }

  return 'Ruta por confirmar';
}

String _departureCopy(Map<String, dynamic> request) {
  final raw =
      request['departure_datetime']?.toString() ??
      request['start_datetime']?.toString() ??
      request['departure_at']?.toString() ??
      request['scheduled_at']?.toString() ??
      request['date']?.toString() ??
      '';

  if (raw.isEmpty) return 'Fecha por confirmar';

  final parsed = DateTime.tryParse(raw);

  if (parsed == null) return raw;

  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  final month = months[parsed.month - 1];

  final hour =
      parsed.hour == 0
          ? 12
          : (parsed.hour > 12 ? parsed.hour - 12 : parsed.hour);

  final suffix = parsed.hour >= 12 ? 'p.m.' : 'a.m.';
  final minute = parsed.minute.toString().padLeft(2, '0');

  return '${parsed.day}-$month, $hour:$minute $suffix';
}

int _passengerCount(Map<String, dynamic> request) {
  return int.tryParse(
        request['passengers']?.toString() ??
            request['passenger_count']?.toString() ??
            request['pax']?.toString() ??
            '1',
      ) ??
      1;
}

String _aircraftLabel(Map<String, dynamic> request) {
  return request['assigned_aircraft_model']?.toString() ??
      request['aircraft']?.toString() ??
      request['aircraft_model']?.toString() ??
      request['aircraft_name']?.toString() ??
      _nestedText(request['contract'], 'aircraft') ??
      _nestedText(request['assigned_aircraft'], 'model') ??
      _nestedText(request['assigned_aircraft'], 'name') ??
      _nestedText(request['aircraft_data'], 'model') ??
      _nestedText(request['aircraft_data'], 'name') ??
      'Aeronave por asignar';
}

String _aircraftCapacityLabel(
  Map<String, dynamic> request,
  List<Aircraft> aircraftFleet,
) {
  final aircraftId =
      request['assigned_aircraft_id']?.toString().trim() ??
      request['aircraft_id']?.toString().trim() ??
      '';
  final aircraftName = _aircraftLabel(request).trim().toLowerCase();

  for (final aircraft in aircraftFleet) {
    final matchesId = aircraftId.isNotEmpty && aircraft.id == aircraftId;
    final matchesName =
        aircraftName.isNotEmpty &&
        (aircraft.name.trim().toLowerCase() == aircraftName ||
            aircraft.aircraftType.trim().toLowerCase() == aircraftName);
    if (matchesId || matchesName) {
      final capacity = aircraft.capacityPassengers;
      if (capacity > 0) return 'Capacidad: $capacity pax';
    }
  }

  final value =
      request['aircraft_capacity'] ??
      request['capacity'] ??
      _nestedMap(request['contract'])['passengers'];
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text == '0') return '';
  return 'Capacidad: $text pax';
}

String _aircraftCategoryLabel(Map<String, dynamic> request) {
  final value =
      request['aircraft_category'] ??
      request['cabin'] ??
      request['aircraft_type'] ??
      _nestedMap(request['contract'])['aircraft_category'];
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return '';
  return 'Cabina: $text';
}

List<_ItinerarySegment> _itinerarySegments(Map<String, dynamic> request) {
  final rawLegs = request['legs'] ?? request['segments'] ?? request['routes'];
  final segments = <_ItinerarySegment>[];

  if (rawLegs is List) {
    for (var index = 0; index < rawLegs.length; index++) {
      final leg = rawLegs[index];
      if (leg is! Map) continue;
      final origin = leg['origin']?.toString().trim() ?? '';
      final destination = leg['destination']?.toString().trim() ?? '';
      if (origin.isEmpty && destination.isEmpty) continue;
      segments.add(
        _ItinerarySegment(
          order: int.tryParse(leg['leg_order']?.toString() ?? '') ?? index + 1,
          origin: origin.isEmpty ? 'Origen por confirmar' : origin,
          destination:
              destination.isEmpty ? 'Destino por confirmar' : destination,
          departure:
              leg['departure_datetime']?.toString() ??
              leg['date']?.toString() ??
              '',
        ),
      );
    }
  }

  final requirements = request['requirements'];
  if (segments.isEmpty && requirements is List && requirements.isNotEmpty) {
    final baseOrigin = request['origin']?.toString().trim() ?? '';
    final baseDestination = request['destination']?.toString().trim() ?? '';
    if (baseOrigin.isNotEmpty || baseDestination.isNotEmpty) {
      segments.add(
        _ItinerarySegment(
          order: 1,
          origin: baseOrigin.isEmpty ? 'Origen por confirmar' : baseOrigin,
          destination:
              baseDestination.isEmpty
                  ? 'Destino por confirmar'
                  : baseDestination,
          departure: request['departure_datetime']?.toString() ?? '',
        ),
      );
    }
    for (var index = 0; index < requirements.length; index++) {
      final leg = requirements[index];
      if (leg is! Map) continue;
      final origin = leg['origin']?.toString().trim() ?? '';
      final destination = leg['destination']?.toString().trim() ?? '';
      if (origin.isEmpty && destination.isEmpty) continue;
      segments.add(
        _ItinerarySegment(
          order: index + 2,
          origin: origin.isEmpty ? 'Origen por confirmar' : origin,
          destination:
              destination.isEmpty ? 'Destino por confirmar' : destination,
          departure:
              leg['departure_datetime']?.toString() ??
              (leg['date'] == null
                  ? ''
                  : '${leg['date']}T${leg['time'] ?? '09:00'}'),
        ),
      );
    }
  }

  return segments;
}

String _aircraftImageUrl(
  Map<String, dynamic> request,
  List<Aircraft> aircraftFleet,
) {
  final direct = _firstText([
    request['aircraft_image'],
    request['image_url'],
    request['imageUrl'],
    request['aircraft_photo'],
    request['aircraft_photo_url'],
    request['aircraft_thumbnail'],
    request['main_image'],
    request['mainImage'],
    request['image'],
    request['image_path'],
    request['imagePath'],
    request['photo'],
    request['photo_url'],
    request['photoUrl'],
    request['thumbnail_url'],
    request['thumbnailUrl'],
    request['cover_image'],
    request['coverImage'],
    request['cover_photo'],
    request['coverPhoto'],
  ]);
  if (direct.isNotEmpty) return _resolveMediaUrl(direct);

  for (final key in const [
    'assigned_aircraft',
    'aircraft_data',
    'aircraft',
    'aircraft_snapshot',
    'selected_aircraft',
  ]) {
    final nested = _nestedMap(request[key]);
    if (nested.isEmpty) continue;

    final image = _firstText([
      nested['aircraft_image'],
      nested['image_url'],
      nested['imageUrl'],
      nested['aircraft_photo'],
      nested['aircraft_photo_url'],
      nested['mainImage'],
      nested['main_image'],
      nested['image'],
      nested['image_path'],
      nested['imagePath'],
      nested['photo'],
      nested['photo_url'],
      nested['photoUrl'],
      nested['thumbnail_url'],
      nested['thumbnailUrl'],
      nested['cover_image'],
      nested['coverImage'],
      nested['cover_photo'],
      nested['coverPhoto'],
    ]);
    if (image.isNotEmpty) return _resolveMediaUrl(image);

    final gallery = _firstAircraftImageFrom(nested);
    if (gallery.isNotEmpty) return gallery;
  }

  final contract = _nestedMap(request['contract']);
  final termsSnapshot = _nestedMap(contract['terms_snapshot']);
  final contractAircraft = _nestedMap(termsSnapshot['aircraft_snapshot']);
  final contractGallery = _firstAircraftImageFrom(contractAircraft);
  if (contractGallery.isNotEmpty) return contractGallery;

  final requestGallery = _firstImageFromCollection(
    request['images'] ??
        request['aircraft_images'] ??
        request['aircraftImages'] ??
        request['gallery_images'] ??
        request['galleryImages'] ??
        request['gallery'] ??
        request['photos'] ??
        request['media'] ??
        request['multimedia'] ??
        request['pictures'] ??
        request['files'],
  );
  if (requestGallery.isNotEmpty) return requestGallery;

  final fleetAircraft = _matchingFleetAircraft(request, aircraftFleet);
  if (fleetAircraft == null || fleetAircraft.imageUrl.trim().isEmpty) {
    return '';
  }

  return _resolveMediaUrl(fleetAircraft.imageUrl);
}

Aircraft? _matchingFleetAircraft(
  Map<String, dynamic> request,
  List<Aircraft> aircraftFleet,
) {
  final requestIds =
      [
            request['assigned_aircraft_id'],
            request['aircraft_id'],
            _nestedMap(request['assigned_aircraft'])['id'],
            _nestedMap(request['aircraft_data'])['id'],
            _nestedMap(request['aircraft'])['id'],
          ]
          .map((value) => value?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toSet();

  for (final aircraft in aircraftFleet) {
    if (requestIds.contains(aircraft.id)) return aircraft;
  }

  final lookup =
      [
        request['assigned_aircraft_model'],
        request['aircraft_model'],
        request['aircraft_name'],
        request['aircraft'],
        _nestedMap(request['assigned_aircraft'])['model'],
        _nestedMap(request['assigned_aircraft'])['name'],
        _nestedMap(request['aircraft_data'])['model'],
        _nestedMap(request['aircraft_data'])['name'],
        _nestedMap(request['aircraft'])['model'],
        _nestedMap(request['aircraft'])['name'],
      ].map(_normalizeLookup).where((value) => value.isNotEmpty).toSet();

  for (final aircraft in aircraftFleet) {
    final aircraftValues = {
      _normalizeLookup(aircraft.name),
      _normalizeLookup(aircraft.aircraftType),
    }..remove('');

    if (aircraftValues.any(lookup.contains)) return aircraft;
  }

  return null;
}

String _firstAircraftImageFrom(Map<String, dynamic> raw) {
  final gallery = _firstImageFromCollection(
    raw['images'] ??
        raw['aircraft_images'] ??
        raw['aircraftImages'] ??
        raw['gallery_images'] ??
        raw['galleryImages'] ??
        raw['gallery'] ??
        raw['photos'] ??
        raw['media'] ??
        raw['multimedia'] ??
        raw['pictures'] ??
        raw['files'],
  );
  if (gallery.isNotEmpty) return gallery;

  return _resolveMediaUrl(
    _firstText([
      raw['main_image'],
      raw['mainImage'],
      raw['image_url'],
      raw['imageUrl'],
      raw['image'],
      raw['image_path'],
      raw['imagePath'],
      raw['photo'],
      raw['photo_url'],
      raw['photoUrl'],
      raw['cover_image'],
      raw['coverImage'],
      raw['cover_photo'],
      raw['coverPhoto'],
      raw['thumbnail'],
      raw['thumbnail_url'],
      raw['thumbnailUrl'],
      raw['exterior_image'],
      raw['exteriorImage'],
      raw['interior_image'],
      raw['interiorImage'],
    ]),
  );
}

String _firstImageFromCollection(dynamic value) {
  final items =
      value is List
          ? value
          : value == null
          ? const []
          : [value];
  for (final item in items) {
    if (item is String && item.trim().isNotEmpty) {
      return _resolveMediaUrl(item);
    }
    if (item is Map) {
      final image = _firstText([
        item['main_image'],
        item['mainImage'],
        item['imageUrl'],
        item['image_url'],
        item['image'],
        item['url'],
        item['path'],
        item['file_url'],
        item['fileUrl'],
        item['public_url'],
        item['publicUrl'],
        item['src'],
        item['photo_url'],
      ]);
      if (image.isNotEmpty) return _resolveMediaUrl(image);
    }
  }
  return '';
}

String _resolveMediaUrl(String value) {
  return resolveMediaUrl(value);
}

Map<String, dynamic> _nestedMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _firstText(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return '';
}

int? _asProgressInt(dynamic value) {
  if (value is int) return value;
  if (value is double) {
    if (value >= 0 && value <= 1) return (value * 100).round();
    return value.round();
  }

  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;

  final parsedInt = int.tryParse(text);
  if (parsedInt != null) return parsedInt;

  final parsedDouble = double.tryParse(text);
  if (parsedDouble == null) return null;
  if (parsedDouble >= 0 && parsedDouble <= 1) {
    return (parsedDouble * 100).round();
  }
  return parsedDouble.round();
}

String _normalizeLookup(dynamic value) {
  return value?.toString().trim().toLowerCase().replaceAll(
        RegExp(r'[_\-\s]+'),
        ' ',
      ) ??
      '';
}
