import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/cliente_api.dart';
import '../../../models/client_operation_tracking.dart';
import '../tema_cliente.dart';

typedef OperationTrackingLoader =
    Future<ClientOperationTracking> Function(String operationId);

class ClientTrackingScreen extends StatefulWidget {
  const ClientTrackingScreen({super.key, this.operationId, this.loader});

  final String? operationId;
  final OperationTrackingLoader? loader;

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
    _load();
    _refreshTimer = Timer.periodic(
      _refreshInterval,
      (_) => _load(refresh: true),
    );
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
    _load();
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
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _tracking = tracking;
        _loading = false;
        _error = null;
        _refreshMessage = null;
      });
      if (ClientTrackingStatus.fromValue(tracking.status).terminal) {
        _refreshTimer?.cancel();
      }
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _loading = false;
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
    return Scaffold(
      backgroundColor: ClientThemeColors.bg,
      appBar: AppBar(
        backgroundColor: ClientThemeColors.bg,
        foregroundColor: const Color(0xFF8FC9F4),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seguimiento operacional',
              style: TextStyle(
                color: Color(0xFFF5F8FA),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (tracking?.operationId.isNotEmpty == true)
              Text(
                'OPERACIÓN #${tracking!.operationId}',
                style: const TextStyle(
                  color: Color(0xFF7FB7D8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                ),
              ),
          ],
        ),
      ),
      body:
          _loading && tracking == null
              ? const Center(
                child: CircularProgressIndicator(
                  color: ClientThemeColors.accent,
                ),
              )
              : _error != null && tracking == null
              ? _TrackingError(onRetry: _load)
              : RefreshIndicator(
                onRefresh: () => _load(refresh: true),
                color: ClientThemeColors.accent,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                  children: [
                    if (_refreshMessage != null)
                      _TrackingWarning(message: _refreshMessage!),
                    if (tracking != null) ...[
                      _TrackingStatusCard(
                        status: ClientTrackingStatus.fromValue(tracking.status),
                      ),
                      const SizedBox(height: 16),
                      _TrackingTimeline(events: tracking.timeline),
                    ],
                  ],
                ),
              ),
    );
  }
}

class _TrackingError extends StatelessWidget {
  const _TrackingError({required this.onRetry});
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
          const Text(
            'No pudimos cargar el seguimiento de tu vuelo.',
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

class _TrackingStatusCard extends StatelessWidget {
  const _TrackingStatusCard({required this.status});
  final ClientTrackingStatus status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0D2638), Color(0xFF102E43)],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFF1E526F)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ESTADO ACTUAL',
          style: TextStyle(
            color: const Color(0xFF9FB9CB),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: .9,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          status.title,
          style: const TextStyle(
            color: Color(0xFFF5F8FA),
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          status.description,
          style: const TextStyle(color: Color(0xFFB8CCE0), height: 1.4),
        ),
      ],
    ),
  );
}

class _TrackingTimeline extends StatelessWidget {
  const _TrackingTimeline({required this.events});
  final List<ClientOperationTimelineEvent> events;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF0B2233),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFF1E526F)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACTUALIZACIONES DEL VUELO',
          style: TextStyle(
            color: Color(0xFF9FB9CB),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: .9,
          ),
        ),
        const SizedBox(height: 14),
        if (events.isEmpty)
          const Text(
            'Todavía no hay actualizaciones operacionales disponibles.',
            style: TextStyle(color: Color(0xFFB8CCE0)),
          )
        else
          for (var index = 0; index < events.length; index++)
            _TimelineEvent(
              event: events[index],
              isLast: index == events.length - 1,
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
    final state = ClientTrackingEventState.fromValue(event.status);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: state.color,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 88, color: const Color(0xFF54798F)),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      DateFormat(
                        'dd MMM yyyy · HH:mm',
                        'es_MX',
                      ).format(event.createdAt!.toLocal()),
                      style: const TextStyle(
                        color: Color(0xFF9FB9CB),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (event.title.isNotEmpty)
                  Text(
                    event.title,
                    style: const TextStyle(
                      color: Color(0xFFF5F8FA),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    event.description,
                    style: const TextStyle(
                      color: Color(0xFFB8CCE0),
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                _TimelineStatusBadge(state: state),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineStatusBadge extends StatelessWidget {
  const _TimelineStatusBadge({required this.state});
  final ClientTrackingEventState state;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: state.background,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: state.color.withValues(alpha: .55)),
    ),
    child: Text(
      state.label,
      style: TextStyle(
        color: state.color,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

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
    final status = value.toLowerCase();
    if (_has(status, const ['cancel', 'rechaz'])) {
      return const ClientTrackingStatus(
        'Vuelo cancelado',
        'La operación fue cancelada. Si necesitas ayuda, nuestro equipo está disponible para ti.',
        terminal: true,
      );
    }
    if (_has(status, const ['completed', 'finaliz', 'landed', 'aterriz'])) {
      return const ClientTrackingStatus(
        'Vuelo finalizado',
        'El servicio ha finalizado.',
        terminal: true,
      );
    }
    if (_has(status, const ['in_flight', 'en_vuelo', 'airborne'])) {
      return const ClientTrackingStatus(
        'Tu vuelo está en curso',
        'La operación se encuentra en seguimiento.',
      );
    }
    if (_has(status, const ['ready', 'lista', 'listo'])) {
      return const ClientTrackingStatus(
        'Tu vuelo está listo',
        'La operación está lista para salida.',
      );
    }
    return const ClientTrackingStatus(
      'Estamos preparando tu vuelo',
      'El equipo continúa con la preparación operacional.',
    );
  }
}

bool _has(String value, List<String> candidates) =>
    candidates.any(value.contains);
