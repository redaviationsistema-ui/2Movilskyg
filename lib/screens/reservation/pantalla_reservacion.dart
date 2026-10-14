// Nota: este archivo coordina el estado y las acciones del flujo de
// reservacion; la UI detallada vive en componentes separados.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/acceso_comercial_cliente.dart';
import '../../models/aeropuerto.dart';
import '../../models/modelo_ruta.dart';
import '../../providers/proveedor_autenticacion.dart';
import '../../providers/proveedor_reservaciones.dart';
import '../cliente/tema_cliente.dart';
import '../cliente/views/pantalla_pago_cliente.dart';
import '../cliente/widgets/widgets_flujo_movil_cliente.dart';
import 'pantalla_vista_previa_cotizacion.dart';
import 'widgets/hoja_selector_aeropuerto.dart';
import 'widgets/contenido_pantalla_reservacion.dart';

class ReservationScreen extends StatefulWidget {
  const ReservationScreen({
    super.key,
    this.onQuoteReady,
    this.userInitial = 'C',
  });

  final VoidCallback? onQuoteReady;
  final String userInitial;

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final ScrollController _formScrollController = ScrollController();
  final Map<int, GlobalKey> _routeFormKeys = {};
  bool _isSubmittingQuote = false;
  String _tripType = 'Solo ida';
  TimeOfDay? _departureTime;
  DateTime? _returnDate;
  TimeOfDay? _returnTime;

  static const List<String> _priorityAirportCodes = [
    'MEX',
    'CUN',
    'MTY',
    'GDL',
    'SJD',
    'TIJ',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<ReservationProvider>();
      provider.resetForm();
      setState(() {
        _tripType = 'Solo ida';
        _departureTime = null;
        _returnDate = null;
        _returnTime = null;
      });
      await provider.loadInitialData();
      if (!mounted) return;
      await provider.loadClientWorkspaceData(force: true);
    });
  }

  @override
  void dispose() {
    _formScrollController.dispose();
    super.dispose();
  }

  GlobalKey _routeFormKey(int index) =>
      _routeFormKeys.putIfAbsent(index, GlobalKey.new);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final reservation = context.watch<ReservationProvider>();
    final primaryRoute = reservation.routes.first;
    final suggestedAirports = _suggestedAirports(reservation);
    final commercialState = resolveCommercialAccessState(auth.accessData);

    return _ReservationReveal(
      child: ClientMobileScreenShell(
        welcomeTitle: 'Hola ${_firstName(auth.displayName)} 👋',
        welcomeSubtitle: 'Tu próximo vuelo comienza aquí',
        onSignOut: auth.signOut,
        child: ReservationScreenContent(
          reservation: reservation,
          scrollController: _formScrollController,
          routeKeyForIndex: _routeFormKey,
          primaryRoute: primaryRoute,
          suggestedAirports: suggestedAirports,
          dateFormat: _dateFormat,
          tripType: _tripType,
          departureTime: _departureTime,
          returnDate: _returnDate,
          returnTime: _returnTime,
          commercialState: commercialState,
          hasCommercialAccessData: auth.accessData != null,
          onOpenMembership: _openMembershipCenter,
          onTripTypeChanged: (value) {
            setState(() {
              _tripType = value;
              if (value != 'Ida y vuelta') {
                _returnDate = null;
                _returnTime = null;
              }
            });
            reservation.setBookingTripLabel(value);
            if (value == 'Multidestino') {
              while (reservation.routes.length > 1) {
                reservation.removeRoute(reservation.routes.length - 1);
              }
            }
            _normalizeRoutesForMode(reservation);
          },
          onPickOrigin:
              () => _pickAirport(
                title: 'Selecciona origen',
                onSelected: (airport) => reservation.setFromAirport(0, airport),
              ),
          onPickDestination:
              () => _pickAirport(
                title: 'Selecciona destino',
                onSelected: (airport) => reservation.setToAirport(0, airport),
              ),
          onPickPrimaryDate: () => _pickDateForRoute(reservation, 0),
          onPickDepartureTime: _pickDepartureTime,
          onPickReturnDate: _pickReturnDate,
          onPickReturnTime: _pickReturnTime,
          onPassengerChanged: reservation.setGlobalPassengers,
          onPickRouteOrigin:
              (index) => _showMessage(
                'El origen se toma automaticamente del destino anterior.',
              ),
          onPickRouteDestination:
              (index) => _pickAirport(
                title: 'Destino tramo ${index + 1}',
                onSelected:
                    (airport) => reservation.setToAirport(index, airport),
              ),
          onPickRouteDate: (index) => _pickDateForRoute(reservation, index),
          onPickRouteTime: (index) => _pickTimeForRoute(reservation, index),
          onRemoveRoute: reservation.removeRoute,
          onAddRoute: () => _handleAddMultiCityRoute(reservation),
          onApplySuggestedDestination:
              (airport) => _applySuggestedDestination(reservation, airport),
          onPreview: () => _openItinerarySummary(reservation),
        ),
      ),
    );
  }

  String _firstName(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return 'cliente';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  void _openMembershipCenter() {
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
                await context
                    .read<ReservationProvider>()
                    .loadClientWorkspaceData(force: true);
              },
            ),
      ),
    );
  }

  Future<CommercialAccessState> _refreshCommercialAccessState() async {
    final auth = context.read<AuthProvider>();
    await auth.refreshCommercialAccessStatus();
    return resolveCommercialAccessState(auth.accessData);
  }

  bool _blockQuoteIfAccessExpired(
    CommercialAccessState accessState, {
    required String source,
  }) {
    if (accessState.canQuote) return false;

    final auth = context.read<AuthProvider>();
    final access = auth.accessData ?? const <String, dynamic>{};
    final user = auth.user;
    debugPrint(
      '[bloqueo-cotizador-cliente-movil] {source: $source, reason: canQuote=false, blockedMessage: "${accessState.quoteBlockedMessage}", accessStatus: "${accessState.status}", userId: "${user?.id ?? ''}", email: "${user?.email ?? ''}", access: $access}',
    );

    _showMessage(accessState.quoteBlockedMessage);
    _openMembershipCenter();
    return true;
  }

  Future<void> _openItinerarySummary(ReservationProvider reservation) async {
    if (reservation.routes.first.startDate != null) {
      _normalizeRoutesForMode(reservation);
    }
    final navigator = Navigator.of(context);
    final editedLeg = await navigator.push<int>(
      MaterialPageRoute(
        builder:
            (_) => ItinerarySummaryScreen(
              tripType: _tripType,
              onRequestQuote: () => _requestQuoteFromSummary(reservation),
              onEditLeg: navigator.pop,
            ),
      ),
    );

    if (!mounted || editedLeg == null) return;
    final targetIndex = editedLeg < 0 ? 0 : editedLeg;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = _routeFormKey(targetIndex).currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: .08,
        );
      } else if (_formScrollController.hasClients) {
        _formScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _requestQuoteFromSummary(ReservationProvider reservation) async {
    if (_isSubmittingQuote) return;
    setState(() => _isSubmittingQuote = true);
    try {
      await _performQuoteRequest(reservation);
    } finally {
      if (mounted) setState(() => _isSubmittingQuote = false);
    }
  }

  Future<void> _performQuoteRequest(ReservationProvider reservation) async {
    final navigator = Navigator.of(context);
    final accessState = await _refreshCommercialAccessState();
    if (_blockQuoteIfAccessExpired(accessState, source: 'submitSearch')) {
      return;
    }

    final route = reservation.routes.first;
    if (route.fromAirport == null ||
        route.toAirport == null ||
        route.startDate == null) {
      _showMessage('Completa origen, destino y fecha para continuar.');
      return;
    }

    if (_tripType == 'Ida y vuelta' && _returnDate == null) {
      _showMessage('Selecciona la fecha de regreso.');
      return;
    }

    _normalizeRoutesForMode(reservation);

    if (_tripType == 'Multidestino') {
      final completeRoutes = reservation.routes.where(_isRouteComplete).length;
      if (completeRoutes < 2) {
        _showMessage(
          'Agrega al menos dos tramos completos para cotizar multidestino.',
        );
        return;
      }
      final continuityError = _multiCityContinuityError(reservation);
      if (continuityError != null) {
        _showMessage(continuityError);
        return;
      }
    }

    final success = await reservation.previewCurrentSelection();
    if (!mounted) return;

    if (!success) {
      final refreshedAccessState = await _refreshCommercialAccessState();
      if (_blockQuoteIfAccessExpired(
        refreshedAccessState,
        source: 'previewCurrentSelection',
      )) {
        return;
      }
      _showMessage(
        reservation.quoteError ?? 'No fue posible generar una cotizacion real.',
      );
      return;
    }

    final previousRemaining = accessState.remainingFreeQuotes;
    final auth = context.read<AuthProvider>();
    final refreshedState = await _refreshCommercialAccessState();
    if (!refreshedState.hasPaidAccess &&
        previousRemaining > 0 &&
        refreshedState.remainingFreeQuotes >= previousRemaining) {
      auth.consumeTrialQuote();
    }

    if (widget.onQuoteReady != null) {
      navigator.pop();
      widget.onQuoteReady!();
      return;
    }

    if (!mounted) return;
    navigator.pop();
    navigator.push(
      MaterialPageRoute(builder: (_) => const QuotePreviewScreen()),
    );
  }

  void _normalizeRoutesForMode(ReservationProvider reservation) {
    final firstRoute = reservation.routes.first;
    final departureDateTime = _mergeDateAndTime(
      firstRoute.startDate ?? reservation.startDate ?? DateTime.now(),
      _departureTime,
    );

    reservation.setGlobalStartDate(departureDateTime);
    reservation.setStartDate(0, departureDateTime);
    reservation.setPassengers(0, reservation.passengers);

    if (_tripType == 'Solo ida') {
      while (reservation.routes.length > 1) {
        reservation.removeRoute(reservation.routes.length - 1);
      }
      return;
    }

    if (_tripType == 'Ida y vuelta') {
      while (reservation.routes.length > 1) {
        reservation.removeRoute(reservation.routes.length - 1);
      }

      if (reservation.routes.length < 2) {
        reservation.addRoute(allowIncomplete: true);
      }
      if (reservation.routes.length < 2) {
        return;
      }
      final returnRoute = reservation.routes[1];
      returnRoute.fromAirport = firstRoute.toAirport;
      returnRoute.toAirport = firstRoute.fromAirport;
      returnRoute.passengers = reservation.passengers;
      if (_returnDate != null) {
        reservation.setStartDate(
          1,
          _mergeDateAndTime(_returnDate!, _returnTime),
        );
      }
      reservation.setGlobalPassengers(reservation.passengers);
      return;
    }

    for (var index = 1; index < reservation.routes.length; index++) {
      reservation.routes[index].fromAirport =
          reservation.routes[index - 1].toAirport;
      reservation.setPassengers(index, reservation.passengers);
    }
  }

  bool _isRouteComplete(RouteModel route) {
    return route.fromAirport != null &&
        route.toAirport != null &&
        route.startDate != null;
  }

  String? _multiCityContinuityError(ReservationProvider reservation) {
    DateTime? previousDate;
    for (var index = 0; index < reservation.routes.length; index++) {
      final route = reservation.routes[index];
      if (!_isRouteComplete(route)) {
        return 'Completa el tramo ${index + 1} antes de cotizar.';
      }
      if (route.fromAirport == route.toAirport) {
        return 'El origen y destino del tramo ${index + 1} deben ser diferentes.';
      }
      final date = route.startDate!;
      if (previousDate != null && date.isBefore(previousDate)) {
        return 'Ordena las fechas y horas de los tramos antes de cotizar.';
      }
      previousDate = date;
    }
    return null;
  }

  void _handleAddMultiCityRoute(ReservationProvider reservation) {
    final lastRoute = reservation.routes.last;
    if (!_isRouteComplete(lastRoute)) {
      _showMessage('Completa el ultimo tramo antes de agregar otro destino.');
      return;
    }
    reservation.addRoute();
  }

  List<Airport> _suggestedAirports(ReservationProvider reservation) {
    final byCode = <String, Airport>{};
    for (final airport in reservation.airports) {
      final code = airport.iata?.trim().toUpperCase();
      if (code == null || code.isEmpty || byCode.containsKey(code)) continue;
      byCode[code] = airport;
    }

    final prioritized =
        _priorityAirportCodes
            .map((code) => byCode[code])
            .whereType<Airport>()
            .toList();

    if (prioritized.length >= 4) {
      return prioritized.take(6).toList();
    }

    final fallback = byCode.values
        .where(
          (airport) => !prioritized.any((item) => item.iata == airport.iata),
        )
        .take(6 - prioritized.length);

    return [...prioritized, ...fallback];
  }

  void _applySuggestedDestination(
    ReservationProvider reservation,
    Airport airport,
  ) {
    if (_tripType == 'Multidestino') {
      final lastIndex = reservation.routes.length - 1;
      reservation.setToAirport(lastIndex, airport);
      _showMessage('${airport.city} lista como destino del tramo actual.');
      return;
    }

    reservation.setToAirport(0, airport);
    _showMessage('${airport.city} lista como destino sugerido.');
  }

  Future<void> _pickDateForRoute(
    ReservationProvider reservation,
    int index,
  ) async {
    final current = reservation.routes[index].startDate ?? DateTime.now();
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (picked == null) return;
    final previousTime = reservation.routes[index].startDate;
    reservation.setStartDate(
      index,
      DateTime(
        picked.year,
        picked.month,
        picked.day,
        previousTime?.hour ?? 9,
        previousTime?.minute ?? 0,
      ),
    );
  }

  Future<void> _pickTimeForRoute(
    ReservationProvider reservation,
    int index,
  ) async {
    final current = reservation.routes[index].startDate;
    final picked = await showTimePicker(
      context: context,
      initialTime:
          current == null
              ? const TimeOfDay(hour: 9, minute: 0)
              : TimeOfDay.fromDateTime(current),
    );
    if (picked == null) return;
    final baseDate = current ?? DateTime.now();
    reservation.setStartDate(
      index,
      DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  Future<void> _pickReturnDate() async {
    final departureDate =
        context.read<ReservationProvider>().routes.first.startDate ??
        DateTime.now();
    final firstReturnDate = DateTime(
      departureDate.year,
      departureDate.month,
      departureDate.day,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: _returnDate ?? firstReturnDate.add(const Duration(days: 1)),
      firstDate: firstReturnDate,
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (picked == null) return;
    setState(() {
      _returnDate = picked;
    });
  }

  Future<void> _pickDepartureTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _departureTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      _departureTime = picked;
    });
  }

  Future<void> _pickReturnTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _returnTime ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      _returnTime = picked;
    });
  }

  Future<void> _pickAirport({
    required String title,
    required ValueChanged<Airport> onSelected,
  }) async {
    final reservation = context.read<ReservationProvider>();
    final airport = await showModalBottomSheet<Airport>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) =>
              AirportPickerSheet(title: title, airports: reservation.airports),
    );

    if (airport == null) return;
    onSelected(airport);
  }

  DateTime _mergeDateAndTime(DateTime date, TimeOfDay? time) {
    if (time == null) {
      return DateTime(date.year, date.month, date.day, 9);
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _showMessage(String message) {
    final palette = context.clientPalette;
    final lower = message.toLowerCase();
    final isError =
        lower.contains('completa') ||
        lower.contains('no fue posible') ||
        lower.contains('selecciona');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
          backgroundColor:
              isError ? Theme.of(context).colorScheme.error : palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_rounded,
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
}

class _ReservationReveal extends StatefulWidget {
  const _ReservationReveal({required this.child});

  final Widget child;

  @override
  State<_ReservationReveal> createState() => _ReservationRevealState();
}

class _ReservationRevealState extends State<_ReservationReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _offset = Tween<Offset>(
      begin: const Offset(0, .035),
      end: Offset.zero,
    ).animate(curve);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) == true) {
        _controller.value = 1;
        return;
      }
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
