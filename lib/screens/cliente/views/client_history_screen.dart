import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/aircraft.dart';
import '../../../providers/reservation_provider.dart';
import '../widgets/client_experience_widgets.dart';
import 'client_aircraft_detail_screen.dart';
import 'client_concierge_screen.dart';

const Color kBg = Color(0xFFF7F7F7);
const Color kWhite = Colors.white;
const Color kBlack = Color(0xFF050505);
const Color kText = Color(0xFF111111);
const Color kMuted = Color(0xFF666666);
const Color kBorder = Color(0xFFE6E6E6);
const Color kSoft = Color(0xFFF2F2F2);

class ClientHistoryScreen extends StatefulWidget {
  const ClientHistoryScreen({
    super.key,
    this.showBackButton = true,
    this.onOpenContract,
    this.onOpenPayment,
  });

  final bool showBackButton;
  final ValueChanged<Map<String, dynamic>>? onOpenContract;
  final ValueChanged<Map<String, dynamic>>? onOpenPayment;

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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const Text(
              'Tus vuelos',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: kBlack,
                height: 1,
                letterSpacing: -1.1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Consulta tus reservas de forma simple.',
              style: TextStyle(
                color: kMuted,
                fontSize: 16,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _TripTabButton(
                  label: 'Próximos',
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
              const _MinimalLoadingCard()
            else if (filteredRequests.isEmpty)
              _EmptyFlightsCard(label: _activeTabLabel)
            else
              ...filteredRequests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MinimalFlightCard(
                    request: request,
                    onTap: () => _showFlightSheet(provider, request),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String get _activeTabLabel {
    switch (_activeTab) {
      case _TripTab.upcoming:
        return 'Próximos';
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
  final meta = _statusMeta(request);

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: kWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (_) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return SafeArea(
            top: false,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  _routeLabel(request),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: kBlack,
                    height: 1,
                    letterSpacing: -0.8,
                  ),
                ),

                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerLeft,
                  child: _MinimalStatusPill(meta: meta),
                ),

                const SizedBox(height: 18),

                _DetailRow(
                  label: 'Fecha',
                  value: _departureCopy(request),
                ),
                _DetailRow(
                  label: 'Aeronave',
                  value: _aircraftLabel(request),
                ),
                _DetailRow(
                  label: 'Pasajeros',
                  value: '${_passengerCount(request)} pasajeros',
                ),
                _DetailRow(
                  label: 'Reserva',
                  value: _requestCode(request),
                ),

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
          );
        },
      );
    },
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
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: active ? kBlack : kWhite,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? kBlack : kBorder,
          ),
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
            fontSize: 14,
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
    required this.onTap,
  });

  final Map<String, dynamic> request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = _statusMeta(request);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: kBlack,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.flight_takeoff_rounded,
                color: kWhite,
                size: 21,
              ),
            ),
            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _routeLabel(request),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kBlack,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _departureCopy(request),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _aircraftLabel(request),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kText,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MiniDotStatus(meta: meta),
                const SizedBox(height: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: kBlack,
                  size: 24,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniDotStatus extends StatelessWidget {
  const _MiniDotStatus({required this.meta});

  final _WorkflowMeta meta;

  @override
  Widget build(BuildContext context) {
    final isConfirmed =
        meta.tone == _WorkflowTone.confirmed ||
        meta.tone == _WorkflowTone.completed;

    final isCancelled = meta.tone == _WorkflowTone.cancelled;

    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color:
            isConfirmed
                ? kBlack
                : isCancelled
                    ? const Color(0xFF9A9A9A)
                    : kWhite,
        shape: BoxShape.circle,
        border: Border.all(color: kBlack, width: 1.4),
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
        border: Border.all(
          color: isConfirmed ? kBlack : kBorder,
        ),
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
  const _DetailRow({
    required this.label,
    required this.value,
  });

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
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: kBlack,
        disabledForegroundColor: const Color(0xFF999999),
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: kBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
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
            child: CircularProgressIndicator(
              color: kBlack,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Cargando vuelos...',
            style: TextStyle(
              color: kBlack,
              fontWeight: FontWeight.w900,
            ),
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