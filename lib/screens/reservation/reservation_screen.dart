import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/airport.dart';
import '../../models/route_model.dart';
import '../../providers/reservation_provider.dart';
import '../cliente/widgets/client_mobile_flow_widgets.dart';
import 'quote_preview_screen.dart';

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
  Widget build(BuildContext context) {
    final reservation = context.watch<ReservationProvider>();
    final primaryRoute = reservation.routes.first;
    final suggestedAirports = _suggestedAirports(reservation);

    return ClientMobileScreenShell(
      userInitial: widget.userInitial,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        children: [
          const EyebrowLabel(label: 'Aviacion privada'),
          const SizedBox(height: 12),
          const Text(
            'Vuela privado\nen minutos',
            style: TextStyle(
              fontSize: 38,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Cotiza y compara aeronaves disponibles.',
            style: TextStyle(
              color: Color(0xFF746D64),
              fontSize: 20,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          _QuickActionRail(
            onTodayTrip: () => _applyTodayPreset(reservation),
            onRoundTrip: () => _applyRoundTripPreset(reservation),
            onMultiCity: () => _applyMultiCityPreset(reservation),
          ),
          const SizedBox(height: 28),
          ConciergeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedTripSelector(
                  value: _tripType,
                  onChanged: (value) {
                    setState(() {
                      _tripType = value;
                      if (value != 'Ida y vuelta') {
                        _returnDate = null;
                        _returnTime = null;
                      }
                    });
                    reservation.setBookingTripLabel(value);
                    _normalizeRoutesForMode(reservation);
                  },
                ),
                if (_tripType == 'Ida y vuelta') ...[
                  const SizedBox(height: 16),
                  const _ModeIntroCard(
                    eyebrow: 'Viaje redondo',
                    title:
                        'Define salida y regreso en un mismo flujo ejecutivo.',
                    subtitle:
                        'Ideal para juntas, inspecciones o regreso el mismo dia con control total del itinerario.',
                    tint: Color(0xFF1B8F4D),
                  ),
                ] else if (_tripType == 'Multidestino') ...[
                  const SizedBox(height: 16),
                  const _ModeIntroCard(
                    eyebrow: 'Ruta multi-destino',
                    title: 'Construye una gira privada tramo por tramo.',
                    subtitle:
                        'Perfecto para roadshows, visitas ejecutivas y agendas que combinan varias ciudades.',
                    tint: Color(0xFFB46A00),
                  ),
                ],
                const SizedBox(height: 16),
                if (_tripType == 'Multidestino') ...[
                  const _RouteHeader(title: 'Tramo 1'),
                  const SizedBox(height: 12),
                ],
                ConciergeField(
                  label: 'Origen',
                  value: _airportPrimaryLabel(primaryRoute.fromAirport),
                  secondaryValue: _airportSecondaryLabel(
                    primaryRoute.fromAirport,
                  ),
                  placeholder: 'Seleccionar aeropuerto',
                  onTap:
                      () => _pickAirport(
                        title: 'Selecciona origen',
                        onSelected:
                            (airport) => reservation.setFromAirport(0, airport),
                      ),
                ),
                const SizedBox(height: 12),
                ConciergeField(
                  label: 'Destino',
                  value: _airportPrimaryLabel(primaryRoute.toAirport),
                  secondaryValue: _airportSecondaryLabel(
                    primaryRoute.toAirport,
                  ),
                  placeholder: 'Seleccionar aeropuerto',
                  onTap:
                      () => _pickAirport(
                        title: 'Selecciona destino',
                        onSelected:
                            (airport) => reservation.setToAirport(0, airport),
                      ),
                ),
                const SizedBox(height: 12),
                ConciergeField(
                  label: 'Salida',
                  value:
                      primaryRoute.startDate == null
                          ? 'Seleccionar fecha'
                          : _dateFormat.format(primaryRoute.startDate!),
                  onTap: () => _pickDateForRoute(reservation, 0),
                  trailing: const Icon(
                    Icons.calendar_today_outlined,
                    size: 24,
                    color: Color(0xFF6F675D),
                  ),
                  placeholder: 'Seleccionar fecha',
                ),
                const SizedBox(height: 8),
                _InlinePreferenceButton(
                  title:
                      _departureTime == null
                          ? 'Agregar hora'
                          : 'Hora de salida: ${_departureTime!.format(context)}',
                  onTap: _pickDepartureTime,
                ),
                if (_tripType == 'Ida y vuelta') ...[
                  const SizedBox(height: 14),
                  ConciergeField(
                    label: 'Fecha de regreso',
                    value:
                        _returnDate == null
                            ? 'dd/mm/aaaa'
                            : _dateFormat.format(_returnDate!),
                    onTap: _pickReturnDate,
                    trailing: const Icon(
                      Icons.calendar_today_outlined,
                      size: 24,
                      color: Color(0xFF6F675D),
                    ),
                    placeholder: 'dd/mm/aaaa',
                  ),
                  const SizedBox(height: 8),
                  _InlinePreferenceButton(
                    title:
                        _returnTime == null
                            ? 'Agregar hora de regreso'
                            : 'Hora de regreso: ${_returnTime!.format(context)}',
                    onTap: _pickReturnTime,
                  ),
                ],
                if (_tripType == 'Multidestino') ...[
                  const SizedBox(height: 14),
                  ...List.generate(
                    reservation.routes.length - 1,
                    (extraIndex) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MultiLegCard(
                        index: extraIndex + 1,
                        route: reservation.routes[extraIndex + 1],
                        onPickOrigin:
                            () => _pickAirport(
                              title: 'Origen tramo ${extraIndex + 2}',
                              onSelected:
                                  (airport) => reservation.setFromAirport(
                                    extraIndex + 1,
                                    airport,
                                  ),
                            ),
                        onPickDestination:
                            () => _pickAirport(
                              title: 'Destino tramo ${extraIndex + 2}',
                              onSelected:
                                  (airport) => reservation.setToAirport(
                                    extraIndex + 1,
                                    airport,
                                  ),
                            ),
                        onPickDate:
                            () =>
                                _pickDateForRoute(reservation, extraIndex + 1),
                        onRemove: () => reservation.removeRoute(extraIndex + 1),
                        formatDate: _dateFormat,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        primaryRoute.toAirport == null
                            ? null
                            : () => reservation.addRoute(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Agregar tramo'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: const BorderSide(color: Color(0xFFE2D6C6)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      foregroundColor: const Color(0xFF7A5A20),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _PassengerRow(
                  value: reservation.passengers,
                  onChanged: reservation.setGlobalPassengers,
                ),
                if (suggestedAirports.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Rutas sugeridas',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: Color(0xFF8A641E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 156,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: suggestedAirports.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final airport = suggestedAirports[index];
                        return _SuggestedDestinationCard(
                          airport: airport,
                          isMultiCity: _tripType == 'Multidestino',
                          onTap:
                              () => _applySuggestedDestination(
                                reservation,
                                airport,
                              ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        reservation.isLoadingQuotePreview
                            ? null
                            : () => _handlePreview(reservation),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF151515),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(64),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                    child:
                        reservation.isLoadingQuotePreview
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text(
                              'Ver aeronaves disponibles',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: -0.2,
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cotizacion estimada. Sujeta a FBO, permisos y operacion.',
                  style: TextStyle(
                    color: Color(0xFF8A8379),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (reservation.isLoadingWorkspace) ...[
            const LoadingBand(text: 'Sincronizando rutas del cliente...'),
          ],
          if (reservation.quoteError != null) ...[
            ConciergeCard(
              child: Text(
                reservation.quoteError!,
                style: const TextStyle(
                  color: Color(0xFF8D1F1A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handlePreview(ReservationProvider reservation) async {
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
    final success = await reservation.previewCurrentSelection();
    if (!mounted) return;

    if (!success) {
      _showMessage(
        reservation.quoteError ?? 'No fue posible generar una cotizacion real.',
      );
      return;
    }

    if (widget.onQuoteReady != null) {
      widget.onQuoteReady!();
      return;
    }

    Navigator.push(
      context,
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

      reservation.addRoute();
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
      reservation.setPassengers(index, reservation.passengers);
    }
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

  void _applyTodayPreset(ReservationProvider reservation) {
    final now = DateTime.now();
    final departure = DateTime(now.year, now.month, now.day, now.hour + 2);
    setState(() {
      _tripType = 'Solo ida';
      _departureTime = TimeOfDay.fromDateTime(departure);
      _returnDate = null;
      _returnTime = null;
    });
    reservation.setBookingTripLabel('Solo ida');
    reservation.setGlobalStartDate(departure);
    reservation.setStartDate(0, departure);
    _normalizeRoutesForMode(reservation);
    _showMessage('Listo para una salida hoy con respuesta rapida.');
  }

  void _applyRoundTripPreset(ReservationProvider reservation) {
    final departureDate =
        reservation.routes.first.startDate ??
        reservation.startDate ??
        DateTime.now().add(const Duration(days: 1));
    setState(() {
      _tripType = 'Ida y vuelta';
      _departureTime ??= const TimeOfDay(hour: 9, minute: 0);
      _returnDate = DateTime(
        departureDate.year,
        departureDate.month,
        departureDate.day,
      ).add(const Duration(days: 1));
      _returnTime ??= const TimeOfDay(hour: 17, minute: 0);
    });
    reservation.setBookingTripLabel('Ida y vuelta');
    _normalizeRoutesForMode(reservation);
    _showMessage('Configuramos un viaje redondo para cerrar el itinerario.');
  }

  void _applyMultiCityPreset(ReservationProvider reservation) {
    setState(() {
      _tripType = 'Multidestino';
      _returnDate = null;
      _returnTime = null;
    });
    reservation.setBookingTripLabel('Multidestino');
    _normalizeRoutesForMode(reservation);
    if (reservation.routes.length < 2) {
      reservation.addRoute();
    }
    _showMessage('Activa los tramos que necesites para una ruta especial.');
  }

  void _applySuggestedDestination(
    ReservationProvider reservation,
    Airport airport,
  ) {
    if (_tripType == 'Multidestino') {
      final lastIndex = reservation.routes.length - 1;
      reservation.setToAirport(lastIndex, airport);
      if (lastIndex == 0 && reservation.routes.length < 2) {
        reservation.addRoute();
      }
      _showMessage('Agregamos ${airport.city} como siguiente parada.');
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
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (picked == null) return;
    reservation.setStartDate(index, picked);
  }

  Future<void> _pickReturnDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _returnDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
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
              _AirportPickerSheet(title: title, airports: reservation.airports),
    );

    if (airport == null) return;
    onSelected(airport);
  }

  String _airportPrimaryLabel(Airport? airport) {
    if (airport == null) return 'Seleccionar aeropuerto';
    return airport.city;
  }

  String? _airportSecondaryLabel(Airport? airport) {
    if (airport == null) return null;
    final parts = <String>[];
    final iata = airport.iata?.trim();
    if (iata != null && iata.isNotEmpty) {
      parts.add(iata.toUpperCase());
    }
    if (airport.name.trim().isNotEmpty) {
      parts.add(airport.name);
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  DateTime _mergeDateAndTime(DateTime date, TimeOfDay? time) {
    if (time == null) {
      return DateTime(date.year, date.month, date.day, 9);
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _QuickActionRail extends StatelessWidget {
  const _QuickActionRail({
    required this.onTodayTrip,
    required this.onRoundTrip,
    required this.onMultiCity,
  });

  final VoidCallback onTodayTrip;
  final VoidCallback onRoundTrip;
  final VoidCallback onMultiCity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 152,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _QuickActionCard(
            icon: Icons.flash_on_rounded,
            title: 'Salida hoy',
            subtitle: 'Prioriza velocidad y minima reposicion.',
            tint: const Color(0xFF143955),
            onTap: onTodayTrip,
          ),
          const SizedBox(width: 12),
          _QuickActionCard(
            icon: Icons.swap_calls_rounded,
            title: 'Round trip',
            subtitle: 'Salida y regreso dentro del mismo flujo.',
            tint: const Color(0xFF1B8F4D),
            onTap: onRoundTrip,
          ),
          const SizedBox(width: 12),
          _QuickActionCard(
            icon: Icons.travel_explore_rounded,
            title: 'Ruta especial',
            subtitle: 'Internacional o multicity con revision operativa.',
            tint: const Color(0xFFB46A00),
            onTap: onMultiCity,
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x0F141414)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: tint, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF5F564C),
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeIntroCard extends StatelessWidget {
  const _ModeIntroCard({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.tint,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              color: tint,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF141414),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF544D45),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedDestinationCard extends StatelessWidget {
  const _SuggestedDestinationCard({
    required this.airport,
    required this.isMultiCity,
    required this.onTap,
  });

  final Airport airport;
  final bool isMultiCity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final code = airport.iata?.trim().toUpperCase() ?? 'RUTA';
    final location = [
      airport.city,
      airport.state,
    ].whereType<String>().join(', ');

    return SizedBox(
      width: 164,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F3EC),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2D6C6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF9A6F28),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                airport.city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111111),
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF5F564C),
                  fontSize: 11,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isMultiCity ? 'Agregar parada' : 'Usar destino',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF151515),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteHeader extends StatelessWidget {
  const _RouteHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF7A5A20),
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _InlinePreferenceButton extends StatelessWidget {
  const _InlinePreferenceButton({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          foregroundColor: const Color(0xFF7A5A20),
          backgroundColor: const Color(0xFFF5EAD7),
          shape: const StadiumBorder(),
        ),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
    );
  }
}

class _PassengerRow extends StatelessWidget {
  const _PassengerRow({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = value == 1 ? '1 pasajero' : '$value pasajeros';

    return Row(
      children: [
        const Expanded(
          child: Text(
            'Pasajeros',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF171717),
            ),
          ),
        ),
        _PassengerButton(
          icon: Icons.remove_rounded,
          onTap: value <= 1 ? null : () => onChanged(value - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        _PassengerButton(
          icon: Icons.add_rounded,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _PassengerButton extends StatelessWidget {
  const _PassengerButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFFF0EBE2) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD8CCBB)),
        ),
        child: Icon(
          icon,
          size: 18,
          color:
              onTap == null ? const Color(0xFFB6AA9A) : const Color(0xFF5C5246),
        ),
      ),
    );
  }
}

class _MultiLegCard extends StatelessWidget {
  const _MultiLegCard({
    required this.index,
    required this.route,
    required this.onPickOrigin,
    required this.onPickDestination,
    required this.onPickDate,
    required this.onRemove,
    required this.formatDate,
  });

  final int index;
  final RouteModel route;
  final VoidCallback onPickOrigin;
  final VoidCallback onPickDestination;
  final VoidCallback onPickDate;
  final VoidCallback onRemove;
  final DateFormat formatDate;

  @override
  Widget build(BuildContext context) {
    return ConciergeCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Tramo ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          ConciergeField(
            label: 'Origen',
            value: _airportPrimary(route.fromAirport),
            secondaryValue: _airportSecondary(route.fromAirport),
            placeholder: 'Seleccionar aeropuerto',
            onTap: onPickOrigin,
          ),
          const SizedBox(height: 10),
          ConciergeField(
            label: 'Destino',
            value: _airportPrimary(route.toAirport),
            secondaryValue: _airportSecondary(route.toAirport),
            placeholder: 'Seleccionar aeropuerto',
            onTap: onPickDestination,
          ),
          const SizedBox(height: 10),
          ConciergeField(
            label: 'Fecha',
            value:
                route.startDate == null
                    ? 'dd/mm/aaaa'
                    : formatDate.format(route.startDate!),
            onTap: onPickDate,
            trailing: const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: Color(0xFF6B6258),
            ),
            placeholder: 'dd/mm/aaaa',
          ),
        ],
      ),
    );
  }

  String _airportPrimary(Airport? airport) {
    if (airport == null) return 'Seleccionar aeropuerto';
    return airport.city;
  }

  String? _airportSecondary(Airport? airport) {
    if (airport == null) return null;
    final parts = <String>[];
    if (airport.iata?.trim().isNotEmpty == true) {
      parts.add(airport.iata!.trim().toUpperCase());
    }
    if (airport.name.trim().isNotEmpty) {
      parts.add(airport.name);
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }
}

class _AirportPickerSheet extends StatefulWidget {
  const _AirportPickerSheet({required this.title, required this.airports});

  final String title;
  final List<Airport> airports;

  @override
  State<_AirportPickerSheet> createState() => _AirportPickerSheetState();
}

class _AirportPickerSheetState extends State<_AirportPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        widget.airports
            .where((airport) {
              final search = _query.trim().toUpperCase();
              if (search.isEmpty) return true;
              return airport.city.toUpperCase().contains(search) ||
                  airport.name.toUpperCase().contains(search) ||
                  (airport.iata ?? '').toUpperCase().contains(search);
            })
            .take(30)
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F3EA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6CABC),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar ciudad, aeropuerto o codigo',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemBuilder: (context, index) {
                    final airport = filtered[index];
                    final code =
                        airport.iata?.isNotEmpty == true ? airport.iata! : '--';

                    return ConciergeCard(
                      padding: const EdgeInsets.all(12),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          airport.city,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${airport.name}\n$code',
                          style: const TextStyle(height: 1.35),
                        ),
                        onTap: () => Navigator.pop(context, airport),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: filtered.length,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
