import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/cliente_api.dart';
import '../../../core/client_workflow_status.dart';
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
      backgroundColor: const Color(0xFF071321),
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
        backgroundColor: const Color(0xFF071321),
        foregroundColor: ClientThemeColors.text,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información de tu vuelo',
              maxLines: 2,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            if (brief != null && brief.visible && brief.operation.id.isNotEmpty)
              Text(
                'OPERACIÓN #${brief.operation.id}',
                style: const TextStyle(
                  fontSize: 10,
                  color: _briefGold,
                  letterSpacing: 1.2,
                ),
              ),
          ],
        ),
        toolbarHeight:
            MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 124 : 76,
        iconTheme: const IconThemeData(color: _briefGold),
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
                foregroundColor: _briefGold,
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
              : SafeArea(
                top: false,
                child: RefreshIndicator(
                  onRefresh: () => _load(refresh: true),
                  color: _briefGold,
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
                        _FlightHero(brief: brief),
                        const SizedBox(height: 16),
                        _RouteSummary(
                          brief: brief,
                          flightRequest: widget.flightRequest,
                        ),
                        _ItinerarySection(legs: _displayLegs(brief)),
                        _PresentationSection(
                          brief: brief,
                          onOpenMaps: _openUrl,
                        ),
                        _PreparationSection(brief: brief),
                        if (brief.crew.assigned) ...[
                          const SizedBox(height: 12),
                          _CrewSection(brief: brief),
                        ],
                        const SizedBox(height: 12),
                        _NextStepPanel(brief: brief),
                        if (brief.services.values.any(
                          (service) => service.requested,
                        )) ...[
                          const SizedBox(height: 12),
                          _ServicesSection(brief: brief),
                        ],
                        if (brief.presentation.instructions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _InstructionsSection(
                            instructions: brief.presentation.instructions,
                          ),
                        ],
                        if (brief.support.hasContact) ...[
                          const SizedBox(height: 12),
                          _SupportSection(
                            support: brief.support,
                            onOpenUrl: _openUrl,
                          ),
                        ],
                      ],
                    ],
                  ),
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
        CircularProgressIndicator(color: _briefGold),
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
  Widget build(BuildContext context) => _BriefSection(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_clock_outlined, color: _briefGold, size: 30),
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

class _FlightHero extends StatelessWidget {
  const _FlightHero({required this.brief});
  final FlightBrief brief;

  @override
  Widget build(BuildContext context) {
    final phase = _FlightPhase.fromBrief(brief);
    final preparation = _PreparationState.fromBrief(brief);
    final status =
        phase.isCancelled
            ? 'CANCELADO'
            : phase.isInFlight
            ? 'EN OPERACIÓN'
            : phase.isFinalized
            ? 'FINALIZADO'
            : brief.readiness.ready
            ? 'LISTO PARA SALIDA'
            : preparation.isActive
            ? 'EN PREPARACIÓN'
            : _operationStatusLabel(brief);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Positioned.fill(
            child: _AircraftImage(
              imageUrl: brief.aircraft.imageUrl,
              model: brief.aircraft.model,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0x65071321), Color(0xF2071321)],
                ),
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 210),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text('FLIGHT BRIEF', style: _eyebrowStyle),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        status,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: _briefGold,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  _travelCopy(phase.title, brief.legs.length > 1),
                  style: const TextStyle(
                    color: Color(0xFFF5F7FA),
                    fontSize: 25,
                    height: 1.12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  phase.subtitle,
                  style: const TextStyle(
                    color: Color(0xFFD7E0E8),
                    height: 1.4,
                    fontSize: 13,
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
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF172D42), Color(0xFF071321)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
    ),
  );
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.brief, required this.flightRequest});
  final FlightBrief brief;
  final Map<String, dynamic>? flightRequest;

  @override
  Widget build(BuildContext context) {
    final first = brief.legs.firstOrNull;
    final origin = first?.origin ?? brief.departure;
    final destination = first?.destination ?? brief.arrival;
    String airportCode(FlightBriefLocation location, String fallback) =>
        _value(location.code, fallback: _value(fallback));
    String passengers = 'Por confirmar';
    for (final key in ['passengers', 'passenger_count', 'pax', 'seats']) {
      final count = int.tryParse(flightRequest?[key]?.toString() ?? '');
      if (count != null && count > 0) {
        passengers = '$count pax';
        break;
      }
    }
    return _BriefSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (brief.legs.length > 1) ...[
            Text(
              'PRIMER TRAMO · ${brief.legs.length} TRAMOS',
              style: _eyebrowStyle,
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SummaryAirport(
                  code: airportCode(
                    origin,
                    first == null ? brief.flight.origin : '',
                  ),
                  city: origin.city,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: Icon(
                  Icons.flight_takeoff_rounded,
                  color: _briefGold,
                  size: 22,
                ),
              ),
              Expanded(
                child: _SummaryAirport(
                  code: airportCode(
                    destination,
                    first == null ? brief.flight.destination : '',
                  ),
                  city: destination.city,
                  alignRight: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryFact(
                  icon: Icons.schedule_outlined,
                  label: 'SALIDA',
                  value: _dateTimeLabel(
                    first?.departureAt ??
                        (first == null ? brief.flight.departureAt : null),
                  ),
                ),
                _SummaryFact(
                  icon: Icons.people_outline,
                  label: 'PASAJEROS',
                  value: passengers,
                ),
                _SummaryFact(
                  icon: Icons.flight_outlined,
                  label: 'AERONAVE',
                  value: _value(
                    brief.aircraft.model,
                    fallback: _value(brief.flight.aircraft),
                  ),
                ),
                if (brief.flight.arrivalAt != null)
                  _SummaryFact(
                    icon: Icons.flight_land_outlined,
                    label: 'LLEGADA',
                    value: _dateTimeLabel(brief.flight.arrivalAt),
                  ),
                if (brief.flight.durationHours != null)
                  _SummaryFact(
                    icon: Icons.timelapse,
                    label: 'DURACIÓN',
                    value: _durationLabel(brief.flight.durationHours),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryAirport extends StatelessWidget {
  const _SummaryAirport({
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
        code,
        style: const TextStyle(
          color: Color(0xFFF5F7FA),
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (city.isNotEmpty)
        Text(city, style: const TextStyle(color: _briefMuted, fontSize: 12)),
    ],
  );
}

class _SummaryFact extends StatelessWidget {
  const _SummaryFact({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 260),
    padding: const EdgeInsets.only(right: 16),
    margin: const EdgeInsets.only(right: 16),
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: Color(0x1FFFFFFF))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _briefGold, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, style: _eyebrowStyle.copyWith(fontSize: 9)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFF5F7FA),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _ItinerarySection extends StatelessWidget {
  const _ItinerarySection({required this.legs});

  final List<FlightBriefLeg> legs;

  @override
  Widget build(BuildContext context) => _BriefSection(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            const Text('ITINERARIO', style: _eyebrowStyle),
            Text(
              '${legs.length} ${legs.length == 1 ? 'tramo' : 'tramos'}',
              style: const TextStyle(color: _briefMuted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (legs.isEmpty)
          const Text(
            'Itinerario por confirmar',
            style: TextStyle(color: _briefMuted),
          ),
        for (var index = 0; index < legs.length; index++) ...[
          _ItineraryLegItem(
            leg: legs[index],
            index: index,
            totalLegs: legs.length,
          ),
          if (index != legs.length - 1) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0x1FFFFFFF)),
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
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          Semantics(
            label: 'Tramo ${index + 1}',
            child: Text(
              '${index + 1}'.padLeft(2, '0'),
              style: const TextStyle(
                color: _briefGold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (index < totalLegs - 1)
            Container(
              width: 1,
              height: 32,
              margin: const EdgeInsets.only(top: 8),
              color: const Color(0x33D6B477),
            ),
        ],
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_value(leg.origin.code)} → ${_value(leg.destination.code)}',
              style: const TextStyle(
                color: Color(0xFFF5F7FA),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _dateTimeLabel(leg.departureAt),
              style: const TextStyle(color: _briefMuted, fontSize: 12),
            ),
            if (leg.origin.airportName.isNotEmpty ||
                leg.destination.airportName.isNotEmpty)
              Text(
                _join([leg.origin.airportName, leg.destination.airportName]),
                style: const TextStyle(color: _briefMuted, fontSize: 11),
              ),
            if (leg.presentationLocation.isNotEmpty) ...[
              const SizedBox(height: 6),
              _LegDetail(
                icon: Icons.place_outlined,
                label: 'Presentación',
                value: leg.presentationLocation,
              ),
            ],
            if (leg.presentationAt != null ||
                leg.presentationTime.isNotEmpty) ...[
              const SizedBox(height: 6),
              _LegDetail(
                icon: Icons.schedule,
                label: 'Hora de presentación',
                value:
                    leg.presentationAt != null
                        ? _dateTimeLabel(leg.presentationAt)
                        : leg.presentationTime,
              ),
            ],
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
      Icon(icon, size: 18, color: _briefGold),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          '$label: $value',
          style: const TextStyle(
            color: ClientThemeColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _PresentationSection extends StatelessWidget {
  const _PresentationSection({required this.brief, required this.onOpenMaps});
  final FlightBrief brief;
  final Future<void> Function(String) onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final presentation = brief.presentation;
    return _BriefSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DÓNDE PRESENTARTE', style: _eyebrowStyle),
          const SizedBox(height: 8),
          Text(
            _value(
              presentation.airportName,
              fallback: _value(
                brief.legs.firstOrNull?.origin.airportName ?? '',
                fallback: _value(brief.departure.airportName),
              ),
            ),
            style: const TextStyle(
              color: ClientThemeColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            _join([
              _value(
                presentation.airportCode,
                fallback:
                    brief.legs.firstOrNull?.origin.code ?? brief.departure.code,
              ),
              _value(
                presentation.city,
                fallback:
                    brief.legs.firstOrNull?.origin.city ?? brief.departure.city,
              ),
            ]),
            style: const TextStyle(color: _briefMuted),
          ),
          const SizedBox(height: 16),
          _DetailLine(
            icon: Icons.place_outlined,
            label: 'Punto de presentación',
            value: _value(
              presentation.locationName,
              fallback:
                  brief.hasLegPresentation
                      ? 'Consulta la presentación de cada tramo en el itinerario.'
                      : 'El punto de presentación será confirmado por nuestro equipo.',
            ),
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
        Icon(icon, color: _briefGold, size: 19),
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

class _PreparationSection extends StatelessWidget {
  const _PreparationSection({required this.brief});
  final FlightBrief brief;
  @override
  Widget build(BuildContext context) {
    final preparation = _PreparationState.fromBrief(brief);
    final checklist = brief.checklist;
    final rows = [
      ('Pago confirmado', brief.payment.confirmed, false),
      ('Aeronave identificada', brief.aircraft.model.isNotEmpty, false),
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
    return _BriefSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ESTADO DE PREPARACIÓN', style: _eyebrowStyle),
          const SizedBox(height: 12),
          Text(
            preparation.label,
            style: const TextStyle(
              color: Color(0xFFF5F7FA),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                Expanded(
                  child: Semantics(
                    label:
                        '${rows[index].$1}: ${rows[index].$2
                            ? 'completado'
                            : rows[index].$3
                            ? 'en proceso'
                            : 'pendiente'}',
                    child: Tooltip(
                      message: rows[index].$1,
                      child: Center(
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                rows[index].$2
                                    ? _briefGold
                                    : Colors.transparent,
                            border: Border.all(
                              color:
                                  rows[index].$2 || rows[index].$3
                                      ? _briefGold
                                      : _briefMuted,
                            ),
                          ),
                          child: Icon(
                            rows[index].$2
                                ? Icons.check
                                : rows[index].$3
                                ? Icons.more_horiz
                                : Icons.circle_outlined,
                            size: 16,
                            color:
                                rows[index].$2
                                    ? const Color(0xFF071321)
                                    : _briefGold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (index < rows.length - 1)
                  const Expanded(
                    child: Divider(height: 1, color: Color(0x33FFFFFF)),
                  ),
              ],
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            iconColor: _briefGold,
            collapsedIconColor: _briefGold,
            shape: const Border(),
            collapsedShape: const Border(),
            title: const Text(
              'Ver hitos de preparación',
              style: TextStyle(color: _briefMuted, fontSize: 12),
            ),
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        row.$2
                            ? Icons.check_circle_outline
                            : row.$3
                            ? Icons.pending_outlined
                            : Icons.radio_button_unchecked,
                        color: row.$2 || row.$3 ? _briefGold : _briefMuted,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${row.$1} · ${row.$2
                              ? 'Completado'
                              : row.$3
                              ? 'En proceso'
                              : 'Pendiente'}',
                          style: const TextStyle(
                            color: _briefMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (checklist.total > 0 &&
              checklist.percentage != null &&
              !_isCancelled(brief)) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (checklist.percentage! / 100).clamp(0, 1),
              minHeight: 3,
              color: _briefGold,
              backgroundColor: const Color(0xFF172D42),
            ),
            const SizedBox(height: 8),
            Text(
              '${checklist.completed} de ${checklist.total} completadas',
              style: const TextStyle(color: _briefMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _CrewSection extends StatelessWidget {
  const _CrewSection({required this.brief});
  final FlightBrief brief;

  @override
  Widget build(BuildContext context) => _BriefSection(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TRIPULACIÓN', style: _eyebrowStyle),
        const SizedBox(height: 12),
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFF153A55),
              child: Icon(Icons.person_outline_rounded, color: _briefGold),
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

class _NextStepPanel extends StatelessWidget {
  const _NextStepPanel({required this.brief});
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
                if (!phase.isCancelled &&
                    !phase.isFinalized &&
                    !phase.isInFlight) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'No necesitas realizar ninguna acción por el momento.',
                    style: TextStyle(
                      color: _briefMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.brief});
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
    return _BriefSection(
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
                    color: _briefGold,
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

class _InstructionsSection extends StatelessWidget {
  const _InstructionsSection({required this.instructions});
  final String instructions;

  @override
  Widget build(BuildContext context) => _BriefSection(
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

class _SupportSection extends StatelessWidget {
  const _SupportSection({required this.support, required this.onOpenUrl});
  final FlightBriefSupport support;
  final Future<void> Function(String) onOpenUrl;

  @override
  Widget build(BuildContext context) => _BriefSection(
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

class _BriefSection extends StatelessWidget {
  const _BriefSection({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 20),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0x1FFFFFFF))),
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
    if (_containsAny(
      '${brief.flight.status} ${brief.operation.status}'.toLowerCase(),
      const [
        'in_flight',
        'en_vuelo',
        'airborne',
        'landed',
        'aterriz',
        'completed',
        'finaliz',
      ],
    )) {
      return const _PreparationState(
        'Preparación sin cierre confirmado',
        Color(0xFFA5B4C4),
        isComplete: false,
        isActive: false,
      );
    }
    if (brief.checklist.exists ||
        _containsAny(
          '${brief.flight.status} ${brief.operation.status}'.toLowerCase(),
          const ['preparing', 'preparation', 'en_preparacion'],
        )) {
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
    required this.isInFlight,
    required this.isFinalized,
    required this.isCancelled,
  });
  final String title;
  final String subtitle;
  final String nextTitle;
  final String nextDescription;
  final bool isInFlight;
  final bool isFinalized;
  final bool isCancelled;

  factory _FlightPhase.fromBrief(FlightBrief brief) {
    final status =
        '${brief.flight.status} ${brief.operation.status}'.toLowerCase();
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
        isInFlight: false,
        isFinalized: false,
        isCancelled: true,
      );
    }
    if (_containsAny(status, const ['tracking_live']) &&
        !inFlight &&
        !finalized) {
      return const _FlightPhase(
        title: 'Tu operación está en curso',
        subtitle: 'La operación se encuentra en seguimiento.',
        nextTitle: 'Seguimiento de tu operación',
        nextDescription:
            'Puedes consultar las actualizaciones en el menú de acciones del vuelo.',
        isInFlight: true,
        isFinalized: false,
        isCancelled: false,
      );
    }
    if (inFlight) {
      return const _FlightPhase(
        title: 'Tu vuelo está en curso',
        subtitle: 'Tu operación se encuentra en seguimiento.',
        nextTitle: 'Tu vuelo está en curso',
        nextDescription: 'Puedes consultar el seguimiento cuando lo necesites.',
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
        isInFlight: false,
        isFinalized: false,
        isCancelled: false,
      );
    }
    if (preparation.isActive ||
        _containsAny(status, const [
          'preparing',
          'preparation',
          'en_preparacion',
        ])) {
      return const _FlightPhase(
        title: 'Estamos preparando tu viaje',
        subtitle:
            'Nuestro equipo coordina cada detalle para que tu vuelo se realice en tiempo y forma.',
        nextTitle: 'Preparación en curso',
        nextDescription:
            'Nuestro equipo está realizando las verificaciones previas.',
        isInFlight: false,
        isFinalized: false,
        isCancelled: false,
      );
    }
    if (preparation.isComplete) {
      return const _FlightPhase(
        title: 'Verificaciones completadas',
        subtitle: 'La salida está pendiente de confirmación operativa.',
        nextTitle: 'Coordinación de salida',
        nextDescription: 'Te informaremos cuando se confirme la salida.',
        isInFlight: false,
        isFinalized: false,
        isCancelled: false,
      );
    }
    if (_containsAny(
      '${brief.flight.status} ${brief.operation.status}'.toLowerCase(),
      const ['pending', 'pendiente'],
    )) {
      return const _FlightPhase(
        title: 'Tu vuelo está pendiente',
        subtitle:
            'Estamos a la espera de confirmar la información de tu operación.',
        nextTitle: 'Confirmación de la operación',
        nextDescription:
            'Nuestro equipo te informará cuando haya una actualización.',
        isInFlight: false,
        isFinalized: false,
        isCancelled: false,
      );
    }
    if ([brief.flight.status, brief.operation.status].any(
      (value) => const [
        'confirmed',
        'confirmado',
        'confirmada',
        'flight_confirmed',
        'scheduled',
        'programado',
      ].contains(value.trim().toLowerCase()),
    )) {
      return const _FlightPhase(
        title: 'Tu vuelo está confirmado',
        subtitle: 'La preparación operativa está pendiente.',
        nextTitle: 'Preparación de tu viaje',
        nextDescription:
            'Nuestro equipo realizará las verificaciones previas. Te mantendremos informado.',
        isInFlight: false,
        isFinalized: false,
        isCancelled: false,
      );
    }
    return const _FlightPhase(
      title: 'Información de tu vuelo',
      subtitle: 'El estado operativo está por confirmar.',
      nextTitle: 'Actualización de la operación',
      nextDescription:
          'Consulta las próximas actualizaciones o contacta a nuestro equipo.',
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

const _briefMuted = Color(0xFFA5B4C4);
const _briefGold = Color(0xFFD6B477);

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

String _dateTimeLabel(DateTime? value) =>
    value == null
        ? 'Por confirmar'
        : DateFormat('dd MMM yyyy · h:mm a', 'es_MX').format(value.toLocal());

String _durationLabel(double? hours) {
  if (hours == null || hours <= 0) return 'Por confirmar';
  final totalMinutes = (hours * 60).round();
  return '${totalMinutes ~/ 60} h ${totalMinutes % 60} min';
}

List<FlightBriefLeg> _displayLegs(FlightBrief brief) {
  if (brief.legs.isNotEmpty) return brief.legs;
  final origin = _value(brief.departure.code, fallback: brief.flight.origin);
  final destination = _value(
    brief.arrival.code,
    fallback: brief.flight.destination,
  );
  if (origin.isEmpty &&
      destination.isEmpty &&
      brief.flight.departureAt == null) {
    return const [];
  }
  return [
    FlightBriefLeg(
      origin: FlightBriefLocation(
        code: origin,
        airportName: brief.departure.airportName,
        city: brief.departure.city,
      ),
      destination: FlightBriefLocation(
        code: destination,
        airportName: brief.arrival.airportName,
        city: brief.arrival.city,
      ),
      departureAt: brief.flight.departureAt,
      presentationLocation: '',
      presentationAt: null,
      presentationTime: '',
    ),
  ];
}

String _operationStatusLabel(FlightBrief brief) {
  final status =
      (brief.operation.status.isNotEmpty
              ? brief.operation.status
              : brief.flight.status)
          .trim();
  switch (status.toLowerCase()) {
    case 'confirmed':
    case 'confirmado':
    case 'scheduled':
    case 'programado':
      return 'CONFIRMADO';
    case 'pending':
    case 'pendiente':
      return 'PENDIENTE';
    default:
      return status.isEmpty
          ? 'ESTADO POR CONFIRMAR'
          : (clientWorkflowDefinitionById(status.toLowerCase())?.label ??
                  status)
              .toUpperCase();
  }
}
