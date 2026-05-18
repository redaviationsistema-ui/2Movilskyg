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
  String _tripType = 'Ida';
  TimeOfDay? _departureTime;
  DateTime? _returnDate;
  TimeOfDay? _returnTime;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ReservationProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await provider.loadInitialData();
      if (!mounted) return;
      await provider.loadClientWorkspaceData(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reservation = context.watch<ReservationProvider>();
    final primaryRoute = reservation.routes.first;
    final recentRoutes = _recentRoutes(reservation).take(3).toList();

    return ClientMobileScreenShell(
      userInitial: widget.userInitial,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
        children: [
          const EyebrowLabel(label: 'Planificador de aviacion privada'),
          const SizedBox(height: 8),
          const Text(
            'Busca.\nReserva.\nVuela.',
            style: TextStyle(
              fontSize: 28,
              height: 0.95,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Entra, elige y reserva tu vuelo privado con control total desde el primer paso.',
            style: TextStyle(
              color: Color(0xFF5E5A53),
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          ConciergeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedTripSelector(
                  value: _tripType,
                  onChanged: (value) {
                    setState(() {
                      _tripType = value;
                    });
                    _normalizeRoutesForMode(reservation);
                  },
                ),
                const SizedBox(height: 14),
                ConciergeField(
                  label: 'Origen',
                  value: _airportLabel(primaryRoute.fromAirport),
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
                  value: _airportLabel(primaryRoute.toAirport),
                  onTap:
                      () => _pickAirport(
                        title: 'Selecciona destino',
                        onSelected:
                            (airport) => reservation.setToAirport(0, airport),
                      ),
                ),
                const SizedBox(height: 12),
                ConciergeField(
                  label: 'Fecha',
                  value:
                      primaryRoute.startDate == null
                          ? 'dd/mm/aaaa'
                          : _dateFormat.format(primaryRoute.startDate!),
                  onTap: () => _pickDateForRoute(reservation, 0),
                  trailing: const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: Color(0xFF6B6258),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _pickDepartureTime,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    side: const BorderSide(color: Color(0xFFE2D6C6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    foregroundColor: const Color(0xFF7A5A20),
                  ),
                  child: Text(
                    _departureTime == null
                        ? 'Agregar hora especifica'
                        : 'Hora ${_departureTime!.format(context)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (_tripType == 'Redondo') ...[
                  const SizedBox(height: 12),
                  ConciergeField(
                    label: 'Regreso',
                    value:
                        _returnDate == null
                            ? 'Seleccionar fecha de regreso'
                            : _dateFormat.format(_returnDate!),
                    onTap: _pickReturnDate,
                    trailing: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: Color(0xFF6B6258),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _pickReturnTime,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: const BorderSide(color: Color(0xFFE2D6C6)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _returnTime == null
                          ? 'Agregar hora de regreso'
                          : 'Regreso ${_returnTime!.format(context)}',
                    ),
                  ),
                ],
                if (_tripType == 'Multi-destino') ...[
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
                    label: const Text('Agregar destino'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      side: const BorderSide(color: Color(0xFFE2D6C6)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _PassengerRow(
                  value: reservation.passengers,
                  onChanged: reservation.setGlobalPassengers,
                ),
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
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
                              'Cotizar vuelo',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (reservation.isLoadingWorkspace && recentRoutes.isEmpty)
            const LoadingBand(text: 'Sincronizando rutas del cliente...')
          else if (recentRoutes.isNotEmpty) ...[
            for (final route in recentRoutes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SuggestedRouteCard(
                  route: route,
                  onTap: () => _applySuggestedRoute(route, reservation),
                ),
              ),
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

    if (_tripType == 'Redondo' && _returnDate == null) {
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

    if (_tripType == 'Ida') {
      while (reservation.routes.length > 1) {
        reservation.removeRoute(reservation.routes.length - 1);
      }
      return;
    }

    if (_tripType == 'Redondo') {
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

  void _applySuggestedRoute(
    Map<String, dynamic> routeData,
    ReservationProvider reservation,
  ) {
    final originText = routeData['origin']?.toString() ?? '';
    final destinationText = routeData['destination']?.toString() ?? '';
    final departureText =
        routeData['departure_datetime']?.toString() ??
        routeData['date']?.toString();

    final originAirport = _findAirport(originText, reservation.airports);
    final destinationAirport = _findAirport(
      destinationText,
      reservation.airports,
    );

    if (originAirport != null) {
      reservation.setFromAirport(0, originAirport);
    }
    if (destinationAirport != null) {
      reservation.setToAirport(0, destinationAirport);
    }

    if (departureText != null && departureText.isNotEmpty) {
      final parsed = DateTime.tryParse(departureText);
      if (parsed != null) {
        reservation.setStartDate(0, parsed);
      }
    }
  }

  Airport? _findAirport(String query, List<Airport> airports) {
    final normalized = query.trim().toUpperCase();
    if (normalized.isEmpty) return null;

    for (final airport in airports) {
      final city = airport.city.toUpperCase();
      final name = airport.name.toUpperCase();
      final iata = (airport.iata ?? '').toUpperCase();
      if (city == normalized || name == normalized || iata == normalized) {
        return airport;
      }
    }

    for (final airport in airports) {
      final city = airport.city.toUpperCase();
      final name = airport.name.toUpperCase();
      final iata = (airport.iata ?? '').toUpperCase();
      if (city.contains(normalized) ||
          name.contains(normalized) ||
          iata.contains(normalized)) {
        return airport;
      }
    }

    return null;
  }

  List<Map<String, dynamic>> _recentRoutes(ReservationProvider reservation) {
    return reservation.flightRequests.where((request) {
      final origin = request['origin']?.toString() ?? '';
      final destination = request['destination']?.toString() ?? '';
      return origin.isNotEmpty && destination.isNotEmpty;
    }).toList();
  }

  String _airportLabel(Airport? airport) {
    if (airport == null) return 'Seleccionar';
    final iata = airport.iata?.trim();
    if (iata != null && iata.isNotEmpty) {
      return '${airport.city} / $iata';
    }
    return airport.city;
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

class _PassengerRow extends StatelessWidget {
  const _PassengerRow({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Pasajeros',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF171717),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: value <= 1 ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        Text(
          '$value',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        IconButton(
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}

class _SuggestedRouteCard extends StatelessWidget {
  const _SuggestedRouteCard({required this.route, required this.onTap});

  final Map<String, dynamic> route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final origin = route['origin']?.toString() ?? 'Origen';
    final destination = route['destination']?.toString() ?? 'Destino';
    final aircraft =
        route['aircraft_model']?.toString() ??
        route['assigned_aircraft_model']?.toString() ??
        'Aeronave por asignar';
    final passengers =
        route['passengers']?.toString() ??
        route['passenger_count']?.toString() ??
        'N/D';
    final total =
        route['estimated_total']?.toString() ??
        route['final_price']?.toString() ??
        'Cotizacion privada';
    final note =
        route['notes']?.toString() ??
        route['workflow_status']?.toString() ??
        'Ruta real recuperada desde tu historial.';

    return ConciergeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ruta sugerida',
            style: TextStyle(
              color: Color(0xFF9A6F28),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$origin -> $destination',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Desde $total · $aircraft · $passengers pasajeros',
            style: const TextStyle(color: Color(0xFF4F4A43), height: 1.3),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: const TextStyle(color: Color(0xFF3A342D), height: 1.35),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF0EAE0),
                foregroundColor: const Color(0xFF171717),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Ver opcion'),
            ),
          ),
        ],
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
                'Destino ${index + 1}',
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
            value: _airportValue(route.fromAirport),
            onTap: onPickOrigin,
          ),
          const SizedBox(height: 10),
          ConciergeField(
            label: 'Destino',
            value: _airportValue(route.toAirport),
            onTap: onPickDestination,
          ),
          const SizedBox(height: 10),
          ConciergeField(
            label: 'Fecha',
            value:
                route.startDate == null
                    ? 'Seleccionar'
                    : formatDate.format(route.startDate!),
            onTap: onPickDate,
            trailing: const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: Color(0xFF6B6258),
            ),
          ),
        ],
      ),
    );
  }

  String _airportValue(Airport? airport) {
    if (airport == null) return 'Seleccionar';
    return airport.iata?.isNotEmpty == true
        ? '${airport.city} / ${airport.iata}'
        : airport.city;
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
