import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/cliente_api.dart';
import '../../../models/aeronave.dart';
import '../../../providers/proveedor_reservaciones.dart';
import '../views/pantalla_detalle_aeronave_cliente.dart';
import '../views/pantalla_concierge_cliente.dart';
import 'widgets_experiencia_cliente.dart';

const Color kBg = Color(0xFFF7F7F7);
const Color kWhite = Colors.white;
const Color kBlack = Color(0xFF050505);
const Color kText = Color(0xFF111111);
const Color kMuted = Color(0xFF666666);
const Color kBorder = Color(0xFFE6E6E6);
const Color kSoft = Color(0xFFF2F2F2);

class ClientFlightsList extends StatefulWidget {
  const ClientFlightsList({
    super.key,
    required this.heading,
    required this.description,
    this.showBackButton = true,
    this.onOpenContract,
    this.onOpenPayment,
    this.includeUpcomingTab = true,
  });

  final String heading;
  final String description;
  final bool showBackButton;
  final ValueChanged<Map<String, dynamic>>? onOpenContract;
  final ValueChanged<Map<String, dynamic>>? onOpenPayment;
  final bool includeUpcomingTab;

  @override
  State<ClientFlightsList> createState() => _ClientFlightsListState();
}

class _ClientFlightsListState extends State<ClientFlightsList> {
  late _TripTab _activeTab;

  @override
  void initState() {
    super.initState();

    _activeTab =
        widget.includeUpcomingTab ? _TripTab.processing : _TripTab.history;
    final provider = context.read<ReservationProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      provider.loadClientWorkspaceData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReservationProvider>();
    final allRequests = provider.flightRequests;
    final filteredRequests = _filterRequests(allRequests);

    return ClientExperienceShell(
      title: 'Mis vuelos',
      subtitle: 'Reservas y seguimiento.',
      showBackButton: widget.showBackButton,
      trailing: StatusBadge(
        label: '${allRequests.length} vuelos',
        color: kBlack,
      ),
      child: RefreshIndicator(
        color: kBlack,
        backgroundColor: kWhite,
        onRefresh: () => provider.loadClientWorkspaceData(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
          children: [
            Text(
              widget.heading,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: kBlack,
                height: 1.02,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.description,
              style: const TextStyle(
                color: kMuted,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: 14),
            if (provider.isLoadingWorkspace && allRequests.isEmpty)
              const _MinimalLoadingCard()
            else if (filteredRequests.isEmpty)
              _EmptyFlightsCard(label: _activeTabLabel)
            else
              ...filteredRequests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MinimalFlightCard(
                    request: request,
                    aircraftFleet: provider.aircraftFleet,
                    onTap: () => _showFlightSheet(provider, request),
                    onOpenAircraft: () => _openAircraft(provider, request),
                    onOpenContract: () => _handleOpenContract(request),
                    onOpenPayment: () => _handleOpenPayment(request),
                    onOpenConcierge: _openConcierge,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_TripTab> get _availableTabs {
    if (widget.includeUpcomingTab) {
      return const [_TripTab.upcoming, _TripTab.processing, _TripTab.history];
    }

    return const [_TripTab.processing, _TripTab.history];
  }

  String get _activeTabLabel => _tabLabel(_activeTab);
  List<Map<String, dynamic>> _filterRequests(
    List<Map<String, dynamic>> requests,
  ) {
    final filtered =
        requests.where((request) {
          final status = _statusMeta(request);
          final departure = _departureDate(request);
          final isFuture =
              departure != null && departure.isAfter(DateTime.now());

          switch (_activeTab) {
            case _TripTab.upcoming:
              return !status.isClosed && isFuture;

            case _TripTab.processing:
              return !status.isClosed;

            case _TripTab.history:
              return status.isClosed ||
                  (departure != null && departure.isBefore(DateTime.now()));
          }
        }).toList();

    filtered.sort((a, b) {
      final firstDate = _departureDate(a);
      final secondDate = _departureDate(b);

      if (firstDate == null && secondDate == null) return 0;
      if (firstDate == null) return 1;
      if (secondDate == null) return -1;

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

  void _openConcierge() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ClientConciergeScreen()));
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
        builder: (_) => ClientAircraftDetailScreen(aircraft: aircraft),
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

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: kWhite,
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
                  Text(
                    _routeLabel(request),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: kBlack,
                      height: 1,
                      letterSpacing: -0.8,
                    ),
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
                      color: kSoft,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: kBorder),
                    ),
                    child: Text(
                      meta.nextAction,
                      style: const TextStyle(
                        color: kText,
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
                          onTap: _openConcierge,
                          filled: true,
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
                              meta.contractReady
                                  ? () => _handleOpenContract(request)
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SheetButton(
                          label: 'Pago',
                          icon: Icons.credit_card_rounded,
                          onTap:
                              meta.paymentReady
                                  ? () => _handleOpenPayment(request)
                                  : null,
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleOpenContract(Map<String, dynamic> request) {
    if (widget.onOpenContract != null) {
      widget.onOpenContract!(request);
      return;
    }

    _showActionMessage('Firma de contrato disponible pronto.');
  }

  void _handleOpenPayment(Map<String, dynamic> request) {
    if (widget.onOpenPayment != null) {
      widget.onOpenPayment!(request);
      return;
    }

    _showActionMessage('Checkout seguro disponible pronto.');
  }
}

enum _TripTab { upcoming, processing, history }

String _tabLabel(_TripTab tab) {
  switch (tab) {
    case _TripTab.upcoming:
      return 'Proximos';
    case _TripTab.processing:
      return 'En proceso';
    case _TripTab.history:
      return 'Historial';
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? kBlack : kWhite,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? kBlack : kBorder),
          boxShadow:
              active
                  ? const [
                    BoxShadow(
                      color: Color(0x16000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? kWhite : kText,
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
    final meta = _statusMeta(request);
    final imageUrl = _aircraftImageUrl(request, aircraftFleet);
    final aircraftName = _aircraftLabel(request);
    final capacity = _aircraftCapacityLabel(request);
    final category = _aircraftCategoryLabel(request);
    final supportLines = _workflowSupportLines(request, meta);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFAF7F1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E1D8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x144D3F1B),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
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
                        _requestCode(request).toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF8B6A24),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _routeLabel(request),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kBlack,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          height: 1.02,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(meta: meta),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  icon: Icons.calendar_month_rounded,
                  label: _departureCopy(request),
                ),
                _MetaChip(
                  icon: Icons.groups_rounded,
                  label: '${_passengerCount(request)} pasajeros',
                ),
                _MetaChip(icon: Icons.flight_rounded, label: aircraftName),
                if (_itinerarySegments(request).length > 1)
                  _MetaChip(
                    icon: Icons.route_rounded,
                    label: '${_itinerarySegments(request).length} tramos',
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _ProgressSummary(meta: meta),
            const SizedBox(height: 8),
            _ProgressSteps(meta: meta),
            const SizedBox(height: 10),
            _ExecutiveAircraftPanel(
              imageUrl: imageUrl,
              aircraftName: aircraftName,
              capacity: capacity,
              category: category,
              onOpenAircraft: onOpenAircraft,
            ),
            const SizedBox(height: 8),
            _NextStepPanel(lines: supportLines),
            _SegmentsPanel(segments: _itinerarySegments(request)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CardActionButton(
                  label: 'Contrato',
                  icon: Icons.description_outlined,
                  enabled: meta.contractReady,
                  onTap: onOpenContract,
                ),
                _CardActionButton(
                  label: 'Pago',
                  icon: Icons.credit_card_rounded,
                  enabled: meta.paymentReady,
                  onTap: onOpenPayment,
                ),
                _CardActionButton(
                  label: _flightActionLabel(meta),
                  icon: Icons.flight_takeoff_rounded,
                  enabled: meta.flightReady,
                  onTap: onTap,
                ),
                _CardActionButton(
                  label: 'Concierge',
                  icon: Icons.support_agent_rounded,
                  enabled: true,
                  filled: true,
                  onTap: onOpenConcierge,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
              fontSize: 11,
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
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EDE7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF625D55)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF625D55),
                fontSize: 11,
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
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (meta.progress.clamp(0, 100)) / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFEBE3D4),
              valueColor: const AlwaysStoppedAnimation<Color>(kBlack),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${meta.progress}%',
          style: const TextStyle(
            color: kBlack,
            fontSize: 12,
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
    final colors = switch (state) {
      _StepState.done => (const Color(0xFFE5F7EA), const Color(0xFF14673A)),
      _StepState.active => (const Color(0xFFFFF2D8), const Color(0xFF9A6500)),
      _StepState.todo => (const Color(0xFFF1EDE7), const Color(0xFF7A7266)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
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
              fontSize: 11,
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
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0E7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _AircraftHeroMedia(imageUrl: imageUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aircraftName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kBlack,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                if (capacity.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    capacity,
                    style: const TextStyle(
                      color: Color(0xFF625D55),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (category.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    category,
                    style: const TextStyle(
                      color: Color(0xFF625D55),
                      fontSize: 12,
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
            color: kBlack,
            visualDensity: VisualDensity.compact,
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
    final hasImage = imageUrl.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 86,
        height: 66,
        color: kBlack,
        child:
            hasImage
                ? Image.network(
                  imageUrl,
                  width: 86,
                  height: 66,
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
    return const Center(
      child: Text(
        'Jet privado',
        textAlign: TextAlign.center,
        style: TextStyle(color: kWhite, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _NextStepPanel extends StatelessWidget {
  const _NextStepPanel({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0E7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Siguiente paso',
            style: TextStyle(color: kBlack, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          for (final line in lines.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                line,
                style: const TextStyle(
                  color: Color(0xFF625D55),
                  fontSize: 12,
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

class _SegmentsPanel extends StatelessWidget {
  const _SegmentsPanel({required this.segments});

  final List<_ItinerarySegment> segments;

  @override
  Widget build(BuildContext context) {
    if (segments.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final segment in segments)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F0E7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Tramo ${segment.order} · ${segment.origin} -> ${segment.destination}',
                style: const TextStyle(
                  color: Color(0xFF433C31),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
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
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final background =
        filled ? kBlack : (enabled ? kWhite : const Color(0xFFF2EEE6));
    final foreground =
        filled ? kWhite : (enabled ? kBlack : const Color(0xFF8C8376));

    return SizedBox(
      height: 38,
      child: FilledButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 15),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: const Color(0xFFF2EEE6),
          disabledForegroundColor: const Color(0xFF8C8376),
          side: BorderSide(color: filled ? kBlack : const Color(0xFFDED6C8)),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
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
    final isConfirmed =
        meta.tone == _WorkflowTone.confirmed ||
        meta.tone == _WorkflowTone.completed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isConfirmed ? kBlack : kSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: isConfirmed ? kBlack : kBorder),
      ),
      child: Text(
        meta.label,
        style: TextStyle(
          color: isConfirmed ? kWhite : kBlack,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                color: kMuted,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: kBlack,
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
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: kBlack,
          foregroundColor: kWhite,
          disabledBackgroundColor: const Color(0xFFE5E5E5),
          disabledForegroundColor: const Color(0xFF999999),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      );
    }

    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: kBlack,
        disabledForegroundColor: const Color(0xFF999999),
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: kBorder),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(color: kBlack, strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            'Cargando vuelos...',
            style: TextStyle(color: kBlack, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _EmptyFlightsCard extends StatelessWidget {
  const _EmptyFlightsCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
      ),
      child: Text(
        'No hay viajes en ${label.toLowerCase()}.',
        style: const TextStyle(
          color: kText,
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      ),
    );
  }
}

_WorkflowMeta _statusMeta(Map<String, dynamic> request) {
  final workflow = _normalizedStatus(
    request['workflow_status'] ??
        request['status'] ??
        request['flight_status'] ??
        request['reservation_status'],
  );

  final contractStatus = _normalizedStatus(
    request['contract_status'] ??
        request['contract'] ??
        request['signature_status'],
  );

  final paymentStatus = _normalizedStatus(
    request['payment_status'] ??
        request['checkout_status'] ??
        request['payment'],
  );

  final providerStatus = _normalizedStatus(
    request['provider_status'] ??
        request['match_status'] ??
        request['supplier_status'],
  );

  final trackingStatus = _normalizedStatus(
    request['tracking_status'] ??
        request['tracking'] ??
        request['monitoring_status'],
  );

  final providerConfirmed =
      _containsAny(providerStatus, const [
        'accepted',
        'approved',
        'confirmed',
      ]) ||
      _containsAny(workflow, const [
        'provider accepted',
        'provider_accepted',
        'accepted',
        'approved',
        'matched',
        'confirmado',
      ]) ||
      _hasValue(request['provider_id']) ||
      _hasValue(request['assigned_aircraft_id']) ||
      _hasValue(request['assigned_provider_id']);

  final contractReady =
      _containsAny(contractStatus, const ['signed', 'completed', 'approved']) ||
      _asBool(
        request['contract_signed'] ??
            request['contract_completed'] ??
            request['contract_ready'],
      ) ||
      _hasValue(request['contract_url']) ||
      _hasValue(request['contract_document_url']);

  final paymentReady =
      _containsAny(paymentStatus, const ['paid', 'completed', 'confirmed']) ||
      _asBool(request['payment_completed'] ?? request['is_paid']) ||
      _hasValue(request['payment_reference']);

  final flightReady =
      _containsAny(workflow, const [
        'flight confirmed',
        'scheduled',
        'boarding',
        'departed',
        'airborne',
      ]) ||
      _containsAny(_normalizedStatus(request['flight_status']), const [
        'confirmed',
        'scheduled',
        'boarding',
        'departed',
        'airborne',
      ]);

  final trackingReady =
      _containsAny(trackingStatus, const ['active', 'live', 'enabled']) ||
      _containsAny(workflow, const ['tracking']) ||
      _hasValue(request['tracking_url']) ||
      _hasValue(request['live_tracking_url']);

  if (workflow.contains('completed')) {
    return const _WorkflowMeta(
      label: 'Vuelo completado',
      tone: _WorkflowTone.completed,
      progress: 100,
      activeStep: 5,
      nextAction: 'Reserva cerrada correctamente.',
      isClosed: true,
      providerConfirmed: true,
      contractReady: true,
      paymentReady: true,
      flightReady: true,
      trackingReady: true,
    );
  }

  if (workflow.contains('cancel') || workflow.contains('rejected')) {
    return const _WorkflowMeta(
      label: 'Reserva cerrada',
      tone: _WorkflowTone.cancelled,
      progress: 100,
      activeStep: 5,
      nextAction: 'Reserva sin seguimiento activo.',
      isClosed: true,
      providerConfirmed: false,
      contractReady: false,
      paymentReady: false,
      flightReady: false,
      trackingReady: false,
    );
  }

  if (trackingReady) {
    return const _WorkflowMeta(
      label: 'Tracking activo',
      tone: _WorkflowTone.confirmed,
      progress: 90,
      activeStep: 5,
      nextAction:
          'Monitorea terminal, tripulación y seguimiento en tiempo real.',
      isClosed: false,
      providerConfirmed: true,
      contractReady: true,
      paymentReady: true,
      flightReady: true,
      trackingReady: true,
    );
  }

  if (flightReady) {
    return const _WorkflowMeta(
      label: 'Vuelo confirmado',
      tone: _WorkflowTone.confirmed,
      progress: 82,
      activeStep: 4,
      nextAction: 'Todo listo para la operación del vuelo.',
      isClosed: false,
      providerConfirmed: true,
      contractReady: true,
      paymentReady: true,
      flightReady: true,
      trackingReady: false,
    );
  }

  if (paymentReady) {
    return const _WorkflowMeta(
      label: 'Pago confirmado',
      tone: _WorkflowTone.confirmed,
      progress: 74,
      activeStep: 3,
      nextAction: 'Pago validado. Estamos preparando la salida.',
      isClosed: false,
      providerConfirmed: true,
      contractReady: true,
      paymentReady: true,
      flightReady: false,
      trackingReady: false,
    );
  }

  if (_containsAny(paymentStatus, const [
    'pending',
    'processing',
    'awaiting',
  ])) {
    return const _WorkflowMeta(
      label: 'Pago en curso',
      tone: _WorkflowTone.pending,
      progress: 66,
      activeStep: 3,
      nextAction: 'Completa el pago para confirmar la operación.',
      isClosed: false,
      providerConfirmed: true,
      contractReady: true,
      paymentReady: true,
      flightReady: false,
      trackingReady: false,
    );
  }

  if (contractReady) {
    return const _WorkflowMeta(
      label: 'Contrato firmado',
      tone: _WorkflowTone.pending,
      progress: 58,
      activeStep: 2,
      nextAction: 'Contrato listo. El siguiente paso es el pago.',
      isClosed: false,
      providerConfirmed: true,
      contractReady: true,
      paymentReady: false,
      flightReady: false,
      trackingReady: false,
    );
  }

  if (_containsAny(contractStatus, const ['pending', 'sent', 'awaiting'])) {
    return const _WorkflowMeta(
      label: 'Contrato pendiente',
      tone: _WorkflowTone.pending,
      progress: 50,
      activeStep: 2,
      nextAction: 'Siguiente paso: firma de contrato.',
      isClosed: false,
      providerConfirmed: true,
      contractReady: true,
      paymentReady: false,
      flightReady: false,
      trackingReady: false,
    );
  }

  if (providerConfirmed) {
    return _WorkflowMeta(
      label: 'Proveedor confirmado',
      tone: _WorkflowTone.confirmed,
      progress: 42,
      activeStep: 1,
      nextAction: _providerNextAction(request),
      isClosed: false,
      providerConfirmed: true,
      contractReady: true,
      paymentReady: false,
      flightReady: false,
      trackingReady: false,
    );
  }

  if (workflow.contains('search') ||
      workflow.contains('pending') ||
      workflow.contains('matching') ||
      workflow.contains('validacion')) {
    return const _WorkflowMeta(
      label: 'En curso',
      tone: _WorkflowTone.searching,
      progress: 28,
      activeStep: 0,
      nextAction: 'Estamos validando proveedor y disponibilidad.',
      isClosed: false,
      providerConfirmed: false,
      contractReady: false,
      paymentReady: false,
      flightReady: false,
      trackingReady: false,
    );
  }

  return const _WorkflowMeta(
    label: 'Reserva activa',
    tone: _WorkflowTone.info,
    progress: 16,
    activeStep: 0,
    nextAction: 'La reserva ya está registrada.',
    isClosed: false,
    providerConfirmed: false,
    contractReady: false,
    paymentReady: false,
    flightReady: false,
    trackingReady: false,
  );
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

String _flightActionLabel(_WorkflowMeta meta) {
  if (meta.tone == _WorkflowTone.completed) return 'Buen viaje';
  if (meta.trackingReady) return 'Tracking';
  if (meta.flightReady) return 'Vuelo listo';
  if (meta.paymentReady) return 'Liberacion';
  return 'Vuelo';
}

List<String> _workflowSupportLines(
  Map<String, dynamic> request,
  _WorkflowMeta meta,
) {
  final lines = <String>[meta.nextAction];
  final package = request['flight_package']?.toString().trim() ?? '';
  final operator =
      request['operator']?.toString().trim().isNotEmpty == true
          ? request['operator'].toString().trim()
          : request['provider_name']?.toString().trim() ?? '';

  if (package.isNotEmpty) lines.add('Paquete: $package');
  if (meta.contractReady && !meta.paymentReady) {
    lines.add('Contrato en gestion');
  } else if (meta.paymentReady && !meta.flightReady) {
    lines.add('Pago en proceso operativo');
  } else if (meta.flightReady || meta.trackingReady) {
    lines.add('Operacion en liberacion final');
  }
  if (operator.isNotEmpty) lines.add('Operado por: $operator');
  lines.add('Concierge 24/7 disponible');

  return lines;
}

String _requestCode(Map<String, dynamic> request) {
  final id = request['id']?.toString() ?? '0000';
  return 'RESERVA SKY-$id';
}

String _providerNextAction(Map<String, dynamic> request) {
  final providerName =
      request['provider_name']?.toString() ??
      _nestedText(request['provider'], 'name') ??
      _nestedText(request['provider'], 'company_name');

  if (providerName != null && providerName.isNotEmpty) {
    return 'Proveedor confirmado: $providerName. Siguiente paso: contrato.';
  }

  return 'El proveedor ya fue confirmado. Siguiente paso: contrato.';
}

String _normalizedStatus(dynamic value) {
  return value?.toString().trim().toLowerCase() ?? '';
}

bool _containsAny(String value, List<String> patterns) {
  for (final pattern in patterns) {
    if (value.contains(pattern)) return true;
  }

  return false;
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
  final legs = request['legs'] ?? request['segments'] ?? request['routes'];

  if (legs is List && legs.isNotEmpty) {
    final first = legs.first;

    if (first is Map) {
      final origin = first['origin']?.toString() ?? '';
      final destination = first['destination']?.toString() ?? '';

      if (origin.isNotEmpty || destination.isNotEmpty) {
        return '$origin → $destination';
      }
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

String _aircraftCapacityLabel(Map<String, dynamic> request) {
  final value =
      request['aircraft_capacity'] ??
      request['capacity'] ??
      request['passengers'] ??
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
  final raw = value.trim();
  if (raw.isEmpty) return '';
  final lower = raw.toLowerCase();
  if (lower.startsWith('blob:') ||
      lower.startsWith('data:') ||
      lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      raw.startsWith('//')) {
    return raw;
  }

  if (raw.startsWith('/') && !raw.startsWith('/storage')) return raw;

  final origin = ApiClient.instance.backendOrigin;
  final cleanPath = raw.replaceFirst(RegExp(r'^\.?/'), '');
  if (origin.isEmpty) return '/$cleanPath';
  return '$origin/$cleanPath';
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

String _normalizeLookup(dynamic value) {
  return value?.toString().trim().toLowerCase().replaceAll(
        RegExp(r'[_\-\s]+'),
        ' ',
      ) ??
      '';
}
