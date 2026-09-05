import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/cliente_api.dart';
import '../../../models/client_operation_tracking.dart';
import '../../../models/flight_brief.dart';
import '../tema_cliente.dart';
import 'pantalla_seguimiento_cliente.dart';

typedef FlightBriefLoader =
    Future<FlightBrief> Function(String flightRequestId);

class ClientFlightBriefScreen extends StatefulWidget {
  const ClientFlightBriefScreen({
    super.key,
    required this.flightRequestId,
    this.loader,
    this.trackingLoader,
    this.flightRequest,
  });

  final String flightRequestId;
  final FlightBriefLoader? loader;
  final OperationTrackingLoader? trackingLoader;
  final Map<String, dynamic>? flightRequest;

  @override
  State<ClientFlightBriefScreen> createState() =>
      _ClientFlightBriefScreenState();
}

class _ClientFlightBriefScreenState extends State<ClientFlightBriefScreen>
    with WidgetsBindingObserver {
  static const _refreshInterval = Duration(seconds: 20);
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _actionsDrawerKey = GlobalKey<_FlightActionsDrawerState>();

  Timer? _refreshTimer;
  FlightBrief? _brief;
  Object? _error;
  String? _refreshMessage;
  bool _loading = true;
  int _requestVersion = 0;
  String? _activeFlightRequestId;

  FlightBriefLoader get _loader =>
      widget.loader ?? ApiClient.instance.getFlightBrief;

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
  void didUpdateWidget(covariant ClientFlightBriefScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flightRequestId == widget.flightRequestId) return;
    _requestVersion++;
    _brief = null;
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
    final requestId = widget.flightRequestId.trim();
    if (requestId.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = const ApiException('No fue posible identificar el vuelo.');
        });
      }
      return;
    }
    if (_activeFlightRequestId == requestId) return;

    final version = ++_requestVersion;
    _activeFlightRequestId = requestId;
    if (!refresh && mounted) {
      setState(() {
        _loading = _brief == null;
        _error = null;
      });
    }

    try {
      final loadedBrief = await _loader(requestId);
      final requestLegs = FlightBrief.legsFromPayload(
        widget.flightRequest ?? const {},
      );
      final brief =
          loadedBrief.legs.isEmpty && requestLegs.isNotEmpty
              ? loadedBrief.withLegs(requestLegs)
              : loadedBrief;
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _brief = brief;
        _loading = false;
        _error = null;
        _refreshMessage = null;
      });
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _loading = false;
        if (_brief == null) {
          _error = error;
        } else {
          _refreshMessage =
              'No fue posible actualizar la información del vuelo.';
        }
      });
    } finally {
      if (_activeFlightRequestId == requestId) {
        _activeFlightRequestId = null;
      }
    }
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No fue posible abrir este enlace.')),
        );
      }
    }
  }

  void _closeActionsDrawer() {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isEndDrawerOpen ?? false) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final brief = _brief;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: ClientThemeColors.bg,
      drawerScrimColor: Colors.black.withValues(alpha: .58),
      endDrawerEnableOpenDragGesture: false,
      endDrawer: _FlightActionsDrawer(
        key: _actionsDrawerKey,
        brief: brief,
        onClose: _closeActionsDrawer,
        operationId: brief?.operation.id ?? '',
        trackingLoader:
            widget.trackingLoader ?? ApiClient.instance.getOperationTracking,
        onOpenMaps:
            brief?.presentation.mapsUrl.isNotEmpty == true
                ? () async {
                  _closeActionsDrawer();
                  await _openUrl(brief!.presentation.mapsUrl);
                }
                : null,
      ),
      appBar: AppBar(
        backgroundColor: ClientThemeColors.bg,
        foregroundColor: ClientThemeColors.text,
        elevation: 0,
        title: const Text('Información de tu vuelo'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Acciones del vuelo',
              onPressed: () {
                _actionsDrawerKey.currentState?.showTracking();
                _scaffoldKey.currentState?.openEndDrawer();
              },
              icon: const Icon(Icons.more_vert_rounded),
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                backgroundColor: const Color(0xFF10314A),
                foregroundColor: const Color(0xFF8FC9F4),
                shape: const CircleBorder(
                  side: BorderSide(color: Color(0x3324516D)),
                ),
              ),
            ),
          ),
        ],
      ),
      body:
          _loading && brief == null
              ? const _FlightBriefLoading()
              : _error != null && brief == null
              ? _FlightBriefError(onRetry: _load)
              : RefreshIndicator(
                onRefresh: () => _load(refresh: true),
                color: ClientThemeColors.accent,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    if (_refreshMessage != null)
                      _RefreshWarning(message: _refreshMessage!),
                    if (brief != null && !brief.visible)
                      _FlightBriefUnavailable(
                        onRefresh: () => _load(refresh: true),
                      )
                    else if (brief != null) ...[
                      _FlightTimeline(brief: brief),
                      const SizedBox(height: 16),
                      _FlightHero(brief: brief),
                      const SizedBox(height: 16),
                      if (brief.legs.length > 1)
                        _ItineraryCard(legs: brief.legs)
                      else
                        _RouteCard(brief: brief),
                      if (!brief.hasLegPresentation &&
                          brief.presentation.hasContent) ...[
                        const SizedBox(height: 12),
                        _PresentationCard(brief: brief, onOpenMaps: _openUrl),
                      ],
                      const SizedBox(height: 12),
                      _PreparationCard(brief: brief),
                      const SizedBox(height: 12),
                      _OperationalCard(brief: brief),
                      if (brief.crew.assigned) ...[
                        const SizedBox(height: 12),
                        _CrewCard(brief: brief),
                      ],
                      const SizedBox(height: 12),
                      _NextStepCard(brief: brief),
                      const SizedBox(height: 12),
                      _CustomerActionCard(brief: brief),
                      if (brief.services.values.any(
                        (service) => service.requested,
                      )) ...[
                        const SizedBox(height: 12),
                        _ServicesCard(brief: brief),
                      ],
                      if (brief.presentation.instructions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _InstructionsCard(
                          instructions: brief.presentation.instructions,
                        ),
                      ],
                      if (brief.support.hasContact) ...[
                        const SizedBox(height: 12),
                        _SupportCard(
                          support: brief.support,
                          onOpenUrl: _openUrl,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
    );
  }
}

class _FlightActionsDrawer extends StatefulWidget {
  const _FlightActionsDrawer({
    super.key,
    required this.brief,
    required this.onClose,
    required this.operationId,
    required this.trackingLoader,
    required this.onOpenMaps,
  });

  final FlightBrief? brief;
  final VoidCallback onClose;
  final String operationId;
  final OperationTrackingLoader trackingLoader;
  final Future<void> Function()? onOpenMaps;

  @override
  State<_FlightActionsDrawer> createState() => _FlightActionsDrawerState();
}

class _FlightActionsDrawerState extends State<_FlightActionsDrawer> {
  ClientOperationTracking? _tracking;
  Object? _trackingError;
  bool _trackingExpanded = true;
  bool _trackingLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.operationId.isNotEmpty) _loadTracking();
  }

  void showTracking() {
    if (widget.operationId.isEmpty) return;
    if (!_trackingExpanded) setState(() => _trackingExpanded = true);
    if (_tracking == null && !_trackingLoading) _loadTracking();
  }

  Future<void> _toggleTracking() async {
    if (widget.operationId.isEmpty) return;
    setState(() => _trackingExpanded = !_trackingExpanded);
    if (!_trackingExpanded || _tracking != null || _trackingLoading) return;
    await _loadTracking();
  }

  Future<void> _loadTracking() async {
    if (_trackingLoading) return;
    setState(() {
      _trackingLoading = true;
      _trackingError = null;
    });
    try {
      final tracking = await widget.trackingLoader(widget.operationId);
      if (!mounted) return;
      setState(() => _tracking = tracking);
    } catch (error) {
      if (!mounted) return;
      setState(() => _trackingError = error);
    } finally {
      if (mounted) setState(() => _trackingLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width * .86).clamp(280.0, 380.0);
    final requestId = widget.brief?.flightRequestId.trim() ?? '';

    return Drawer(
      width: width,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B2233), Color(0xFF102C40)],
            ),
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(24),
            ),
            border: const Border(left: BorderSide(color: Color(0xFF24516D))),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 26,
                offset: Offset(-8, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ACCIONES DEL VUELO',
                            style: TextStyle(
                              color: Color(0xFFF3F7FA),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .8,
                            ),
                          ),
                          if (requestId.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              'Solicitud #$requestId',
                              style: const TextStyle(
                                color: Color(0xFF9FB7C8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar acciones',
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close_rounded),
                      color: const Color(0xFFBBD8EC),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0x2E64A0C8)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (widget.operationId.isNotEmpty) ...[
                      _FlightActionMenuItem(
                        icon: Icons.radar_rounded,
                        title: 'Ver seguimiento',
                        onTap: _toggleTracking,
                        enabled: true,
                        destructive: false,
                        expanded: _trackingExpanded,
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        child:
                            _trackingExpanded
                                ? _TrackingDrawerHistory(
                                  tracking: _tracking,
                                  loading: _trackingLoading,
                                  hasError: _trackingError != null,
                                  onRetry: _loadTracking,
                                )
                                : const SizedBox.shrink(),
                      ),
                    ],
                    if (widget.onOpenMaps != null)
                      _FlightActionMenuItem(
                        icon: Icons.map_outlined,
                        title: 'Cómo llegar',
                        onTap: () => widget.onOpenMaps!(),
                        enabled: true,
                        destructive: false,
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

class _FlightActionMenuItem extends StatelessWidget {
  const _FlightActionMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
    this.enabled = true,
    this.expanded = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool destructive;
  final bool enabled;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? const Color(0xFFFF6B72) : const Color(0xFFBBD8EC);
    return Semantics(
      button: true,
      enabled: enabled && onTap != null,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x2E64A0C8))),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color:
                        enabled
                            ? const Color(0xFFF3F7FA)
                            : const Color(0xFF66839A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AnimatedRotation(
                duration: const Duration(milliseconds: 180),
                turns: expanded ? .25 : 0,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: color.withValues(alpha: .75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingDrawerHistory extends StatelessWidget {
  const _TrackingDrawerHistory({
    required this.tracking,
    required this.loading,
    required this.hasError,
    required this.onRetry,
  });

  final ClientOperationTracking? tracking;
  final bool loading;
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(22),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF8FC9F4)),
        ),
      );
    }
    if (hasError) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No pudimos cargar el seguimiento.',
              style: TextStyle(
                color: Color(0xFFF3F7FA),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (tracking == null) return const SizedBox.shrink();

    final status = ClientTrackingStatus.fromValue(tracking!.status);
    final events = [...tracking!.timeline]..sort((a, b) {
      if (a.createdAt == null || b.createdAt == null) return 0;
      return b.createdAt!.compareTo(a.createdAt!);
    });

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1C2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF24516D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HISTORIAL DE SEGUIMIENTO', style: _drawerEyebrowStyle),
          const SizedBox(height: 10),
          _DrawerCurrentStatus(status: status, rawStatus: tracking!.status),
          const SizedBox(height: 18),
          const Text('HISTORIAL DEL VUELO', style: _drawerEyebrowStyle),
          const SizedBox(height: 12),
          if (events.isEmpty)
            const Text(
              'Aún no hay actualizaciones operacionales disponibles.',
              style: TextStyle(color: Color(0xFFB8CCE0), height: 1.35),
            )
          else
            for (var index = 0; index < events.length; index++)
              _DrawerTimelineEvent(
                event: events[index],
                isLast: index == events.length - 1,
              ),
        ],
      ),
    );
  }
}

const _drawerEyebrowStyle = TextStyle(
  color: Color(0xFF9FB9CB),
  fontSize: 11,
  fontWeight: FontWeight.w900,
  letterSpacing: .8,
);

class _DrawerCurrentStatus extends StatelessWidget {
  const _DrawerCurrentStatus({required this.status, required this.rawStatus});
  final ClientTrackingStatus status;
  final String rawStatus;

  @override
  Widget build(BuildContext context) {
    final eventState = ClientTrackingEventState.fromValue(rawStatus);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF102C40),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status.title,
            style: const TextStyle(
              color: Color(0xFFF3F7FA),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status.description,
            style: const TextStyle(color: Color(0xFFB8CCE0), height: 1.3),
          ),
          const SizedBox(height: 8),
          _DrawerStatusBadge(state: eventState),
        ],
      ),
    );
  }
}

class _DrawerTimelineEvent extends StatelessWidget {
  const _DrawerTimelineEvent({required this.event, required this.isLast});
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
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: state.color,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 82, color: const Color(0xFF54798F)),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.createdAt != null)
                  Text(
                    DateFormat(
                      'dd MMM yyyy · HH:mm',
                      'es_MX',
                    ).format(event.createdAt!.toLocal()),
                    style: const TextStyle(
                      color: Color(0xFF9FB9CB),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (event.title.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    event.title,
                    style: const TextStyle(
                      color: Color(0xFFF3F7FA),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    event.description,
                    style: const TextStyle(
                      color: Color(0xFFB8CCE0),
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                _DrawerStatusBadge(state: state),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DrawerStatusBadge extends StatelessWidget {
  const _DrawerStatusBadge({required this.state});
  final ClientTrackingEventState state;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: state.background,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: state.color.withValues(alpha: .55)),
    ),
    child: Text(
      state.label,
      style: TextStyle(
        color: state.color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _FlightBriefLoading extends StatelessWidget {
  const _FlightBriefLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: ClientThemeColors.accent),
        SizedBox(height: 16),
        Text('Actualizando la información de tu vuelo...'),
      ],
    ),
  );
}

class _FlightBriefError extends StatelessWidget {
  const _FlightBriefError({required this.onRetry});

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
            size: 40,
            color: ClientThemeColors.muted,
          ),
          const SizedBox(height: 14),
          const Text(
            'No pudimos cargar la información de tu vuelo.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}

class _FlightBriefUnavailable extends StatelessWidget {
  const _FlightBriefUnavailable({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => _BriefCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.lock_clock_outlined,
          color: ClientThemeColors.accent,
          size: 30,
        ),
        const SizedBox(height: 14),
        const Text(
          'Flight Brief disponible después de confirmar el pago.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Actualizaremos esta sección cuando la información esté disponible.',
          style: TextStyle(color: _briefMuted, height: 1.4),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Actualizar'),
        ),
      ],
    ),
  );
}

class _RefreshWarning extends StatelessWidget {
  const _RefreshWarning({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF845A00),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

class _FlightTimeline extends StatelessWidget {
  const _FlightTimeline({required this.brief});
  final FlightBrief brief;

  @override
  Widget build(BuildContext context) {
    final phase = _FlightPhase.fromBrief(brief);
    final labels = const [
      'Pago',
      'Reserva',
      'Detalles',
      'Flight Brief',
      'Preparación',
      'Seguimiento',
    ];
    final current = phase.timelineIndex;
    return _BriefCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(labels.length, (index) {
            final completed = index < current;
            final active = index == current;
            return Row(
              children: [
                _TimelineNode(
                  label: labels[index],
                  completed: completed,
                  active: active,
                ),
                if (index != labels.length - 1)
                  Container(
                    width: 24,
                    height: 2,
                    color:
                        completed
                            ? const Color(0xFF19805A)
                            : const Color(0xFFD6E0E6),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.label,
    required this.completed,
    required this.active,
  });
  final String label;
  final bool completed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color =
        completed ? const Color(0xFF19805A) : ClientThemeColors.accent;
    return SizedBox(
      width: 74,
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color:
                  completed
                      ? color
                      : active
                      ? const Color(0xFFE7F4F5)
                      : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? color : const Color(0xFFCBD8DF),
                width: active ? 3 : 1,
              ),
            ),
            child:
                completed
                    ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 17,
                    )
                    : active
                    ? Icon(Icons.flight_rounded, color: color, size: 19)
                    : null,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? ClientThemeColors.text : _briefMuted,
              fontSize: 11,
              fontWeight:
                  active || completed ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlightHero extends StatelessWidget {
  const _FlightHero({required this.brief});
  final FlightBrief brief;

  @override
  Widget build(BuildContext context) {
    final phase = _FlightPhase.fromBrief(brief);
    return _BriefCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('FLIGHT BRIEF', style: _eyebrowStyle),
                const SizedBox(height: 7),
                Text(
                  _travelCopy(phase.title, brief.legs.length > 1),
                  style: const TextStyle(
                    color: ClientThemeColors.text,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  phase.subtitle,
                  style: const TextStyle(color: _briefMuted, height: 1.4),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 8,
            child: _AircraftImage(
              imageUrl: brief.aircraft.imageUrl,
              model: brief.aircraft.model,
            ),
          ),
        ],
      ),
    );
  }
}

class _AircraftImage extends StatelessWidget {
  const _AircraftImage({required this.imageUrl, required this.model});

  final String imageUrl;
  final String model;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return _AircraftFallback(model: model);

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder:
          (context, child, progress) =>
              progress == null ? child : _AircraftFallback(model: model),
      errorBuilder: (_, __, ___) => _AircraftFallback(model: model),
    );
  }
}

class _AircraftFallback extends StatelessWidget {
  const _AircraftFallback({required this.model});

  final String model;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: ClientThemeColors.softSurface,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.flight_rounded,
            size: 48,
            color: ClientThemeColors.accent,
          ),
          if (model.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              model,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ClientThemeColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.brief});
  final FlightBrief brief;

  @override
  Widget build(BuildContext context) => _BriefCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('RUTA', style: _eyebrowStyle),
        const SizedBox(height: 16),
        _AirportRow(
          location: brief.departure,
          icon: Icons.flight_takeoff_rounded,
        ),
        const Padding(
          padding: EdgeInsets.only(left: 16),
          child: SizedBox(
            height: 18,
            child: VerticalDivider(color: Color(0xFF5E7E96), thickness: 2),
          ),
        ),
        _AirportRow(location: brief.arrival, icon: Icons.flight_land_rounded),
        const SizedBox(height: 18),
        const Divider(height: 1),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _FlightFact(
                label: 'Fecha',
                value: _dateLabel(brief.flight.departureAt),
              ),
            ),
            Expanded(
              child: _FlightFact(
                label: 'Salida',
                value: _timeLabel(brief.flight.departureAt),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _FlightFact(
                label: 'Llegada',
                value: _timeLabel(brief.flight.arrivalAt),
              ),
            ),
            Expanded(
              child: _FlightFact(
                label: 'Duración',
                value: _durationLabel(brief.flight.durationHours),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ItineraryCard extends StatelessWidget {
  const _ItineraryCard({required this.legs});

  final List<FlightBriefLeg> legs;

  @override
  Widget build(BuildContext context) => _BriefCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ITINERARIO', style: _eyebrowStyle),
        const SizedBox(height: 14),
        for (var index = 0; index < legs.length; index++) ...[
          _ItineraryLegItem(
            leg: legs[index],
            index: index,
            totalLegs: legs.length,
          ),
          if (index != legs.length - 1) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
          ],
        ],
      ],
    ),
  );
}

class _ItineraryLegItem extends StatelessWidget {
  const _ItineraryLegItem({
    required this.leg,
    required this.index,
    required this.totalLegs,
  });

  final FlightBriefLeg leg;
  final int index;
  final int totalLegs;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('TRAMO ${index + 1}', style: _eyebrowStyle),
      const SizedBox(height: 10),
      _LegAirport(location: leg.origin, icon: Icons.flight_takeoff_rounded),
      const Padding(
        padding: EdgeInsets.only(left: 10),
        child: SizedBox(
          height: 16,
          child: VerticalDivider(color: Color(0xFF5E7E96), thickness: 2),
        ),
      ),
      _LegAirport(location: leg.destination, icon: Icons.flight_land_rounded),
      if (leg.departureAt != null) ...[
        const SizedBox(height: 12),
        _LegDetail(
          icon: Icons.schedule_outlined,
          label: 'Salida',
          value: _dateTimeLabel(leg.departureAt),
        ),
      ],
      if (leg.presentationLocation.isNotEmpty) ...[
        const SizedBox(height: 8),
        _LegDetail(
          icon: Icons.place_outlined,
          label: 'Presentación',
          value: leg.presentationLocation,
        ),
      ],
      if (leg.presentationAt != null || leg.presentationTime.isNotEmpty) ...[
        const SizedBox(height: 8),
        _LegDetail(
          icon: Icons.access_time_rounded,
          label: 'Hora de presentación',
          value:
              leg.presentationAt != null
                  ? _dateTimeLabel(leg.presentationAt)
                  : leg.presentationTime,
        ),
      ],
    ],
  );
}

class _LegAirport extends StatelessWidget {
  const _LegAirport({required this.location, required this.icon});

  final FlightBriefLocation location;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: ClientThemeColors.accent),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (location.code.isNotEmpty)
              Text(
                location.code,
                style: const TextStyle(
                  color: ClientThemeColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            if (location.airportName.isNotEmpty)
              Text(
                location.airportName,
                style: const TextStyle(color: _briefMuted, height: 1.3),
              ),
            if (location.city.isNotEmpty)
              Text(
                location.city,
                style: const TextStyle(color: _briefMuted, height: 1.3),
              ),
          ],
        ),
      ),
    ],
  );
}

class _LegDetail extends StatelessWidget {
  const _LegDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: ClientThemeColors.accent),
      const SizedBox(width: 8),
      Text('$label: ', style: _eyebrowStyle),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            color: ClientThemeColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _AirportRow extends StatelessWidget {
  const _AirportRow({required this.location, required this.icon});
  final FlightBriefLocation location;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: ClientThemeColors.accent),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _value(location.code),
              style: const TextStyle(
                color: ClientThemeColors.text,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (location.airportName.isNotEmpty)
              Text(
                location.airportName,
                style: const TextStyle(color: _briefMuted, height: 1.35),
              ),
            if (location.city.isNotEmpty)
              Text(
                location.city,
                style: const TextStyle(color: _briefMuted, height: 1.35),
              ),
          ],
        ),
      ),
    ],
  );
}

class _FlightFact extends StatelessWidget {
  const _FlightFact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: _eyebrowStyle),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: ClientThemeColors.text,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _PresentationCard extends StatelessWidget {
  const _PresentationCard({required this.brief, required this.onOpenMaps});
  final FlightBrief brief;
  final Future<void> Function(String) onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final presentation = brief.presentation;
    return _BriefCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DÓNDE PRESENTARTE', style: _eyebrowStyle),
          const SizedBox(height: 8),
          Text(
            _value(
              presentation.airportName,
              fallback: brief.departure.airportName,
            ),
            style: const TextStyle(
              color: ClientThemeColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            _join([presentation.airportCode, presentation.city]),
            style: const TextStyle(color: _briefMuted),
          ),
          const SizedBox(height: 16),
          _DetailLine(
            icon: Icons.place_outlined,
            label: 'Punto de presentación',
            value: _value(presentation.locationName),
          ),
          _DetailLine(
            icon: Icons.schedule_outlined,
            label: 'Hora de presentación',
            value: _dateTimeLabel(presentation.presentationAt),
          ),
          if (presentation.address.isNotEmpty)
            _DetailLine(
              icon: Icons.location_city_outlined,
              label: 'Dirección',
              value: presentation.address,
            ),
          if (presentation.mapsUrl.isNotEmpty) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => onOpenMaps(presentation.mapsUrl),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Cómo llegar'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: ClientThemeColors.accent, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: _eyebrowStyle.copyWith(fontSize: 10),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: ClientThemeColors.text,
                  fontWeight: FontWeight.w700,
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

class _PreparationCard extends StatelessWidget {
  const _PreparationCard({required this.brief});
  final FlightBrief brief;

  @override
  Widget build(BuildContext context) {
    final state = _PreparationState.fromBrief(brief);
    final checklist = brief.checklist;
    final hasProgress = checklist.total > 0 && checklist.percentage != null;
    return _BriefCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PREPARACIÓN DE TU VUELO', style: _eyebrowStyle),
          const SizedBox(height: 8),
          Text(
            state.label,
            style: const TextStyle(
              color: ClientThemeColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (hasProgress) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (checklist.percentage! / 100).clamp(0, 1),
                minHeight: 8,
                backgroundColor: const Color(0xFF29445B),
                color: state.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${checklist.completed} de ${checklist.total} completadas',
              style: const TextStyle(
                color: _briefMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OperationalCard extends StatelessWidget {
  const _OperationalCard({required this.brief});
  final FlightBrief brief;

  @override
  Widget build(BuildContext context) {
    final preparation = _PreparationState.fromBrief(brief);
    final rows = [
      ('Pago confirmado', brief.payment.confirmed, false),
      ('Aeronave asignada', brief.aircraft.model.isNotEmpty, false),
      ('Operador asignado', brief.provider.assigned, false),
      (
        _crewIsConfirmed(brief)
            ? 'Tripulación confirmada'
            : 'Tripulación en confirmación',
        _crewIsConfirmed(brief),
        brief.crew.assigned,
      ),
      (preparation.label, preparation.isComplete, preparation.isActive),
    ];
    return _BriefCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('QUÉ ESTÁ LISTO', style: _eyebrowStyle),
          const SizedBox(height: 10),
          for (final row in rows)
            _StatusRow(label: row.$1, done: row.$2, active: row.$3),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.done,
    required this.active,
  });
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(
          done
              ? Icons.check_circle_rounded
              : active
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded,
          color:
              done
                  ? const Color(0xFF19805A)
                  : active
                  ? ClientThemeColors.accent
                  : const Color(0xFF9AACB8),
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: active ? ClientThemeColors.text : _briefMuted,
              fontWeight: active || done ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CrewCard extends StatelessWidget {
  const _CrewCard({required this.brief});
  final FlightBrief brief;

  @override
  Widget build(BuildContext context) => _BriefCard(
    color: const Color(0xFF10283A),
    borderColor: const Color(0x4D6EA0BE),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TRIPULACIÓN', style: _eyebrowStyle),
        const SizedBox(height: 12),
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFF153A55),
              child: Icon(
                Icons.person_outline_rounded,
                color: ClientThemeColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sobrecargo',
                    style: TextStyle(color: _briefMuted, fontSize: 12),
                  ),
                  Text(
                    _value(brief.crew.visibleName),
                    style: const TextStyle(
                      color: ClientThemeColors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _crewIsConfirmed(brief)
                        ? 'Confirmada'
                        : 'Pendiente de confirmación',
                    style: TextStyle(
                      color:
                          _crewIsConfirmed(brief)
                              ? const Color(0xFF19805A)
                              : ClientThemeColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.brief});
  final FlightBrief brief;

  @override
  Widget build(BuildContext context) {
    final phase = _FlightPhase.fromBrief(brief);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF13293A), Color(0xFF172C3D)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33D9AE54)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x1FD9AE54),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x66D9AE54)),
            ),
            child: const Icon(
              Icons.north_east_rounded,
              color: Color(0xFFE3B957),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PRÓXIMO PASO',
                  style: TextStyle(
                    color: Color(0xFF9FB7C8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _travelCopy(phase.nextTitle, brief.legs.length > 1),
                  style: const TextStyle(
                    color: Color(0xFFF5F8FA),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _travelCopy(phase.nextDescription, brief.legs.length > 1),
                  style: const TextStyle(color: Color(0xFFB3C4D1), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerActionCard extends StatelessWidget {
  const _CustomerActionCard({required this.brief});
  final FlightBrief brief;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF122C3E),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x4064A0C8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('¿NECESITAS HACER ALGO?', style: _eyebrowStyle),
        const SizedBox(height: 8),
        Text(
          _travelCopy(
            brief.presentation.isComplete
                ? 'No necesitas realizar ninguna acción por el momento. Estamos terminando de preparar tu vuelo.'
                : 'No necesitas hacer nada por ahora. Te avisaremos cuando confirmemos los detalles de presentación.',
            brief.legs.length > 1,
          ),
          style: const TextStyle(color: _briefMuted, height: 1.45),
        ),
      ],
    ),
  );
}

class _ServicesCard extends StatelessWidget {
  const _ServicesCard({required this.brief});
  final FlightBrief brief;

  @override
  Widget build(BuildContext context) {
    const labels = {
      'catering': 'Catering',
      'special_baggage': 'Equipaje especial',
      'ground_transport': 'Transporte terrestre',
    };
    final services =
        brief.services.entries.where((entry) => entry.value.requested).toList();
    return _BriefCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SERVICIOS DE TU VUELO', style: _eyebrowStyle),
          const SizedBox(height: 10),
          for (final entry in services)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: ClientThemeColors.accent,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      labels[entry.key] ?? entry.key,
                      style: const TextStyle(
                        color: ClientThemeColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Text(
                    'Solicitado',
                    style: TextStyle(color: _briefMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({required this.instructions});
  final String instructions;

  @override
  Widget build(BuildContext context) => _BriefCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ANTES DE TU VUELO', style: _eyebrowStyle),
        const SizedBox(height: 8),
        Text(
          instructions,
          style: const TextStyle(color: _briefMuted, height: 1.45),
        ),
      ],
    ),
  );
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.support, required this.onOpenUrl});
  final FlightBriefSupport support;
  final Future<void> Function(String) onOpenUrl;

  @override
  Widget build(BuildContext context) => _BriefCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('¿NECESITAS AYUDA?', style: _eyebrowStyle),
        if (support.name.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            support.name,
            style: const TextStyle(
              color: ClientThemeColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (support.phone.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => onOpenUrl('tel:${support.phone}'),
                icon: const Icon(Icons.call_outlined),
                label: const Text('Llamar'),
              ),
            if (support.whatsapp.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => onOpenUrl(support.whatsapp),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('WhatsApp'),
              ),
            if (support.email.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => onOpenUrl('mailto:${support.email}'),
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Correo'),
              ),
          ],
        ),
      ],
    ),
  );
}

class _BriefCard extends StatelessWidget {
  const _BriefCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = ClientThemeColors.surface,
    this.borderColor = const Color(0xFF31526D),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor),
    ),
    child: child,
  );
}

class _PreparationState {
  const _PreparationState(
    this.label,
    this.color, {
    required this.isComplete,
    required this.isActive,
  });
  final String label;
  final Color color;
  final bool isComplete;
  final bool isActive;

  factory _PreparationState.fromBrief(FlightBrief brief) {
    if (_isCancelled(brief)) {
      return const _PreparationState(
        'Preparación no disponible',
        Color(0xFF98AAB5),
        isComplete: false,
        isActive: false,
      );
    }
    if (brief.readiness.ready || brief.checklist.isComplete) {
      return const _PreparationState(
        'Preparación completada',
        Color(0xFF19805A),
        isComplete: true,
        isActive: false,
      );
    }
    if (brief.checklist.exists) {
      return const _PreparationState(
        'Preparación en curso',
        ClientThemeColors.accent,
        isComplete: false,
        isActive: true,
      );
    }
    return const _PreparationState(
      'Preparación pendiente',
      Color(0xFF98AAB5),
      isComplete: false,
      isActive: false,
    );
  }
}

class _FlightPhase {
  const _FlightPhase({
    required this.title,
    required this.subtitle,
    required this.nextTitle,
    required this.nextDescription,
    required this.timelineIndex,
    required this.isInFlight,
    required this.isFinalized,
    required this.isCancelled,
  });
  final String title;
  final String subtitle;
  final String nextTitle;
  final String nextDescription;
  final int timelineIndex;
  final bool isInFlight;
  final bool isFinalized;
  final bool isCancelled;

  factory _FlightPhase.fromBrief(FlightBrief brief) {
    final status =
        '${brief.flight.status} ${brief.operation.status} ${brief.operation.crewStatus}'
            .toLowerCase();
    final cancelled = _isCancelled(brief);
    final inFlight = _containsAny(status, const [
      'in_flight',
      'en_vuelo',
      'airborne',
    ]);
    final finalized = _containsAny(status, const [
      'landed',
      'aterriz',
      'completed',
      'finaliz',
    ]);
    final preparation = _PreparationState.fromBrief(brief);
    if (cancelled) {
      return const _FlightPhase(
        title: 'Tu vuelo fue cancelado',
        subtitle: 'La información de la operación se actualizó.',
        nextTitle: 'Tu vuelo fue cancelado',
        nextDescription:
            'Si necesitas ayuda, nuestro equipo está disponible para ti.',
        timelineIndex: 5,
        isInFlight: false,
        isFinalized: false,
        isCancelled: true,
      );
    }
    if (inFlight) {
      return const _FlightPhase(
        title: 'Tu vuelo está en curso',
        subtitle: 'Tu operación se encuentra en seguimiento.',
        nextTitle: 'Tu vuelo está en curso',
        nextDescription: 'Puedes consultar el seguimiento cuando lo necesites.',
        timelineIndex: 5,
        isInFlight: true,
        isFinalized: false,
        isCancelled: false,
      );
    }
    if (finalized) {
      return const _FlightPhase(
        title: 'Tu vuelo ha finalizado',
        subtitle: 'La operación de tu vuelo concluyó.',
        nextTitle: 'Tu vuelo ha finalizado',
        nextDescription: 'El resumen queda disponible en seguimiento.',
        timelineIndex: 5,
        isInFlight: false,
        isFinalized: true,
        isCancelled: false,
      );
    }
    if (brief.readiness.ready) {
      return const _FlightPhase(
        title: 'Todo listo para tu vuelo',
        subtitle: 'La preparación operacional está completa.',
        nextTitle: 'Todo listo para tu vuelo',
        nextDescription: 'Tu vuelo está preparado para la salida.',
        timelineIndex: 4,
        isInFlight: false,
        isFinalized: false,
        isCancelled: false,
      );
    }
    if (preparation.isActive) {
      return const _FlightPhase(
        title: 'Estamos preparando tu vuelo',
        subtitle: 'El equipo continúa las verificaciones previas.',
        nextTitle: 'Preparación en curso',
        nextDescription:
            'Nuestro equipo está realizando las verificaciones previas.',
        timelineIndex: 4,
        isInFlight: false,
        isFinalized: false,
        isCancelled: false,
      );
    }
    if (brief.crew.assigned && !_crewIsConfirmed(brief)) {
      return const _FlightPhase(
        title: 'Estamos preparando tu vuelo',
        subtitle: 'Estamos finalizando la coordinación de tu tripulación.',
        nextTitle: 'Confirmación de tu tripulación',
        nextDescription:
            'Estamos terminando de confirmar al equipo que atenderá tu vuelo.',
        timelineIndex: 3,
        isInFlight: false,
        isFinalized: false,
        isCancelled: false,
      );
    }
    return const _FlightPhase(
      title: 'Estamos preparando tu vuelo',
      subtitle: 'Estamos coordinando la información de tu vuelo.',
      nextTitle: 'Preparación de tu vuelo',
      nextDescription: 'Nuestro equipo realizará las verificaciones previas.',
      timelineIndex: 3,
      isInFlight: false,
      isFinalized: false,
      isCancelled: false,
    );
  }
}

const _eyebrowStyle = TextStyle(
  color: Color(0xFFAEC9D8),
  fontSize: 11,
  fontWeight: FontWeight.w900,
  letterSpacing: .9,
);

const _briefMuted = Color(0xFFB8CCE0);

String _travelCopy(String value, bool isMultiLeg) {
  if (!isMultiLeg) return value;
  return value
      .replaceAll('Tu vuelo', 'Tu viaje')
      .replaceAll('tu vuelo', 'tu viaje');
}

bool _containsAny(String value, List<String> candidates) =>
    candidates.any(value.contains);

bool _isCancelled(FlightBrief brief) {
  final status =
      '${brief.flight.status} ${brief.operation.status}'.toLowerCase();
  return _containsAny(status, const ['cancel', 'rejected', 'rechaz']);
}

bool _crewIsConfirmed(FlightBrief brief) =>
    brief.crew.confirmed ||
    _containsAny(brief.crew.status.toLowerCase(), const [
      'confirmed',
      'in_flight',
      'en_vuelo',
      'landed',
      'aterriz',
    ]);

String _value(String value, {String fallback = 'Por confirmar'}) =>
    value.trim().isEmpty ? fallback : value.trim();

String _join(List<String> values) =>
    values.where((value) => value.trim().isNotEmpty).join(' · ');

String _dateLabel(DateTime? value) =>
    value == null
        ? 'Por confirmar'
        : DateFormat('dd MMM yyyy', 'es_MX').format(value.toLocal());

String _timeLabel(DateTime? value) =>
    value == null
        ? 'Por confirmar'
        : DateFormat('h:mm a', 'es_MX').format(value.toLocal());

String _dateTimeLabel(DateTime? value) =>
    value == null
        ? 'Por confirmar'
        : DateFormat('dd MMM · h:mm a', 'es_MX').format(value.toLocal());

String _durationLabel(double? hours) {
  if (hours == null || hours <= 0) return 'Por confirmar';
  final totalMinutes = (hours * 60).round();
  return '${totalMinutes ~/ 60} h ${totalMinutes % 60} min';
}
