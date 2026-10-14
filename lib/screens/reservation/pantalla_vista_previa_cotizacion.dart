import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/billable_hours_formatter.dart';
import '../../core/cliente_api.dart';
import '../../core/quote_price_formatter.dart';
import '../../models/aeropuerto.dart';
import '../../models/modelo_ruta.dart';
import '../../providers/proveedor_reservaciones.dart';
import '../../widgets/maps/itinerary_airport_map.dart';
import 'pantalla_exito.dart';

class ItinerarySummaryScreen extends StatelessWidget {
  const ItinerarySummaryScreen({
    super.key,
    required this.tripType,
    required this.onRequestQuote,
    required this.onEditLeg,
    this.enableMapVectorProvider = true,
  });

  final String tripType;
  final VoidCallback onRequestQuote;
  final ValueChanged<int> onEditLeg;
  final bool enableMapVectorProvider;

  @override
  Widget build(BuildContext context) {
    final reservation = context.watch<ReservationProvider>();
    final dates =
        reservation.routes
            .map((route) => route.startDate)
            .whereType<DateTime>()
            .toList()
          ..sort();
    final dateRange =
        dates.isEmpty
            ? 'Por definir'
            : dates.length == 1 ||
                (dates.first.year == dates.last.year &&
                    dates.first.month == dates.last.month &&
                    dates.first.day == dates.last.day)
            ? _formatCalendarDate(dates.first)
            : '${_formatCalendarDate(dates.first)} – ${_formatCalendarDate(dates.last)}';

    return Scaffold(
      backgroundColor: const Color(0xFF07111D),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _SummaryExecutiveHeader(
              topInset: MediaQuery.paddingOf(context).top,
              onBack: () {
                final navigator = Navigator.of(context);
                if (navigator.canPop()) navigator.pop(-1);
              },
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('itinerary-summary-content'),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                children: [
                  _SummaryGeneralInfo(
                    tripType:
                        reservation.bookingTripLabel.trim().isEmpty
                            ? tripType
                            : reservation.bookingTripLabel,
                    routeCount: reservation.routes.length,
                    dateRange: dateRange,
                    passengers: reservation.passengers,
                  ),
                  const SizedBox(height: 10),
                  _ItineraryMapPreviewCard(
                    reservation: reservation,
                    enableVectorProvider: enableMapVectorProvider,
                    isSummary: true,
                  ),
                  const SizedBox(height: 24),
                  _ItineraryLegList(
                    routes: reservation.routes,
                    onEditLeg: onEditLeg,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF07111D),
                  border: Border(top: BorderSide(color: Color(0xFF263448))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    key: const ValueKey('request-itinerary-quote'),
                    onPressed:
                        reservation.isLoadingQuotePreview
                            ? null
                            : onRequestQuote,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD9B25F),
                      foregroundColor: const Color(0xFF101C2D),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (reservation.isLoadingQuotePreview)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF101C2D),
                            ),
                          )
                        else
                          const Icon(Icons.flight_takeoff_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Center(
                            child: Text(
                              reservation.isLoadingQuotePreview
                                  ? 'Solicitando cotización…'
                                  : 'Solicitar cotización',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.arrow_forward_rounded, size: 19),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')} '
        '${_spanishMonths[value.month - 1]} · '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  static String _formatCalendarDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')} '
        '${_spanishMonths[value.month - 1]} '
        '${value.year}';
  }

  static const _spanishMonths = [
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
}

class _SummaryExecutiveHeader extends StatelessWidget {
  const _SummaryExecutiveHeader({
    required this.topInset,
    required this.onBack,
  });

  final double topInset;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final extraTextScaleHeight = (textScale - 1).clamp(0.0, 2.0) * 24;
    return SizedBox(
      key: const ValueKey('itinerary-summary-header'),
      height: 152 + topInset + extraTextScaleHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/login/image.png',
            key: const ValueKey('itinerary-summary-jet-image'),
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC071321),
                  Color(0xC9071321),
                  Color(0xF2071321),
                  Color(0xFF07111D),
                ],
                stops: [0, .38, .78, 1],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, topInset + 4, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SummaryIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Regresar al formulario',
                      onPressed: onBack,
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Resumen de itinerario',
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: textScale > 1.25 ? 21 : 23,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Revisa tu recorrido antes de cotizar.',
                      maxLines: 1,
                      style: TextStyle(
                        color: Color(0xFFD0D8E2),
                        fontSize: textScale > 1.25 ? 12 : 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 18,
            right: 18,
            bottom: 0,
            child: ColoredBox(
              color: Color(0x66D9B25F),
              child: SizedBox(height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryIconButton extends StatelessWidget {
  const _SummaryIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: const Color(0xFFD9B25F),
        backgroundColor: const Color(0xFF17253A),
      ),
      icon: Icon(icon),
    );
  }
}

class _SummaryGeneralInfo extends StatelessWidget {
  const _SummaryGeneralInfo({
    required this.tripType,
    required this.routeCount,
    required this.dateRange,
    required this.passengers,
  });

  final String tripType;
  final int routeCount;
  final String dateRange;
  final int passengers;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final compact = constraints.maxWidth < 560 || textScale > 1.2;
        final metricSpecs = [
          (
            key: 'mode',
            icon: Icons.route_rounded,
            label: compact ? 'TIPO' : 'MODALIDAD',
            value: tripType,
            compactValue: _compactTripType(tripType),
          ),
          (
            key: 'legs',
            icon: Icons.alt_route_rounded,
            label: 'TRAMOS',
            value: '$routeCount ${routeCount == 1 ? 'tramo' : 'tramos'}',
            compactValue: '$routeCount ${routeCount == 1 ? 'tramo' : 'tramos'}',
          ),
          (
            key: 'date',
            icon: Icons.calendar_month_rounded,
            label: 'FECHA',
            value: dateRange,
            compactValue: _compactDateRange(dateRange),
          ),
          (
            key: 'passengers',
            icon: Icons.people_alt_rounded,
            label: compact ? 'PAX' : 'PASAJEROS',
            value: '$passengers ${passengers == 1 ? 'pasajero' : 'pasajeros'}',
            compactValue: '$passengers pax',
          ),
        ];
        final metrics = [
          for (final spec in metricSpecs)
            _SummaryMetric(
              key: ValueKey('summary-metric-${spec.key}'),
              icon: spec.icon,
              label: spec.label,
              value: compact ? spec.compactValue : spec.value,
              fullValue: spec.value,
              compact: compact,
            ),
        ];
        final minimumColumnWidth = 62 * textScale;
        final requiredScrollableWidth =
            minimumColumnWidth * metrics.length + (metrics.length - 1) * 5 + 8;
        final shouldScroll = constraints.maxWidth < requiredScrollableWidth;
        const flexes = [26, 19, 31, 24];

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF071321),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child:
              shouldScroll
                  ? SingleChildScrollView(
                    key: const ValueKey('summary-metrics-scroll'),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (
                          var index = 0;
                          index < metrics.length;
                          index++
                        ) ...[
                          SizedBox(
                            width: minimumColumnWidth,
                            child: metrics[index],
                          ),
                          if (index < metrics.length - 1)
                            const _SummaryMetricSeparator(),
                        ],
                      ],
                    ),
                  )
                  : Row(
                    children: [
                      for (var index = 0; index < metrics.length; index++) ...[
                        Expanded(flex: flexes[index], child: metrics[index]),
                        if (index < metrics.length - 1)
                          const _SummaryMetricSeparator(),
                      ],
                    ],
                  ),
        );
      },
    );
  }

  static String _compactTripType(String value) {
    return switch (value.trim().toLowerCase()) {
      'ida y vuelta' => 'Ida/vuelta',
      'multidestino' || 'multi-destino' => 'Multi',
      _ => value,
    };
  }

  static String _compactDateRange(String value) {
    return value.replaceAllMapped(
      RegExp(r'\b(\d{2})\s+([a-z]{3})\s+(20\d{2})\b', caseSensitive: false),
      (match) => '${match[1]} ${match[2]} ${match[3]!.substring(2)}',
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.fullValue,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final String value;
  final String fullValue;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: fullValue,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 10,
          vertical: 6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFD6B477), size: compact ? 15 : 18),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF9DAABD),
                fontSize: compact ? 8.5 : 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: compact ? .35 : .8,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFF5F7FA),
                fontSize: compact ? 11.5 : 13,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetricSeparator extends StatelessWidget {
  const _SummaryMetricSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: Colors.white.withValues(alpha: .12),
    );
  }
}

class _ItineraryLegList extends StatelessWidget {
  const _ItineraryLegList({required this.routes, required this.onEditLeg});

  final List<RouteModel> routes;
  final ValueChanged<int> onEditLeg;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'DETALLE DE TRAMOS',
            style: TextStyle(
              color: Color(0xFF9CAABD),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ),
        for (var index = 0; index < routes.length; index++)
          _ItineraryLegRow(
            route: routes[index],
            index: index,
            onEdit: () => onEditLeg(index),
            showConnector: index < routes.length - 1,
          ),
      ],
    );
  }
}

class _ItineraryLegRow extends StatelessWidget {
  const _ItineraryLegRow({
    required this.route,
    required this.index,
    required this.onEdit,
    required this.showConnector,
  });

  final RouteModel route;
  final int index;
  final VoidCallback onEdit;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final date = route.startDate;
    final dateLabel =
        date == null
            ? 'Fecha y hora por definir'
            : ItinerarySummaryScreen._formatDate(date);

    final originCity = _city(route.fromAirport, route.fromCity);
    final destinationCity = _city(route.toAirport, route.toCity);

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD9B25F).withValues(alpha: .8),
                ),
              ),
              child: Text(
                '${index + 1}'.padLeft(2, '0'),
                style: const TextStyle(
                  color: Color(0xFFD9B25F),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_code(route.fromAirport)}  →  ${_code(route.toAirport)}',
                          style: const TextStyle(
                            color: Color(0xFFF4F6FA),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          dateLabel,
                          style: const TextStyle(
                            color: Color(0xFFB8C2D0),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (originCity != null || destinationCity != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            '${originCity ?? _code(route.fromAirport)}  →  '
                            '${destinationCity ?? _code(route.toAirport)}',
                            style: const TextStyle(
                              color: Color(0xFF9CAABD),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    key: ValueKey('edit-itinerary-leg-$index'),
                    tooltip: 'Editar tramo ${index + 1}',
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFFD9B25F),
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showConnector)
          Padding(
            padding: const EdgeInsets.only(left: 13, top: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 1,
                height: 18,
                color: const Color(0xFF9CAABD).withValues(alpha: .32),
              ),
            ),
          ),
      ],
    );
  }

  static String? _city(Airport? airport, String? routeCity) {
    final city = airport?.city.trim() ?? '';
    if (city.isNotEmpty && city != r'\N') return city;
    final name = airport?.name.trim() ?? '';
    if (name.isNotEmpty && name != r'\N') return name;
    final fallback = routeCity?.trim() ?? '';
    if (fallback.isNotEmpty && fallback != r'\N') return fallback;
    return null;
  }

  static String _code(Airport? airport) {
    if (airport == null) return '---';
    return airport.iata?.trim().isNotEmpty == true && airport.iata != r'\N'
        ? airport.iata!.trim().toUpperCase()
        : airport.icao?.trim().isNotEmpty == true && airport.icao != r'\N'
        ? airport.icao!.trim().toUpperCase()
        : '---';
  }
}

class QuotePreviewScreen extends StatelessWidget {
  const QuotePreviewScreen({
    super.key,
    this.onReservationCreated,
    this.enableMapVectorProvider = true,
  });

  final ValueChanged<String?>? onReservationCreated;
  final bool enableMapVectorProvider;

  Future<void> confirm(BuildContext context) async {
    final reservation = context.read<ReservationProvider>();
    final quote = reservation.selectedQuoteMatch;

    if (quote == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay una cotizacion real seleccionada.'),
        ),
      );
      return;
    }

    final primaryRoute = reservation.routes.first;
    final origin =
        primaryRoute.fromAirport?.iata ?? primaryRoute.fromAirport?.name ?? '';
    final destination =
        primaryRoute.toAirport?.iata ?? primaryRoute.toAirport?.name ?? '';
    final departure = reservation.startDate ?? primaryRoute.startDate;

    if (origin.isEmpty || destination.isEmpty || departure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faltan datos base para crear la solicitud.'),
        ),
      );
      return;
    }

    if (quote['is_available'] == false) {
      reservation.handleAircraftUnavailable(quote);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (quote['availability_reason']?.toString().trim().isNotEmpty ??
                    false)
                ? quote['availability_reason'].toString()
                : 'Disponibilidad actualizada. Esta aeronave ya no esta disponible. Te mostramos otras opciones para tu vuelo.',
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const Dialog(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('Creando solicitud...'),
                ],
              ),
            ),
          ),
    );

    try {
      final response = await reservation.createFlightRequestForMatch(quote);
      final createdId = reservation.createdFlightRequestIdFromResponse(
        response,
      );
      await reservation.loadClientWorkspaceData(force: true);
      reservation.rememberCreatedFlightRequest(response);

      if (!context.mounted) return;

      Navigator.pop(context);
      if (onReservationCreated != null) {
        reservation.resetForm();
        onReservationCreated!(createdId);
        return;
      }

      reservation.resetForm();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SuccessScreen()),
      );
    } on ApiException catch (error) {
      if (context.mounted) Navigator.pop(context);

      if (error.isAircraftAvailabilityConflict) {
        reservation.handleAircraftUnavailable({...quote, ...?error.payload});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Disponibilidad actualizada. La aeronave seleccionada ya no se encuentra disponible. Te mostramos otras opciones disponibles para tu vuelo.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear la solicitud: ${error.message}'),
        ),
      );
    } catch (error) {
      if (context.mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear la solicitud: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reservation = context.watch<ReservationProvider>();
    final quote = reservation.selectedQuoteMatch;

    if (quote == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vista previa de cotizacion')),
        body: const Center(
          child: Text('No hay una cotizacion real disponible.'),
        ),
      );
    }

    final aircraft =
        (quote['aircraft_name'] ?? quote['model'] ?? '-').toString();
    final total = formatQuotePriceLabel(quote);
    final resolvedTime = resolveQuoteDisplayTime(quote).time;
    final billableHours =
        shouldDisplayBackendBillableHours(quote)
            ? extractBackendBillableHours(quote)
            : null;
    final formattedTime = formatBillableHoursLabel(billableHours);
    final time =
        resolvedTime.isNotEmpty && resolvedTime != '0 h 00 min'
            ? resolvedTime
            : formattedTime.isNotEmpty
            ? formattedTime
            : 'Por confirmar';
    final backendBillableLabel =
        formattedTime.isNotEmpty
            ? 'Horas cobrables backend: $formattedTime'
            : '';

    final cabin = (quote['cabin'] ?? 'Jet privado').toString();
    final capacity = (quote['capacity'] ?? 'N/D').toString();
    final providerName =
        ((quote['provider'] is Map)
            ? quote['provider']['company_name']?.toString()
            : null) ??
        quote['provider_name']?.toString() ??
        'Proveedor asignado por sistema';
    final breakdown =
        quote['pricing_breakdown'] is Map
            ? Map<String, dynamic>.from(quote['pricing_breakdown'] as Map)
            : <String, dynamic>{};
    final breakdownBillableHours =
        breakdown['final_billable_hours'] ??
        breakdown['billable_hours'] ??
        breakdown['billableHours'] ??
        '-';
    final subtotal =
        breakdown['subtotal'] ??
        breakdown['subtotal_before_multipliers'] ??
        '-';
    final fuel =
        breakdown['fuel'] ??
        breakdown['fuel_cost'] ??
        breakdown['fuel_surcharge'] ??
        '-';
    final repositioning =
        breakdown['repositioning'] ?? breakdown['repositioning_fee'] ?? '-';
    final overnight =
        breakdown['overnight'] ?? breakdown['overnight_fee'] ?? '-';
    final breakdownTotal = breakdown['total'] ?? quote['total'] ?? '-';
    final packageLabel = reservation.selectedPriorityLabel;
    final preference =
        reservation.preference.trim().isEmpty
            ? 'Sin preferencia especial'
            : reservation.preference.trim();
    final pets =
        reservation.pets.trim().isEmpty
            ? 'Sin mascotas registradas'
            : reservation.pets.trim();
    final baggage =
        reservation.specialBaggage.trim().isEmpty
            ? 'Sin equipaje especial'
            : reservation.specialBaggage.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Vista previa de cotizacion')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Cotizacion real',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Esta pantalla ya consume el preview del backend antes de crear la solicitud.',
          ),
          const SizedBox(height: 24),
          _ItineraryMapPreviewCard(
            reservation: reservation,
            enableVectorProvider: enableMapVectorProvider,
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aircraft,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('$cabin · $capacity pasajeros'),
                  const SizedBox(height: 8),
                  Text('Proveedor: $providerName'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _PriceBlock(label: 'Total', value: total),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PriceBlock(label: 'Tiempo', value: time),
                      ),
                    ],
                  ),
                  if (backendBillableLabel.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _BackendBillableHoursChip(label: backendBillableLabel),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaPill(label: 'Paquete', value: packageLabel),
                      _MetaPill(
                        label: 'Tipo de viaje',
                        value: reservation.currentTripTypeLabel,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Preferencias del cliente',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _LineItem(label: 'Preferencia', value: preference),
                  _LineItem(label: 'Mascotas', value: pets),
                  _LineItem(label: 'Equipaje especial', value: baggage),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (breakdown.isNotEmpty) ...[
            const Text(
              'Desglose',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _LineItem(
                      label: 'Horas billables',
                      value: '$breakdownBillableHours',
                    ),
                    _LineItem(label: 'Subtotal', value: '\$$subtotal'),
                    _LineItem(label: 'Combustible', value: '\$$fuel'),
                    _LineItem(
                      label: 'Repositioning',
                      value: '\$$repositioning',
                    ),
                    _LineItem(label: 'Overnight', value: '\$$overnight'),
                    _LineItem(label: 'Total', value: '\$$breakdownTotal'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => confirm(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: const Color(0xFF10253A),
              ),
              child: const Text('Crear solicitud real'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItineraryMapPreviewCard extends StatelessWidget {
  const _ItineraryMapPreviewCard({
    required this.reservation,
    required this.enableVectorProvider,
    this.isSummary = false,
  });

  final ReservationProvider reservation;
  final bool enableVectorProvider;
  final bool isSummary;

  @override
  Widget build(BuildContext context) {
    if (!isSummary) {
      return Card(
        color: const Color(0xFF111E30),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF354257)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mapa de tu recorrido',
                style: TextStyle(
                  color: Color(0xFFF4F6FA),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Visualiza los aeropuertos seleccionados.',
                style: TextStyle(
                  color: Color(0xFFB8C2D0),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ItineraryAirportMap(
                routes: reservation.routes,
                airportCatalog: reservation.airports,
                height: 230,
                enableVectorProvider: enableVectorProvider,
              ),
              const SizedBox(height: 8),
              const Text(
                'Recorrido ilustrativo. No representa una ruta aérea autorizada.',
                style: TextStyle(
                  color: Color(0xFFB8C2D0),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Selector<ReservationProvider, _SummaryMapSelection>(
      selector: (_, provider) => _SummaryMapSelection.fromProvider(provider),
      shouldRebuild: (previous, next) => previous.signature != next.signature,
      builder: (context, selection, _) => _buildSummaryMap(context, selection),
    );
  }

  Widget _buildSummaryMap(
    BuildContext context,
    _SummaryMapSelection selection,
  ) {
    final mapHeight =
        (MediaQuery.sizeOf(context).height * .32)
            .clamp(230.0, 300.0)
            .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.map_outlined, color: Color(0xFFD9B25F), size: 16),
            SizedBox(width: 7),
            Text(
              'RECORRIDO',
              style: TextStyle(
                color: Color(0xFFD4DCE6),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ItineraryAirportMap(
            routes: selection.routes,
            airportCatalog: selection.airportCatalog,
            height: mapHeight,
            enableVectorProvider: enableVectorProvider,
            showControls: true,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ruta ilustrativa · No válida para navegación aérea.',
          style: TextStyle(
            color: Color(0xFF9CAABD),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SummaryMapSelection {
  const _SummaryMapSelection({
    required this.routes,
    required this.airportCatalog,
    required this.signature,
  });

  final List<RouteModel> routes;
  final List<Airport> airportCatalog;
  final String signature;

  factory _SummaryMapSelection.fromProvider(ReservationProvider provider) {
    String airportSignature(Airport? airport) {
      if (airport == null) return '-';
      return '${airport.id}:${airport.iata}:${airport.icao}:'
          '${airport.lat}:${airport.lng}:${airport.name}:${airport.city}';
    }

    final routeSignature = provider.routes
        .map(
          (route) =>
              '${airportSignature(route.fromAirport)}>'
              '${airportSignature(route.toAirport)}',
        )
        .join('|');
    return _SummaryMapSelection(
      routes: provider.routes,
      airportCatalog: provider.airports,
      signature:
          '${identityHashCode(provider.airports)}:'
          '${provider.airports.length}:$routeSignature',
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF607080))),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF10253A),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackendBillableHoursChip extends StatelessWidget {
  const _BackendBillableHoursChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFD8B15D).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFD8B15D).withValues(alpha: .32),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: Color(0xFFB8860B),
            size: 13,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6F4E12),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFF10253A),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
