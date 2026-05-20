import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/aircraft.dart';
import '../../../providers/reservation_provider.dart';
import '../widgets/client_experience_widgets.dart';
import 'client_aircraft_detail_screen.dart';
import 'client_concierge_screen.dart';

class ClientHistoryScreen extends StatefulWidget {
  const ClientHistoryScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<ClientHistoryScreen> createState() => _ClientHistoryScreenState();
}

class _ClientHistoryScreenState extends State<ClientHistoryScreen> {
  _TripTab _activeTab = _TripTab.processing;

  @override
  void initState() {
    super.initState();
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
    final highlightedRequest =
        filteredRequests.isNotEmpty ? filteredRequests.first : null;
    final secondaryRequests =
        filteredRequests.length > 1 ? filteredRequests.sublist(1) : const [];

    return ClientExperienceShell(
      title: 'Mis vuelos',
      subtitle: 'Activos, proximos e historial en un solo lugar.',
      showBackButton: widget.showBackButton,
      trailing: StatusBadge(
        label: '${allRequests.length} vuelos',
        color: const Color(0xFF143955),
      ),
      child: RefreshIndicator(
        onRefresh: () => provider.loadClientWorkspaceData(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const Text(
              'Activos, proximos e historial\nen un solo lugar.',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111111),
                height: 0.98,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tu experiencia de vuelo privado, pagos y seguimiento viven dentro de cada reserva.',
              style: TextStyle(
                color: Color(0xFF625D55),
                fontSize: 16,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _TripTabButton(
                  label: 'Proximos',
                  active: _activeTab == _TripTab.upcoming,
                  onTap: () => setState(() => _activeTab = _TripTab.upcoming),
                ),
                _TripTabButton(
                  label: 'En proceso',
                  active: _activeTab == _TripTab.processing,
                  onTap: () => setState(() => _activeTab = _TripTab.processing),
                ),
                _TripTabButton(
                  label: 'Historial',
                  active: _activeTab == _TripTab.history,
                  onTap: () => setState(() => _activeTab = _TripTab.history),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (provider.isLoadingWorkspace && allRequests.isEmpty)
              const GlassInfoCard(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredRequests.isEmpty)
              GlassInfoCard(
                child: Text(
                  'No hay viajes en ${_activeTabLabel.toLowerCase()}.',
                  style: const TextStyle(
                    color: Color(0xFF3B3428),
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              )
            else ...[
              if (highlightedRequest != null)
                _FlightExecutiveCard(
                  request: highlightedRequest,
                  onOpenConcierge: _openConcierge,
                  onOpenAircraft:
                      () => _openAircraft(provider, highlightedRequest),
                  onOpenContract:
                      () => _showActionMessage(
                        'Firma de contrato disponible pronto.',
                      ),
                  onOpenPayment:
                      () => _showActionMessage(
                        'Checkout seguro disponible pronto.',
                      ),
                ),
              if (secondaryRequests.isNotEmpty) ...[
                const SizedBox(height: 16),
                const ClientSectionTitle(
                  title: 'Mas vuelos',
                  subtitle:
                      'Acceso rapido a otras reservas del mismo historial.',
                ),
                const SizedBox(height: 14),
                ...secondaryRequests.map(
                  (request) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FlightSummaryCard(
                      request: request,
                      onTap: () => _showFlightSheet(provider, request),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String get _activeTabLabel {
    switch (_activeTab) {
      case _TripTab.upcoming:
        return 'Proximos';
      case _TripTab.processing:
        return 'En proceso';
      case _TripTab.history:
        return 'Historial';
    }
  }

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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (_) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _routeLabel(request),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMeta(request).nextAction,
                  style: const TextStyle(
                    color: Color(0xFF625D55),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _openConcierge,
                        child: const Text('Concierge'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openAircraft(provider, request),
                        child: const Text('Ver aeronave'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  void _showActionMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _TripTab { upcoming, processing, history }

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
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF111111) : const Color(0xFFF0E9DE),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF1F1B18),
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _FlightExecutiveCard extends StatelessWidget {
  const _FlightExecutiveCard({
    required this.request,
    required this.onOpenConcierge,
    required this.onOpenAircraft,
    required this.onOpenContract,
    required this.onOpenPayment,
  });

  final Map<String, dynamic> request;
  final VoidCallback onOpenConcierge;
  final VoidCallback onOpenAircraft;
  final VoidCallback onOpenContract;
  final VoidCallback onOpenPayment;

  @override
  Widget build(BuildContext context) {
    final meta = _statusMeta(request);
    final route = _routeLabel(request);
    final aircraft = _aircraftLabel(request);
    final departure = _departureCopy(request);
    final passengers = _passengerCount(request);
    final totalSegments = _segments(request).length;

    return GlassInfoCard(
      padding: const EdgeInsets.all(20),
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
                      _requestCode(request),
                      style: const TextStyle(
                        color: Color(0xFF9A6F28),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.08,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      route,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111111),
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _MetaText(label: departure),
                        _MetaText(label: '$passengers pasajeros'),
                        _MetaText(label: aircraft),
                        _MetaText(label: '$totalSegments tramos'),
                        _MetaText(label: meta.label),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _WorkflowStatusBadge(meta: meta),
            ],
          ),
          const SizedBox(height: 18),
          _ProgressRow(meta: meta),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: _steps(meta)),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 640;
              final aircraftCard = _ExecutiveInfoCard(
                mediaUrl: _aircraftImage(request),
                title: aircraft,
                lines: [
                  'Capacidad: ${_aircraftCapacity(request)} pax',
                  'Cabina: ${_aircraftCategory(request)}',
                  'Servicios: ${_amenities(request)}',
                ],
              );
              final nextStepCard = _NextStepCard(
                title: 'Proximo paso',
                lines: [
                  meta.nextAction,
                  _paymentLabel(request),
                  'Concierge 24/7 disponible',
                ],
              );

              if (stacked) {
                return Column(
                  children: [
                    aircraftCard,
                    const SizedBox(height: 12),
                    nextStepCard,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: aircraftCard),
                  const SizedBox(width: 12),
                  Expanded(child: nextStepCard),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _segments(
                  request,
                ).map((segment) => _LegPill(label: segment)).toList(),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionButton(
                label: 'Contrato',
                icon: Icons.description_outlined,
                onTap: meta.contractReady ? onOpenContract : null,
              ),
              _ActionButton(
                label: 'Pago',
                icon: Icons.credit_card_rounded,
                onTap: meta.paymentReady ? onOpenPayment : null,
              ),
              _ActionButton(
                label: 'Concierge',
                icon: Icons.support_agent_rounded,
                onTap: onOpenConcierge,
              ),
              _ActionButton(
                label: 'Ver aeronave',
                icon: Icons.flight_rounded,
                onTap: onOpenAircraft,
                emphasized: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlightSummaryCard extends StatelessWidget {
  const _FlightSummaryCard({required this.request, required this.onTap});

  final Map<String, dynamic> request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = _statusMeta(request);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5E1D8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _routeLabel(request),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _departureCopy(request),
                    style: const TextStyle(color: Color(0xFF625D55)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _aircraftLabel(request),
                    style: const TextStyle(
                      color: Color(0xFF9A6F28),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _WorkflowStatusBadge(meta: meta, compact: true),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.meta});

  final _WorkflowMeta meta;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFEBE3D4),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: meta.progress / 100,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF111111), Color(0xFF9A6F28)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${meta.progress}%',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111111),
          ),
        ),
      ],
    );
  }
}

class _WorkflowStatusBadge extends StatelessWidget {
  const _WorkflowStatusBadge({required this.meta, this.compact = false});

  final _WorkflowMeta meta;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (meta.tone) {
      _WorkflowTone.searching => (
        const Color(0xFFE8F1FF),
        const Color(0xFF2351A8),
        '🌀',
      ),
      _WorkflowTone.info => (
        const Color(0xFFEEF4FF),
        const Color(0xFF355DA8),
        '●',
      ),
      _WorkflowTone.pending => (
        const Color(0xFFFFF2D8),
        const Color(0xFF9A6500),
        '◔',
      ),
      _WorkflowTone.confirmed => (
        const Color(0xFFE5F7EA),
        const Color(0xFF14673A),
        '✅',
      ),
      _WorkflowTone.completed => (
        const Color(0xFFDDF7E6),
        const Color(0xFF0D6A34),
        '✓',
      ),
      _WorkflowTone.cancelled => (
        const Color(0xFFFFE6E2),
        const Color(0xFFA13622),
        '✕',
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$icon ${meta.label}',
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 12 : 14,
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF625D55),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ExecutiveInfoCard extends StatelessWidget {
  const _ExecutiveInfoCard({
    required this.title,
    required this.lines,
    this.mediaUrl,
  });

  final String title;
  final List<String> lines;
  final String? mediaUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0E7),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 110,
              height: 110,
              child:
                  mediaUrl != null && mediaUrl!.isNotEmpty
                      ? Image.network(
                        mediaUrl!,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => _PlaceholderMedia(label: title),
                      )
                      : _PlaceholderMedia(label: title),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 8),
                ...lines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: const TextStyle(
                        color: Color(0xFF625D55),
                        height: 1.3,
                      ),
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

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0E7),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 10),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: const TextStyle(color: Color(0xFF625D55), height: 1.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegPill extends StatelessWidget {
  const _LegPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0E7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: const TextStyle(color: Color(0xFF433C31))),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final child =
        emphasized
            ? FilledButton.icon(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(icon, size: 18),
              label: Text(label),
            )
            : OutlinedButton.icon(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF111111),
                minimumSize: const Size(0, 50),
                side: const BorderSide(color: Color(0xFFDED6C8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(icon, size: 18),
              label: Text(label),
            );

    return child;
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (state) {
      _StepState.done => (
        const Color(0xFFE5F7EA),
        const Color(0xFF14673A),
        '✓',
      ),
      _StepState.active => (
        const Color(0xFFFFF2D8),
        const Color(0xFF9A6500),
        '●',
      ),
      _StepState.todo => (
        const Color(0xFFF1EDE7),
        const Color(0xFF7A7266),
        '○',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$icon $label',
        style: TextStyle(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

enum _StepState { done, active, todo }

List<Widget> _steps(_WorkflowMeta meta) {
  final states = <String, _StepState>{
    'Reserva': _StepState.done,
    'Respuesta proveedor':
        meta.providerConfirmed ? _StepState.done : _StepState.todo,
    'Contrato': meta.contractReady ? _StepState.done : _StepState.todo,
    'Pago': meta.paymentReady ? _StepState.done : _StepState.todo,
    'Vuelo': meta.flightReady ? _StepState.done : _StepState.todo,
    'Tracking': meta.trackingReady ? _StepState.done : _StepState.todo,
  };

  if (!meta.providerConfirmed) {
    states['Respuesta proveedor'] = _StepState.active;
  } else if (!meta.contractReady) {
    states['Contrato'] = _StepState.active;
  } else if (!meta.paymentReady) {
    states['Pago'] = _StepState.active;
  } else if (!meta.flightReady) {
    states['Vuelo'] = _StepState.active;
  } else if (!meta.trackingReady) {
    states['Tracking'] = _StepState.active;
  }

  return states.entries
      .map((entry) => _StepPill(label: entry.key, state: entry.value))
      .toList();
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
          'Monitorea terminal, tripulacion y seguimiento en tiempo real.',
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
      nextAction: 'Todo listo para la operacion del vuelo.',
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
      nextAction: 'Completa el pago para confirmar la operacion.',
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
    nextAction: 'La reserva ya esta registrada.',
    isClosed: false,
    providerConfirmed: false,
    contractReady: false,
    paymentReady: false,
    flightReady: false,
    trackingReady: false,
  );
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
        return '$origin -> $destination';
      }
    }
  }

  final origin = request['origin']?.toString() ?? '';
  final destination = request['destination']?.toString() ?? '';
  if (origin.isNotEmpty || destination.isNotEmpty) {
    return '$origin -> $destination';
  }

  return 'Ruta por confirmar';
}

String _departureCopy(Map<String, dynamic> request) {
  final raw =
      request['departure_datetime']?.toString() ??
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
      _nestedText(request['assigned_aircraft'], 'model') ??
      _nestedText(request['aircraft_data'], 'model') ??
      'Aeronave por asignar';
}

String _aircraftCategory(Map<String, dynamic> request) {
  return request['aircraft_category']?.toString() ??
      _nestedText(request['assigned_aircraft'], 'aircraft_type') ??
      request['cabin']?.toString() ??
      'Jet privado';
}

String _aircraftCapacity(Map<String, dynamic> request) {
  return request['aircraft_capacity']?.toString() ??
      request['capacity']?.toString() ??
      _nestedText(request['assigned_aircraft'], 'capacity') ??
      'N/D';
}

String _amenities(Map<String, dynamic> request) {
  final amenities =
      request['amenities'] ?? request['services'] ?? request['service_items'];
  if (amenities is List && amenities.isNotEmpty) {
    return amenities.take(3).map((item) => item.toString()).join(' • ');
  }
  if (amenities is String && amenities.trim().isNotEmpty) {
    return amenities.trim();
  }
  return 'Concierge, privacidad y soporte premium';
}

String? _aircraftImage(Map<String, dynamic> request) {
  final direct = [
    request['aircraft_image'],
    request['image_url'],
    request['main_image'],
  ];
  for (final item in direct) {
    final value = item?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return null;
}

List<String> _segments(Map<String, dynamic> request) {
  final legs = request['legs'] ?? request['segments'] ?? request['routes'];
  if (legs is List && legs.isNotEmpty) {
    final result = <String>[];
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      if (leg is! Map) continue;
      final origin = leg['origin']?.toString() ?? '';
      final destination = leg['destination']?.toString() ?? '';
      final departure = leg['departure_datetime']?.toString() ?? '';
      final dateText =
          departure.isEmpty
              ? ''
              : ' · ${_departureCopy({'departure_datetime': departure})}';
      result.add('Tramo ${i + 1} · $origin -> $destination$dateText');
    }
    if (result.isNotEmpty) return result;
  }

  return [_routeLabel(request)];
}

String _paymentLabel(Map<String, dynamic> request) {
  final payment =
      request['payment_status']?.toString() ??
      request['checkout_status']?.toString() ??
      '';
  final reference =
      request['payment_reference']?.toString() ??
      request['payment_intent']?.toString() ??
      '';
  if (payment.isEmpty && reference.isEmpty) {
    return 'Pago segun etapa comercial de la reserva';
  }
  if (reference.isNotEmpty) {
    return 'Pago: $payment · Ref. $reference';
  }
  return 'Pago: $payment';
}

class _PlaceholderMedia extends StatelessWidget {
  const _PlaceholderMedia({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1F1B18),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
