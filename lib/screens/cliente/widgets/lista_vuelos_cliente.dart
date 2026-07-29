import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/acceso_comercial_cliente.dart';
import '../../../core/airport_name_index.dart';
import '../../../core/app_theme.dart';
import '../../../core/client_workflow_status.dart';
import '../../../core/media_utils.dart';
import '../../../models/aeronave.dart';
import '../../../providers/proveedor_autenticacion.dart';
import '../../../providers/proveedor_reservaciones.dart';
import '../../../services/servicio_aeropuertos.dart';
import '../tema_cliente.dart';
import '../views/pantalla_detalle_aeronave_cliente.dart';
import '../views/pantalla_concierge_cliente.dart';

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
  static const String _guideCompletedKey = 'client_flights_guide_completed_v1';

  late _TripTab _activeTab;
  Timer? _autoRefreshTimer;
  Map<String, String> _airportNames = buildAirportNameIndex(const []);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _activeTab = _TripTab.upcoming;
    final provider = context.read<ReservationProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      provider.loadClientWorkspaceData();
      unawaited(_loadAirportNames());
      unawaited(_showFirstVisitGuide());
    });

    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      _refreshFlights(force: true);
    });
  }

  Future<void> _loadAirportNames() async {
    final names = <String, String>{
      ...buildAirportNameIndex(context.read<ReservationProvider>().airports),
    };
    if (names.isNotEmpty && mounted) {
      setState(() => _airportNames = Map.unmodifiable(names));
    }

    try {
      final airports = await AirportService.getAirports();
      if (!mounted) return;
      names.addAll(buildAirportNameIndex(airports));
      setState(() => _airportNames = Map.unmodifiable(names));
    } catch (_) {
      // Conserva el catálogo local; usa códigos solo si tampoco existe caché.
    }
  }

  Future<void> _showFirstVisitGuide() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted || preferences.getBool(_guideCompletedKey) == true) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Guía de Tus vuelos',
      barrierColor: Colors.black.withValues(alpha: .82),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder:
          (dialogContext, animation, secondaryAnimation) =>
              _FlightsFirstVisitGuide(
                onComplete: () async {
                  await preferences.setBool(_guideCompletedKey, true);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
      transitionBuilder:
          (_, animation, secondaryAnimation, child) => FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: .96, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: child,
            ),
          ),
    );
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
    final provider = context.watch<ReservationProvider>();
    final allRequests = provider.flightRequests;
    final tabRequests = _filterRequests(allRequests);
    final filteredRequests = tabRequests;
    final upcomingRequests = _filterRequestsForTab(
      allRequests,
      _TripTab.upcoming,
    );
    final nextFlight = upcomingRequests.isEmpty ? null : upcomingRequests.first;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF08111E),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: const Color(0xFFD7B15D),
          backgroundColor: const Color(0xFF101C2D),
          onRefresh: () => provider.loadClientWorkspaceData(force: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(24, 18, 24, 34 + bottomInset),
            children: [
              _PremiumFlightsHeader(
                flightCount: allRequests.length,
                showBackButton: widget.showBackButton,
                onBack: () => Navigator.pop(context),
                onNotifications:
                    () => _showActionMessage('Sin notificaciones nuevas.'),
              ),
              const SizedBox(height: 24),
              _NextFlightHero(
                request: nextFlight,
                aircraftFleet: provider.aircraftFleet,
                airportNames: _airportNames,
                onTap:
                    nextFlight == null
                        ? widget.onOpenSearch
                        : () =>
                            _openRequestForCurrentStage(provider, nextFlight),
              ),
              if (_shouldShowWorkspaceAlert(provider.workspaceMessage)) ...[
                const SizedBox(height: 14),
                _WorkspaceAlert(
                  message: provider.workspaceMessage,
                  loading: provider.isLoadingWorkspace,
                  onRefresh:
                      () => provider.loadClientWorkspaceData(force: true),
                ),
              ],
              const SizedBox(height: 22),
              _PremiumTripTabs(
                tabs: _availableTabs,
                activeTab: _activeTab,
                onChanged: (tab) => setState(() => _activeTab = tab),
              ),
              const SizedBox(height: 22),
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
                    duration: Duration(milliseconds: 360 + entry.key * 70),
                    curve: Curves.easeOutCubic,
                    builder:
                        (context, value, child) => Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 28 * (1 - value)),
                            child: child,
                          ),
                        ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _PremiumFlightCard(
                        request: entry.value,
                        aircraftFleet: provider.aircraftFleet,
                        airportNames: _airportNames,
                        onTap:
                            () => _openRequestForCurrentStage(
                              provider,
                              entry.value,
                            ),
                        onMenu: () => _showFlightMenu(entry.value),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              _NewFlightButton(onTap: widget.onOpenSearch),
            ],
          ),
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
    final aircraft = _resolveAircraft(provider, request);
    final imageUrl = _aircraftImageUrl(request, provider.aircraftFleet);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .78),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder:
          (sheetContext) => _LuxuryFlightDetailSheet(
            request: request,
            meta: meta,
            aircraft: aircraft,
            aircraftFleet: provider.aircraftFleet,
            airportNames: _airportNames,
            imageUrl: imageUrl,
            contractEnabled: contractEnabled,
            paymentEnabled: paymentEnabled,
            conciergeEnabled: conciergeEnabled,
            onClose: () => Navigator.pop(sheetContext),
            onConcierge: () => _openConcierge(request),
            onAircraft: () => _openAircraft(provider, request),
            onContract: () => _handleOpenContract(request),
            onPayment: () => _handleOpenPayment(request),
            onTracking: null,
          ),
    );
  }

  void _openRequestForCurrentStage(
    ReservationProvider provider,
    Map<String, dynamic> request,
  ) {
    final workflowId = _workflowStageId(_resolvedWorkflowStage(request));

    if (_contractActionEnabled(request, workflowId)) {
      _handleOpenContract(request);
      return;
    }

    if (_paymentActionEnabled(request, workflowId)) {
      _handleOpenPayment(request);
      return;
    }

    _showFlightSheet(provider, request);
  }

  void _showFlightMenu(Map<String, dynamic> request) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder:
          (sheetContext) => SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              decoration: BoxDecoration(
                color: const Color(0xFF101C2D),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  for (final action in const [
                    (Icons.edit_outlined, 'Editar'),
                    (Icons.copy_rounded, 'Duplicar'),
                    (Icons.cancel_outlined, 'Cancelar'),
                    (Icons.ios_share_rounded, 'Compartir'),
                  ])
                    ListTile(
                      minTileHeight: 52,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      leading: Icon(
                        action.$1,
                        color:
                            action.$2 == 'Cancelar'
                                ? const Color(0xFFFF6B6B)
                                : const Color(0xFFD7B15D),
                      ),
                      title: Text(
                        action.$2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () => Navigator.pop(sheetContext),
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
      normalized.contains('inicia sesion');
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

class _LuxuryFlightDetailSheet extends StatelessWidget {
  const _LuxuryFlightDetailSheet({
    required this.request,
    required this.meta,
    required this.aircraft,
    required this.aircraftFleet,
    required this.airportNames,
    required this.imageUrl,
    required this.contractEnabled,
    required this.paymentEnabled,
    required this.conciergeEnabled,
    required this.onClose,
    required this.onConcierge,
    required this.onAircraft,
    required this.onContract,
    required this.onPayment,
    required this.onTracking,
  });

  final Map<String, dynamic> request;
  final _WorkflowMeta meta;
  final Aircraft? aircraft;
  final List<Aircraft> aircraftFleet;
  final Map<String, String> airportNames;
  final String imageUrl;
  final bool contractEnabled;
  final bool paymentEnabled;
  final bool conciergeEnabled;
  final VoidCallback onClose;
  final VoidCallback onConcierge;
  final VoidCallback onAircraft;
  final VoidCallback onContract;
  final VoidCallback onPayment;
  final VoidCallback? onTracking;

  @override
  Widget build(BuildContext context) {
    final route = _routeParts(request, airportNames);
    final departure = _departureCopy(request).split(',');
    final date = departure.first.trim();
    final time =
        departure.length > 1 ? departure.sublist(1).join(',').trim() : '';

    return FractionallySizedBox(
      heightFactor: .9,
      alignment: Alignment.bottomCenter,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutBack,
        builder:
            (_, value, child) => Transform.translate(
              offset: Offset(0, 34 * (1 - value)),
              child: Opacity(opacity: value.clamp(0, 1), child: child),
            ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: ColoredBox(
              color: const Color(0xFF07111D).withValues(alpha: .96),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FlightSheetHero(
                      route: route,
                      meta: meta,
                      imageUrl: imageUrl,
                      onClose: onClose,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FlightSummaryGrid(
                            date: date,
                            time: time,
                            aircraft: _aircraftLabel(request),
                            passengers: _passengerCount(request).toString(),
                            reservation: _requestCode(request),
                          ),
                          const SizedBox(height: 20),
                          _FlightReadyCard(meta: meta),
                          const SizedBox(height: 24),
                          const _SheetSectionTitle('Acciones'),
                          const SizedBox(height: 14),
                          _FlightActionsGrid(
                            conciergeEnabled: conciergeEnabled,
                            contractEnabled: contractEnabled,
                            paymentEnabled: paymentEnabled,
                            onConcierge: onConcierge,
                            onAircraft: onAircraft,
                            onContract: onContract,
                            onPayment: onPayment,
                          ),
                          const SizedBox(height: 26),
                          const _SheetSectionTitle('Vuelo'),
                          const SizedBox(height: 15),
                          _FlightTimeline(activeStep: meta.activeStep),
                          const SizedBox(height: 26),
                          _AircraftDetailCard(
                            request: request,
                            aircraft: aircraft,
                            aircraftFleet: aircraftFleet,
                            imageUrl: imageUrl,
                            onTap: onAircraft,
                          ),
                          const SizedBox(height: 16),
                          _ConciergeDetailCard(
                            enabled: conciergeEnabled,
                            onTap: onConcierge,
                          ),
                          const SizedBox(height: 26),
                          const _SheetSectionTitle('Documentos'),
                          const SizedBox(height: 8),
                          _FlightDocuments(
                            contractEnabled: contractEnabled,
                            paymentEnabled: paymentEnabled,
                            onContract: onContract,
                            onPayment: onPayment,
                          ),
                          const SizedBox(height: 28),
                          if (onTracking != null) ...[
                            _SheetScaleButton(
                              onTap: onTracking,
                              child: Container(
                                height: 56,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD8B25D),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Text(
                                  'Ver seguimiento',
                                  style: TextStyle(
                                    color: Color(0xFF111820),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          _SheetScaleButton(
                            onTap: onClose,
                            child: Container(
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFD8B25D),
                                ),
                              ),
                              child: const Text(
                                'Cerrar',
                                style: TextStyle(
                                  color: Color(0xFFD8B25D),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlightSheetHero extends StatelessWidget {
  const _FlightSheetHero({
    required this.route,
    required this.meta,
    required this.imageUrl,
    required this.onClose,
  });

  final (String, String) route;
  final _WorkflowMeta meta;
  final String imageUrl;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _PremiumJetImage(imageUrl: imageUrl),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0, .58, 1],
                colors: [
                  Color(0xF807111D),
                  Color(0xC807111D),
                  Color(0x3307111D),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _PremiumStatusPill(meta: meta),
                    const Spacer(),
                    ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: IconButton(
                          tooltip: 'Cerrar',
                          onPressed: onClose,
                          style: IconButton.styleFrom(
                            fixedSize: const Size(46, 46),
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withValues(
                              alpha: .08,
                            ),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: .12),
                            ),
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  route.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.9,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 3),
                  child: Icon(
                    Icons.arrow_downward_rounded,
                    color: Color(0xFFD8B25D),
                    size: 22,
                  ),
                ),
                Text(
                  route.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.9,
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

class _FlightSummaryGrid extends StatelessWidget {
  const _FlightSummaryGrid({
    required this.date,
    required this.time,
    required this.aircraft,
    required this.passengers,
    required this.reservation,
  });

  final String date;
  final String time;
  final String aircraft;
  final String passengers;
  final String reservation;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.calendar_month_outlined, 'Fecha', date, time),
      (Icons.flight_rounded, 'Aeronave', aircraft, ''),
      (Icons.person_outline_rounded, 'Pasajeros', passengers, ''),
      (Icons.confirmation_number_outlined, 'Reserva', reservation, ''),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 104,
      ),
      itemBuilder: (_, index) {
        final item = items[index];
        return _AnimatedSheetCard(
          index: index,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFF101C2D),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(item.$1, color: const Color(0xFFD8B25D), size: 19),
                    const SizedBox(width: 7),
                    Text(
                      item.$2,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  item.$3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.$4.isNotEmpty)
                  Text(
                    item.$4,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .58),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FlightReadyCard extends StatelessWidget {
  const _FlightReadyCard({required this.meta});

  final _WorkflowMeta meta;

  @override
  Widget build(BuildContext context) {
    final ready =
        meta.tone == _WorkflowTone.confirmed ||
        meta.tone == _WorkflowTone.completed;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1624),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFD8B25D).withValues(alpha: .22),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD8B25D).withValues(alpha: .06),
            blurRadius: 22,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD8B25D).withValues(alpha: .1),
            ),
            child: Icon(
              ready ? Icons.auto_awesome_rounded : Icons.schedule_rounded,
              color: const Color(0xFFD8B25D),
              size: 21,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready ? 'Todo listo para volar.' : meta.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ready
                      ? 'La aeronave y la tripulación han sido confirmadas.'
                      : meta.nextAction,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .62),
                    fontSize: 13,
                    height: 1.3,
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

class _FlightActionsGrid extends StatelessWidget {
  const _FlightActionsGrid({
    required this.conciergeEnabled,
    required this.contractEnabled,
    required this.paymentEnabled,
    required this.onConcierge,
    required this.onAircraft,
    required this.onContract,
    required this.onPayment,
  });

  final bool conciergeEnabled;
  final bool contractEnabled;
  final bool paymentEnabled;
  final VoidCallback onConcierge;
  final VoidCallback onAircraft;
  final VoidCallback onContract;
  final VoidCallback onPayment;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        Icons.support_agent_rounded,
        'Concierge',
        conciergeEnabled ? onConcierge : null,
      ),
      (Icons.flight_rounded, 'Aeronave', onAircraft),
      (
        Icons.description_outlined,
        'Contrato',
        contractEnabled ? onContract : null,
      ),
      (Icons.credit_card_outlined, 'Pago', paymentEnabled ? onPayment : null),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 78,
      ),
      itemBuilder: (_, index) {
        final action = actions[index];
        final enabled = action.$3 != null;
        return _SheetScaleButton(
          onTap: action.$3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: const Color(0xFF101C2D),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Row(
              children: [
                Icon(
                  action.$1,
                  color:
                      enabled
                          ? const Color(0xFFD8B25D)
                          : Colors.white.withValues(alpha: .28),
                  size: 24,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    action.$2,
                    style: TextStyle(
                      color:
                          enabled
                              ? Colors.white
                              : Colors.white.withValues(alpha: .35),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: enabled ? .5 : .2),
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FlightTimeline extends StatelessWidget {
  const _FlightTimeline({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Reserva creada',
      'Pago confirmado',
      'Operación confirmada',
      'Tripulación asignada',
      'Vuelo realizado',
    ];
    return Column(
      children: List.generate(steps.length, (index) {
        final done = index < activeStep;
        final last = index == steps.length - 1;
        return IntrinsicHeight(
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            done ? const Color(0xFFD8B25D) : Colors.transparent,
                        border: Border.all(color: const Color(0xFFD8B25D)),
                      ),
                      child:
                          done
                              ? const Icon(
                                Icons.check_rounded,
                                color: Color(0xFF07111D),
                                size: 13,
                              )
                              : null,
                    ),
                    if (!last)
                      Expanded(
                        child: Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          color: const Color(0xFFD8B25D).withValues(alpha: .38),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: last ? 0 : 17),
                  child: Text(
                    steps[index],
                    style: TextStyle(
                      color:
                          done
                              ? Colors.white
                              : Colors.white.withValues(alpha: .52),
                      fontSize: 14,
                      fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _AircraftDetailCard extends StatelessWidget {
  const _AircraftDetailCard({
    required this.request,
    required this.aircraft,
    required this.aircraftFleet,
    required this.imageUrl,
    required this.onTap,
  });

  final Map<String, dynamic> request;
  final Aircraft? aircraft;
  final List<Aircraft> aircraftFleet;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = _aircraftCategoryLabel(request);
    final capacity =
        aircraft?.capacityPassengers ??
        int.tryParse(request['aircraft_capacity']?.toString() ?? '') ??
        0;
    final range = _firstText([
      request['aircraft_range'],
      request['range'],
      request['autonomy'],
    ]);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2D),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 104,
              height: 112,
              child: _PremiumJetImage(imageUrl: imageUrl),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _aircraftLabel(request),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .58),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  capacity > 0
                      ? '$capacity pasajeros'
                      : 'Capacidad por confirmar',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .7),
                    fontSize: 12,
                  ),
                ),
                if (range.isNotEmpty)
                  Text(
                    'Autonomía $range',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .7),
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 9),
                GestureDetector(
                  onTap: onTap,
                  child: const Text(
                    'Ver ficha  →',
                    style: TextStyle(
                      color: Color(0xFFD8B25D),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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

class _ConciergeDetailCard extends StatelessWidget {
  const _ConciergeDetailCard({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2D),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.support_agent_rounded,
            color: Color(0xFFD8B25D),
            size: 27,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Tu concierge está listo para ayudarte.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .82),
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: enabled ? onTap : null,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD8B25D),
            ),
            child: const Text('Contactar'),
          ),
        ],
      ),
    );
  }
}

class _FlightDocuments extends StatelessWidget {
  const _FlightDocuments({
    required this.contractEnabled,
    required this.paymentEnabled,
    required this.onContract,
    required this.onPayment,
  });

  final bool contractEnabled;
  final bool paymentEnabled;
  final VoidCallback onContract;
  final VoidCallback onPayment;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Contrato', contractEnabled ? onContract : null),
      ('Pago', paymentEnabled ? onPayment : null),
    ];
    return Column(
      children: List.generate(items.length, (index) {
        final item = items[index];
        return Column(
          children: [
            InkWell(
              onTap: item.$2,
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Icon(
                      index == 0
                          ? Icons.description_outlined
                          : Icons.receipt_long_outlined,
                      color: const Color(0xFFD8B25D),
                      size: 21,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        item.$1,
                        style: TextStyle(
                          color:
                              item.$2 == null
                                  ? Colors.white.withValues(alpha: .35)
                                  : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: .42),
                    ),
                  ],
                ),
              ),
            ),
            if (index != items.length - 1)
              Divider(height: 1, color: Colors.white.withValues(alpha: .08)),
          ],
        );
      }),
    );
  }
}

class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 21,
        fontWeight: FontWeight.w700,
        letterSpacing: -.3,
      ),
    );
  }
}

class _AnimatedSheetCard extends StatelessWidget {
  const _AnimatedSheetCard({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + index * 65),
      curve: Curves.easeOutCubic,
      builder:
          (_, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - value)),
              child: child,
            ),
          ),
      child: child,
    );
  }
}

class _SheetScaleButton extends StatefulWidget {
  const _SheetScaleButton({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_SheetScaleButton> createState() => _SheetScaleButtonState();
}

class _SheetScaleButtonState extends State<_SheetScaleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown:
          widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 1.02 : 1,
        duration: const Duration(milliseconds: 140),
        child: widget.child,
      ),
    );
  }
}

class _PremiumFlightsHeader extends StatelessWidget {
  const _PremiumFlightsHeader({
    required this.flightCount,
    required this.showBackButton,
    required this.onBack,
    required this.onNotifications,
  });

  final int flightCount;
  final bool showBackButton;
  final VoidCallback onBack;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (showBackButton) ...[
              IconButton(
                onPressed: onBack,
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF101C2D),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 10),
            ],
            Image.asset(
              'assets/LOGOINTERNO.png',
              width: 48,
              height: 48,
              color: const Color(0xFFD7B15D),
              colorBlendMode: BlendMode.srcIn,
              filterQuality: FilterQuality.high,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF101C2D),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFD7B15D).withValues(alpha: .28),
                ),
              ),
              child: Text(
                '$flightCount ${flightCount == 1 ? 'vuelo' : 'vuelos'}',
                style: const TextStyle(
                  color: Color(0xFFD7B15D),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Notificaciones',
              onPressed: onNotifications,
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFFD7B15D),
                backgroundColor: const Color(0xFF101C2D),
                minimumSize: const Size(44, 44),
              ),
              icon: const Icon(Icons.notifications_none_rounded, size: 24),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'Tus vuelos',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Todo listo para tu próximo destino.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .65),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _NextFlightHero extends StatelessWidget {
  const _NextFlightHero({
    required this.request,
    required this.aircraftFleet,
    required this.airportNames,
    required this.onTap,
  });

  final Map<String, dynamic>? request;
  final List<Aircraft> aircraftFleet;
  final Map<String, String> airportNames;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final flight = request;
    final route =
        flight == null
            ? const ('Tu próximo destino', 'Por descubrir')
            : _routeParts(flight, airportNames);
    final imageUrl =
        flight == null ? '' : _aircraftImageUrl(flight, aircraftFleet);
    final status = flight == null ? null : _statusMeta(flight);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder:
          (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - value)),
              child: child,
            ),
          ),
      child: SizedBox(
        height: 230,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF101C2D)),
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: MediaQuery.sizeOf(context).width * .48,
                child: _PremiumJetImage(imageUrl: imageUrl),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: [0, .55, 1],
                    colors: [
                      Color(0xFF101C2D),
                      Color(0xEE101C2D),
                      Color(0x55101C2D),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 18, 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'PRÓXIMO VUELO',
                          style: TextStyle(
                            color: Color(0xFFD7B15D),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.35,
                          ),
                        ),
                        const Spacer(),
                        if (status != null)
                          _PremiumStatusPill(meta: status, compact: true),
                      ],
                    ),
                    const SizedBox(height: 15),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 245),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            route.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1.05,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Icon(
                              Icons.arrow_downward_rounded,
                              color: Color(0xFFD7B15D),
                              size: 18,
                            ),
                          ),
                          Text(
                            route.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1.05,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (flight != null)
                      Row(
                        children: [
                          _HeroMeta(
                            icon: Icons.calendar_month_outlined,
                            label: _departureCopy(flight),
                          ),
                          const SizedBox(width: 11),
                          _HeroMeta(
                            icon: Icons.people_outline_rounded,
                            label: '${_passengerCount(flight)} pax',
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: _HeroMeta(
                              icon: Icons.flight_rounded,
                              label: _aircraftLabel(flight),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    _ScaleTap(
                      onTap: onTap,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            flight == null ? 'Nuevo vuelo' : 'Ver detalles',
                            style: const TextStyle(
                              color: Color(0xFFD7B15D),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFFD7B15D),
                            size: 17,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFD7B15D), size: 15),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 100),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .68),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumTripTabs extends StatelessWidget {
  const _PremiumTripTabs({
    required this.tabs,
    required this.activeTab,
    required this.onChanged,
  });

  final List<_TripTab> tabs;
  final _TripTab activeTab;
  final ValueChanged<_TripTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children:
            tabs.map((tab) {
              final active = tab == activeTab;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color:
                          active ? const Color(0xFF16253B) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border(
                        bottom: BorderSide(
                          color:
                              active
                                  ? const Color(0xFFD7B15D)
                                  : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _tabLabel(tab),
                      style: TextStyle(
                        color:
                            active
                                ? const Color(0xFFD7B15D)
                                : Colors.white.withValues(alpha: .55),
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _PremiumFlightCard extends StatefulWidget {
  const _PremiumFlightCard({
    required this.request,
    required this.aircraftFleet,
    required this.airportNames,
    required this.onTap,
    required this.onMenu,
  });

  final Map<String, dynamic> request;
  final List<Aircraft> aircraftFleet;
  final Map<String, String> airportNames;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  @override
  State<_PremiumFlightCard> createState() => _PremiumFlightCardState();
}

class _PremiumFlightCardState extends State<_PremiumFlightCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final meta = _statusMeta(widget.request);
    final route = _routeParts(widget.request, widget.airportNames);
    final imageUrl = _aircraftImageUrl(widget.request, widget.aircraftFleet);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 1.02 : 1,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 150,
          decoration: BoxDecoration(
            color: _pressed ? const Color(0xFF16253B) : const Color(0xFF101C2D),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _pressed ? .34 : .20),
                blurRadius: _pressed ? 28 : 18,
                offset: Offset(0, _pressed ? 14 : 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: Row(
              children: [
                SizedBox(
                  width: MediaQuery.sizeOf(context).width * .31,
                  height: double.infinity,
                  child: _PremiumJetImage(imageUrl: imageUrl),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(15, 12, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _PremiumStatusPill(meta: meta),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Más opciones',
                              onPressed: widget.onMenu,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 30,
                              ),
                              icon: Icon(
                                Icons.more_horiz_rounded,
                                color: Colors.white.withValues(alpha: .55),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${route.$1}\n→ ${route.$2}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  height: 1.22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFFD7B15D),
                              size: 25,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: _CardMeta(
                                icon: Icons.calendar_month_outlined,
                                value: _departureCopy(widget.request),
                              ),
                            ),
                            _CardMeta(
                              icon: Icons.people_outline_rounded,
                              value: '${_passengerCount(widget.request)} pax',
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CardMeta(
                                icon: Icons.flight_rounded,
                                value: _aircraftLabel(widget.request),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardMeta extends StatelessWidget {
  const _CardMeta({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFD7B15D), size: 14),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .62),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumStatusPill extends StatelessWidget {
  const _PremiumStatusPill({required this.meta, this.compact = false});

  final _WorkflowMeta meta;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final confirmed =
        meta.tone == _WorkflowTone.confirmed ||
        meta.tone == _WorkflowTone.completed;
    final color = confirmed ? const Color(0xFF31D158) : const Color(0xFFD7B15D);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            meta.label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: compact ? 8.5 : 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumJetImage extends StatelessWidget {
  const _PremiumJetImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Image.asset(
      'assets/login/image.png',
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
    );

    if (imageUrl.trim().isEmpty || !imageUrl.startsWith('http')) {
      return fallback();
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback(),
      loadingBuilder:
          (_, child, progress) => progress == null ? child : fallback(),
    );
  }
}

class _NewFlightButton extends StatelessWidget {
  const _NewFlightButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _ScaleTap(
      onTap: onTap,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD7B15D), width: 1.2),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Color(0xFFD7B15D), size: 22),
            SizedBox(width: 8),
            Text(
              'Nuevo vuelo',
              style: TextStyle(
                color: Color(0xFFD7B15D),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScaleTap extends StatefulWidget {
  const _ScaleTap({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<_ScaleTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown:
          widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 1.02 : 1,
        duration: const Duration(milliseconds: 140),
        child: widget.child,
      ),
    );
  }
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

// Componentes históricos conservados para no alterar flujos de detalle.
// ignore: unused_element
class _FlightsOverviewPanel extends StatelessWidget {
  const _FlightsOverviewPanel({
    required this.totalFlights,
    required this.visibleFlights,
    required this.attentionCount,
    required this.nextFlight,
    required this.airportNames,
    required this.loading,
    required this.lastSyncAt,
    required this.onRefresh,
    required this.onOpenSearch,
  });

  final int totalFlights;
  final int visibleFlights;
  final int attentionCount;
  final Map<String, dynamic>? nextFlight;
  final Map<String, String> airportNames;
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
        hasNextFlight
            ? _routeLabel(nextFlight!, airportNames: airportNames)
            : 'Sin vuelo activo';
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
                      maxLines: 2,
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

// ignore: unused_element
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

// ignore: unused_element
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

// ignore: unused_element
class _MinimalFlightCard extends StatelessWidget {
  const _MinimalFlightCard({
    required this.request,
    required this.aircraftFleet,
    required this.airportNames,
    required this.onTap,
    required this.onOpenAircraft,
    required this.onOpenContract,
    required this.onOpenPayment,
    required this.onOpenConcierge,
  });

  final Map<String, dynamic> request;
  final List<Aircraft> aircraftFleet;
  final Map<String, String> airportNames;
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
              _routeLabel(request, airportNames: airportNames),
              maxLines: 2,
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

String _routeLabel(
  Map<String, dynamic> request, {
  Map<String, String> airportNames = const {},
}) {
  final segments = _itinerarySegments(request);
  if (segments.isNotEmpty) {
    final points = <String>[];
    for (final segment in segments) {
      final origin = airportDisplayName(segment.origin, airportNames);
      final destination = airportDisplayName(segment.destination, airportNames);
      if (points.isEmpty) {
        points.add(origin);
      } else if (points.last != origin) {
        points.add(origin);
      }
      if (destination.isNotEmpty && points.last != destination) {
        points.add(destination);
      }
    }
    if (points.isNotEmpty) {
      return points.join(' → ');
    }
  }

  final origin = request['origin']?.toString() ?? '';
  final destination = request['destination']?.toString() ?? '';

  if (origin.isNotEmpty || destination.isNotEmpty) {
    return '${airportDisplayName(origin, airportNames)} → '
        '${airportDisplayName(destination, airportNames)}';
  }

  return 'Ruta por confirmar';
}

(String, String) _routeParts(
  Map<String, dynamic> request,
  Map<String, String> airportNames,
) {
  final label = _routeLabel(request, airportNames: airportNames);
  final points =
      label
          .split(RegExp(r'\s*→\s*'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
  if (points.length >= 2) return (points.first, points.last);
  return (label, 'Destino por confirmar');
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

class _FlightsFirstVisitGuide extends StatefulWidget {
  const _FlightsFirstVisitGuide({required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  State<_FlightsFirstVisitGuide> createState() =>
      _FlightsFirstVisitGuideState();
}

class _FlightsFirstVisitGuideState extends State<_FlightsFirstVisitGuide> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _closing = false;

  static const _steps = <_FlightsGuideStep>[
    _FlightsGuideStep(
      eyebrow: 'TU CENTRO DE VUELO',
      title: 'Todo tu viaje,\nen un solo lugar.',
      description:
          'Aquí verás cuál es tu próximo vuelo, cuándo sale y qué aeronave tiene asignada.',
      icon: Icons.flight_takeoff_rounded,
      bullets: [
        (Icons.route_rounded, 'Ruta y horario'),
        (Icons.airline_seat_recline_extra_rounded, 'Pasajeros'),
        (Icons.flight_rounded, 'Aeronave asignada'),
      ],
    ),
    _FlightsGuideStep(
      eyebrow: 'FLUJO DE TU RESERVA',
      title: 'Siempre sabrás\nqué sigue.',
      description:
          'El estado cambia automáticamente conforme avanzan el operador y nuestro equipo.',
      icon: Icons.timeline_rounded,
      bullets: [
        (Icons.send_rounded, 'Solicitud'),
        (Icons.verified_outlined, 'Confirmación'),
        (Icons.description_outlined, 'Contrato'),
        (Icons.credit_card_rounded, 'Pago'),
        (Icons.check_circle_outline_rounded, 'Vuelo listo'),
      ],
      isFlow: true,
    ),
    _FlightsGuideStep(
      eyebrow: 'DETALLE DEL VUELO',
      title: 'Toca una tarjeta\npara abrirla.',
      description:
          'El detalle concentra únicamente la información y las acciones disponibles para esa etapa.',
      icon: Icons.touch_app_rounded,
      bullets: [
        (Icons.support_agent_rounded, 'Concierge'),
        (Icons.flight_outlined, 'Aeronave'),
        (Icons.description_outlined, 'Contrato'),
        (Icons.payment_rounded, 'Pago'),
      ],
    ),
    _FlightsGuideStep(
      eyebrow: 'NAVEGACIÓN',
      title: 'Muévete con\nfacilidad.',
      description:
          'Busca un nuevo vuelo, revisa tus reservas o administra tu perfil desde la barra inferior.',
      icon: Icons.explore_outlined,
      bullets: [
        (Icons.search_rounded, 'Buscar'),
        (Icons.flight_takeoff_rounded, 'Reservas'),
        (Icons.person_outline_rounded, 'Perfil'),
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_closing) return;
    setState(() => _closing = true);
    await widget.onComplete();
  }

  void _next() {
    if (_page == _steps.length - 1) {
      unawaited(_finish());
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _steps.length - 1;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430, maxHeight: 690),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1726).withValues(alpha: .96),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .42),
                          blurRadius: 38,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 18, 15, 4),
                          child: Row(
                            children: [
                              ColorFiltered(
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                                child: Image.asset(
                                  'assets/LOGOINTERNO.png',
                                  width: 38,
                                  height: 30,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'RED SKY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed:
                                    _closing
                                        ? null
                                        : () => unawaited(_finish()),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white.withValues(
                                    alpha: .62,
                                  ),
                                ),
                                child: const Text(
                                  'Omitir',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: PageView.builder(
                            controller: _controller,
                            itemCount: _steps.length,
                            onPageChanged: (value) {
                              setState(() => _page = value);
                            },
                            itemBuilder:
                                (_, index) =>
                                    _FlightsGuidePage(step: _steps[index]),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  _steps.length,
                                  (index) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    width: index == _page ? 24 : 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          index == _page
                                              ? const Color(0xFFD7B15D)
                                              : Colors.white.withValues(
                                                alpha: .2,
                                              ),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              GestureDetector(
                                onTap: _closing ? null : _next,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFF0D184),
                                        Color(0xFFD7A944),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_closing)
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF07111D),
                                          ),
                                        )
                                      else ...[
                                        Text(
                                          isLast ? 'Entendido' : 'Continuar',
                                          style: const TextStyle(
                                            color: Color(0xFF07111D),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          isLast
                                              ? Icons.check_rounded
                                              : Icons.arrow_forward_rounded,
                                          color: const Color(0xFF07111D),
                                          size: 20,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlightsGuidePage extends StatelessWidget {
  const _FlightsGuidePage({required this.step});

  final _FlightsGuideStep step;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD7B15D).withValues(alpha: .1),
              border: Border.all(
                color: const Color(0xFFD7B15D).withValues(alpha: .42),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD7B15D).withValues(alpha: .12),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Icon(step.icon, color: const Color(0xFFD7B15D), size: 31),
          ),
          const SizedBox(height: 22),
          Text(
            step.eyebrow,
            style: const TextStyle(
              color: Color(0xFFD7B15D),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            step.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 31,
              height: 1.02,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            step.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .68),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          if (step.isFlow)
            _GuideFlow(items: step.bullets)
          else
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children:
                  step.bullets
                      .map(
                        (item) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.$1,
                                color: const Color(0xFFD7B15D),
                                size: 17,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                item.$2,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
            ),
        ],
      ),
    );
  }
}

class _GuideFlow extends StatelessWidget {
  const _GuideFlow({required this.items});

  final List<(IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++)
          Row(
            children: [
              SizedBox(
                width: 28,
                height: 37,
                child: Column(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            index < 2
                                ? const Color(0xFF31D158).withValues(alpha: .16)
                                : Colors.transparent,
                        border: Border.all(
                          color:
                              index < 2
                                  ? const Color(0xFF31D158)
                                  : Colors.white.withValues(alpha: .24),
                        ),
                      ),
                      child: Icon(
                        index < 2 ? Icons.check_rounded : items[index].$1,
                        color:
                            index < 2
                                ? const Color(0xFF31D158)
                                : Colors.white.withValues(alpha: .48),
                        size: 12,
                      ),
                    ),
                    if (index != items.length - 1)
                      Expanded(
                        child: Container(
                          width: 1,
                          color: const Color(0xFFD7B15D).withValues(alpha: .35),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 17),
                child: Text(
                  items[index].$2,
                  style: TextStyle(
                    color:
                        index < 2
                            ? Colors.white
                            : Colors.white.withValues(alpha: .55),
                    fontSize: 13,
                    fontWeight: index < 2 ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _FlightsGuideStep {
  const _FlightsGuideStep({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.bullets,
    this.isFlow = false,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final List<(IconData, String)> bullets;
  final bool isFlow;
}
