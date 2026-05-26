// Nota: este archivo coordina el estado y las acciones del flujo de
// reservacion; la UI detallada vive en componentes separados.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/airport.dart';
import '../../providers/reservation_provider.dart';
import '../cliente/widgets/client_mobile_flow_widgets.dart';
import 'quote_preview_screen.dart';
import 'widgets/airport_picker_sheet.dart';
import 'widgets/reservation_screen_content.dart';

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
      child: ReservationScreenContent(
        reservation: reservation,
        primaryRoute: primaryRoute,
        suggestedAirports: suggestedAirports,
        dateFormat: _dateFormat,
        tripType: _tripType,
        departureTime: _departureTime,
        returnDate: _returnDate,
        returnTime: _returnTime,
        onTodayTrip: () => _applyTodayPreset(reservation),
        onRoundTrip: () => _applyRoundTripPreset(reservation),
        onMultiCity: () => _applyMultiCityPreset(reservation),
        onTripTypeChanged: (value) {
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
        onPickRouteOrigin:
            (index) => _pickAirport(
              title: 'Origen tramo ${index + 1}',
              onSelected:
                  (airport) => reservation.setFromAirport(index, airport),
            ),
        onPickRouteDestination:
            (index) => _pickAirport(
              title: 'Destino tramo ${index + 1}',
              onSelected: (airport) => reservation.setToAirport(index, airport),
            ),
        onPickRouteDate: (index) => _pickDateForRoute(reservation, index),
        onRemoveRoute: reservation.removeRoute,
        onAddRoute: reservation.addRoute,
        onApplySuggestedDestination:
            (airport) => _applySuggestedDestination(reservation, airport),
        onPreview: () => _handlePreview(reservation),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
