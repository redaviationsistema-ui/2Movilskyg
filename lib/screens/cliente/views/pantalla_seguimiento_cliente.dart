import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/cliente_api.dart';
import '../../../models/client_operation_tracking.dart';
import '../../../models/flight_brief.dart';
import '../../../core/media_utils.dart';
import '../presentation/tracking_presentation.dart';

typedef OperationTrackingLoader =
    Future<ClientOperationTracking> Function(String operationId);

class ClientTrackingScreen extends StatefulWidget {
  const ClientTrackingScreen({
    super.key,
    this.operationId,
    this.loader,
    this.flightRequest,
    this.aircraftName = '',
    this.aircraftImageUrl = '',
  });

  final String? operationId;
  final OperationTrackingLoader? loader;
  final Map<String, dynamic>? flightRequest;
  final String aircraftName;
  final String aircraftImageUrl;

  @override
  State<ClientTrackingScreen> createState() => _ClientTrackingScreenState();
}

class _ClientTrackingScreenState extends State<ClientTrackingScreen>
    with WidgetsBindingObserver {
  static const _refreshInterval = Duration(seconds: 20);

  Timer? _refreshTimer;
  ClientOperationTracking? _tracking;
  Object? _error;
  String? _refreshMessage;
  bool _loading = true;
  String? _activeOperationId;
  int _requestVersion = 0;

  OperationTrackingLoader get _loader =>
      widget.loader ?? ApiClient.instance.getOperationTracking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startRefreshTimer();
    _load();
  }

  @override
  void didUpdateWidget(covariant ClientTrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.operationId == widget.operationId) return;
    _requestVersion++;
    _tracking = null;
    _error = null;
    _refreshMessage = null;
    _loading = true;
    _startRefreshTimer();
    _load();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      _refreshInterval,
      (_) => _load(refresh: true),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(refresh: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    final operationId = widget.operationId?.trim() ?? '';
    if (operationId.isEmpty) {
      _refreshTimer?.cancel();
      if (mounted) {
        setState(() {
          _loading = false;
          _error = const ApiException(
            'Selecciona un vuelo para consultar su seguimiento.',
          );
        });
      }
      return;
    }
    if (_activeOperationId == operationId) return;

    final version = ++_requestVersion;
    _activeOperationId = operationId;
    if (!refresh && mounted) {
      setState(() {
        _loading = _tracking == null;
        _error = null;
      });
    }
    try {
      final tracking = await _loader(operationId);
      if (tracking.operationId != operationId) {
        throw const ApiException(
          'La operación recibida no corresponde al vuelo seleccionado.',
        );
      }
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _tracking = tracking;
        _loading = false;
        _error = null;
        _refreshMessage = null;
      });
      if (ClientTrackingStatus.fromValue(tracking.status).terminal) {
        _refreshTimer?.cancel();
      } else if (_refreshTimer?.isActive != true) {
        _startRefreshTimer();
      }
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _loading = false;
        if (error is ApiException &&
            const [401, 403, 404].contains(error.statusCode)) {
          _tracking = null;
          _refreshTimer?.cancel();
        }
        if (_tracking == null) {
          _error = error;
        } else {
          _refreshMessage = 'No pudimos actualizar el seguimiento.';
        }
      });
    } finally {
      if (_activeOperationId == operationId) _activeOperationId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = _tracking;
    final events =
        tracking == null
            ? const <ClientOperationTimelineEvent>[]
            : trackingVisibleEvents(tracking);
    final status =
        tracking == null
            ? null
            : TrackingStatusPresentation.fromTracking(
              tracking,
              visibleEvents: events,
            );
    final contextMatches = _matchesOperation(
      widget.flightRequest,
      widget.operationId,
    );
    final flightRequest = contextMatches ? widget.flightRequest : null;
    final releaseAircraft = trackingReleaseAircraftLabel(events);
    final aircraftName =
        releaseAircraft.isNotEmpty
            ? releaseAircraft
            : contextMatches
            ? widget.aircraftName
            : '';
    String normalizedAircraft(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final aircraftMatches =
        releaseAircraft.isEmpty ||
        normalizedAircraft(releaseAircraft) ==
            normalizedAircraft(widget.aircraftName);

    return Scaffold(
      backgroundColor: _trackingBg,
      appBar: AppBar(
        backgroundColor: _trackingBg,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        toolbarHeight:
            MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 124 : 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seguimiento operacional',
              maxLines: 2,
              style: TextStyle(
                color: Color.fromARGB(255, 243, 243, 243),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (tracking?.operationId.isNotEmpty == true)
              Text(
                'OPERACIÓN #${tracking!.operationId}',
                style: const TextStyle(
                  color: _trackingGold,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
          ],
        ),
      ),
      body:
          _loading && tracking == null
              ? const Center(
                child: CircularProgressIndicator(color: _trackingGold),
              )
              : _error != null && tracking == null
              ? _TrackingError(
                onRetry: _load,
                message:
                    (widget.operationId?.trim().isEmpty ?? true)
                        ? 'Selecciona un vuelo desde Reservas para consultar su seguimiento.'
                        : _error is ApiException &&
                            const [
                              401,
                              403,
                              404,
                            ].contains((_error as ApiException).statusCode)
                        ? 'Esta operación no está disponible. Puedes regresar a Reservas para seleccionar otro vuelo.'
                        : 'No pudimos cargar el seguimiento de tu vuelo.',
              )
              : SafeArea(
                top: false,
                child: RefreshIndicator(
                  onRefresh: () => _load(refresh: true),
                  color: _trackingGold,
                  child: ListView.builder(
                    key: const ValueKey('operation-tracking-list'),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    itemCount: events.length + 2,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_refreshMessage != null) ...[
                              _TrackingWarning(message: _refreshMessage!),
                              TextButton(
                                onPressed: () => _load(refresh: true),
                                child: const Text('Reintentar'),
                              ),
                            ],
                            if (status != null)
                              _TrackingHero(
                                status: status,
                                imageUrl:
                                    contextMatches && aircraftMatches
                                        ? widget.aircraftImageUrl
                                        : '',
                              ),
                            _TrackingFlightSummary(
                              request: flightRequest,
                              aircraftName: aircraftName,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Text(
                                'ACTUALIZACIONES DEL VUELO',
                                style: _trackingEyebrow,
                              ),
                            ),
                            if (events.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 20),
                                child: Text(
                                  'Todavía no hay actualizaciones operativas disponibles.',
                                  style: TextStyle(color: _trackingMuted),
                                ),
                              ),
                          ],
                        );
                      }
                      if (index == events.length + 1) {
                        return _TrackingNextStep(status: status);
                      }
                      return _TimelineEvent(
                        event: events[index - 1],
                        isLast: index == events.length,
                      );
                    },
                  ),
                ),
              ),
    );
  }
}

class _TrackingError extends StatelessWidget {
  const _TrackingError({required this.onRetry, required this.message});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFF9FB9CB),
            size: 42,
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFF5F8FA)),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10314A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}

class _TrackingWarning extends StatelessWidget {
  const _TrackingWarning({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF3B311B),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      message,
      style: const TextStyle(
        color: Color(0xFFFFD56A),
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _TrackingHero extends StatelessWidget {
  const _TrackingHero({required this.status, required this.imageUrl});
  final TrackingStatusPresentation status;
  final String imageUrl;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF172D42), _trackingBg],
              ),
            ),
          ),
        ),
        if (resolveMediaUrl(imageUrl).isNotEmpty)
          Positioned.fill(
            child: Image.network(
              resolveMediaUrl(imageUrl),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0x66071321), Color(0xF5071321)],
              ),
            ),
          ),
        ),
        Container(
          constraints: const BoxConstraints(minHeight: 200),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ESTADO ACTUAL', style: _trackingEyebrow),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(Icons.circle, size: 9, color: _trackingGold),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      status.title,
                      style: const TextStyle(
                        color: _trackingWhite,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        height: 1.12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                status.description,
                style: const TextStyle(
                  color: Color(0xFFD7E0E8),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TrackingFlightSummary extends StatelessWidget {
  const _TrackingFlightSummary({
    required this.request,
    required this.aircraftName,
  });
  final Map<String, dynamic>? request;
  final String aircraftName;
  @override
  Widget build(BuildContext context) {
    final data = request ?? const <String, dynamic>{};
    final legs = FlightBrief.legsFromPayload(data);
    final first = legs.firstOrNull;
    final origin =
        first?.origin.code ??
        _textField(data, ['origin', 'source_origin', 'from']);
    final destination =
        first?.destination.code ??
        _textField(data, ['destination', 'source_destination', 'to']);
    final departure =
        first?.departureAt ??
        (first == null
            ? DateTime.tryParse(
              _textField(data, [
                'departure_datetime',
                'departure_at',
                'start_datetime',
              ]),
            )
            : null);
    final passengers = _textField(data, [
      'passengers',
      'passenger_count',
      'pax',
    ]);
    final model =
        aircraftName.isNotEmpty
            ? aircraftName
            : _textField(data, [
              'assigned_aircraft_model',
              'aircraft_model',
              'aircraft_name',
            ]);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1FFFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (legs.length > 1) ...[
            Text(
              'PRIMER TRAMO · ${legs.length} TRAMOS',
              style: _trackingEyebrow,
            ),
            const SizedBox(height: 12),
          ],
          if (origin.isNotEmpty || destination.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _TrackingAirport(
                    code: origin,
                    city:
                        first?.origin.city ?? _textField(data, ['origin_city']),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Icon(
                    Icons.flight_takeoff,
                    color: _trackingGold,
                    size: 22,
                  ),
                ),
                Expanded(
                  child: _TrackingAirport(
                    code: destination,
                    city:
                        first?.destination.city ??
                        _textField(data, ['destination_city']),
                    alignRight: true,
                  ),
                ),
              ],
            )
          else
            const Text(
              'Información del itinerario por confirmar.',
              style: TextStyle(color: _trackingMuted),
            ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TrackingFact(
                  icon: Icons.schedule,
                  label: 'SALIDA',
                  value:
                      departure == null
                          ? 'Por confirmar'
                          : _dateLabel(departure),
                ),
                _TrackingFact(
                  icon: Icons.people_outline,
                  label: 'PASAJEROS',
                  value:
                      int.tryParse(passengers) != null &&
                              int.parse(passengers) > 0
                          ? '$passengers pax'
                          : 'Por confirmar',
                ),
                _TrackingFact(
                  icon: Icons.flight_outlined,
                  label: 'AERONAVE',
                  value: model.isEmpty ? 'Por confirmar' : model,
                ),
              ],
            ),
          ),
          if (legs.length > 1)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              iconColor: _trackingGold,
              collapsedIconColor: _trackingGold,
              title: const Text(
                'Ver itinerario completo',
                style: TextStyle(color: _trackingMuted, fontSize: 12),
              ),
              children: [
                for (var index = 0; index < legs.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${'${index + 1}'.padLeft(2, '0')} · ${legs[index].origin.code} → ${legs[index].destination.code}\n${legs[index].departureAt == null ? 'Salida por confirmar' : _dateLabel(legs[index].departureAt!)}',
                        style: const TextStyle(
                          color: _trackingWhite,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TrackingAirport extends StatelessWidget {
  const _TrackingAirport({
    required this.code,
    required this.city,
    this.alignRight = false,
  });
  final String code;
  final String city;
  final bool alignRight;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment:
        alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(
        code.isEmpty ? 'Por confirmar' : code,
        style: const TextStyle(
          color: _trackingWhite,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (city.isNotEmpty)
        Text(city, style: const TextStyle(color: _trackingMuted, fontSize: 12)),
    ],
  );
}

class _TrackingFact extends StatelessWidget {
  const _TrackingFact({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 250),
    margin: const EdgeInsets.only(right: 16),
    padding: const EdgeInsets.only(right: 16),
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: Color(0x1FFFFFFF))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _trackingGold, size: 14),
            const SizedBox(width: 5),
            Flexible(child: Text(label, style: _trackingEyebrow)),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(color: _trackingWhite, fontSize: 12),
        ),
      ],
    ),
  );
}

class _TimelineEvent extends StatelessWidget {
  const _TimelineEvent({required this.event, required this.isLast});
  final ClientOperationTimelineEvent event;
  final bool isLast;
  @override
  Widget build(BuildContext context) {
    final label = trackingEventLabel(event);
    final description = trackingEventDescription(event);
    final confirmed = const [
      'Listo para operar',
      'Confirmado',
      'Aeronave confirmada',
      'Tripulación confirmada',
      'Finalizado',
      'Completado',
    ].contains(label);
    final color = confirmed ? _trackingGold : _trackingMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                confirmed ? Icons.check_circle_outline : Icons.circle_outlined,
                size: 17,
                color: color,
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: 72,
                  margin: const EdgeInsets.only(top: 6),
                  color: const Color(0x26FFFFFF),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.createdAt != null)
                  Text(
                    _dateLabel(event.createdAt!),
                    style: const TextStyle(color: _trackingMuted, fontSize: 11),
                  ),
                const SizedBox(height: 5),
                Text(
                  trackingEventTitle(event),
                  style: const TextStyle(
                    color: _trackingWhite,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      color: _trackingMuted,
                      height: 1.4,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Estado de la actualización: $label',
                  style: TextStyle(color: color, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingNextStep extends StatelessWidget {
  const _TrackingNextStep({required this.status});
  final TrackingStatusPresentation? status;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF102235),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x55D6B477)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: _trackingGold, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PRÓXIMO PASO', style: _trackingEyebrow),
              const SizedBox(height: 8),
              Text(
                status?.nextDescription ??
                    'Nuestro equipo compartirá la próxima actualización cuando esté disponible.',
                style: const TextStyle(color: _trackingMuted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// Kept for the existing Flight Brief drawer; the same conservative vocabulary
// is used on both entry points without changing the backend's status codes.
class ClientTrackingStatus {
  const ClientTrackingStatus(
    this.title,
    this.description, {
    this.terminal = false,
  });
  final String title;
  final String description;
  final bool terminal;
  factory ClientTrackingStatus.fromValue(String value) {
    final status = TrackingStatusPresentation.fromValue(value);
    return ClientTrackingStatus(
      status.title,
      status.description,
      terminal: status.terminal,
    );
  }
}

bool _matchesOperation(Map<String, dynamic>? request, String? operationId) {
  if (request == null || operationId == null || operationId.trim().isEmpty) {
    return false;
  }
  final operation = request['operation'];
  final reservation = request['reservation'];
  final nestedOperation = reservation is Map ? reservation['operation'] : null;
  final ids = [
    request['operation_id'],
    operation is Map ? operation['id'] : null,
    reservation is Map ? reservation['operation_id'] : null,
    nestedOperation is Map ? nestedOperation['id'] : null,
  ];
  final resolved =
      ids
          .where((value) => value != null && value.toString().trim().isNotEmpty)
          .firstOrNull;
  return resolved?.toString().trim() == operationId.trim();
}

String _textField(Map<String, dynamic> data, List<String> fields) {
  for (final field in fields) {
    final value = data[field];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
  }
  return '';
}

String _dateLabel(DateTime value) =>
    DateFormat('dd MMM yyyy · HH:mm', 'es_MX').format(value.toLocal());
const _trackingBg = Color(0xFF071321);
const _trackingGold = Color(0xFFD6B477);
const _trackingWhite = Color(0xFFF5F7FA);
const _trackingMuted = Color(0xFFA6B5C5);
const _trackingEyebrow = TextStyle(
  color: _trackingMuted,
  fontSize: 10,
  fontWeight: FontWeight.w700,
  letterSpacing: 1,
);
