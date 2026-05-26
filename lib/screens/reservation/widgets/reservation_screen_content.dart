// Nota: este archivo concentra la composicion visual de la pantalla de
// reservacion y sus componentes reutilizables para evitar una vista monolitica.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/airport.dart';
import '../../../models/route_model.dart';
import '../../../providers/reservation_provider.dart';
import '../../cliente/widgets/client_mobile_flow_widgets.dart';

class ReservationScreenContent extends StatelessWidget {
  const ReservationScreenContent({
    super.key,
    required this.reservation,
    required this.primaryRoute,
    required this.suggestedAirports,
    required this.dateFormat,
    required this.tripType,
    required this.departureTime,
    required this.returnDate,
    required this.returnTime,
    required this.onTodayTrip,
    required this.onRoundTrip,
    required this.onMultiCity,
    required this.onTripTypeChanged,
    required this.onPickOrigin,
    required this.onPickDestination,
    required this.onPickPrimaryDate,
    required this.onPickDepartureTime,
    required this.onPickReturnDate,
    required this.onPickReturnTime,
    required this.onPickRouteOrigin,
    required this.onPickRouteDestination,
    required this.onPickRouteDate,
    required this.onRemoveRoute,
    required this.onAddRoute,
    required this.onApplySuggestedDestination,
    required this.onPreview,
  });

  final ReservationProvider reservation;
  final RouteModel primaryRoute;
  final List<Airport> suggestedAirports;
  final DateFormat dateFormat;
  final String tripType;
  final TimeOfDay? departureTime;
  final DateTime? returnDate;
  final TimeOfDay? returnTime;
  final VoidCallback onTodayTrip;
  final VoidCallback onRoundTrip;
  final VoidCallback onMultiCity;
  final ValueChanged<String> onTripTypeChanged;
  final VoidCallback onPickOrigin;
  final VoidCallback onPickDestination;
  final VoidCallback onPickPrimaryDate;
  final VoidCallback onPickDepartureTime;
  final VoidCallback onPickReturnDate;
  final VoidCallback onPickReturnTime;
  final ValueChanged<int> onPickRouteOrigin;
  final ValueChanged<int> onPickRouteDestination;
  final ValueChanged<int> onPickRouteDate;
  final ValueChanged<int> onRemoveRoute;
  final VoidCallback onAddRoute;
  final ValueChanged<Airport> onApplySuggestedDestination;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F7F7),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 108),
        children: [
          const Text(
            'RED AVIATION',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.8,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Reserva un jet privado\nen minutos',
            style: TextStyle(
              fontSize: 38,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.3,
              color: Color(0xFF050505),
            ),
          ),
        
          const SizedBox(height: 26),
          ConciergeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedTripSelector(
                  value: tripType,
                  onChanged: onTripTypeChanged,
                ),
                if (tripType == 'Ida y vuelta') ...[
                  const SizedBox(height: 16),
                  const ModeIntroCard(
                    eyebrow: 'Viaje redondo',
                    title: 'Define salida y regreso en un mismo flujo ejecutivo.',
                    subtitle:
                        'Ideal para juntas, inspecciones o regreso el mismo dia con control total del itinerario.',
                    tint: Color(0xFF111111),
                  ),
                ] else if (tripType == 'Multidestino') ...[
                  const SizedBox(height: 16),
                  const ModeIntroCard(
                    eyebrow: 'Ruta multi-destino',
                    title: 'Construye una gira privada tramo por tramo.',
                    subtitle:
                        'Perfecto para roadshows, visitas ejecutivas y agendas que combinan varias ciudades.',
                    tint: Color(0xFF111111),
                  ),
                ],
                const SizedBox(height: 16),
                if (tripType == 'Multidestino') ...[
                  const RouteHeader(title: 'Tramo 1'),
                  const SizedBox(height: 12),
                ],
                ConciergeField(
                  label: 'Origen',
                  value: _airportPrimaryLabel(primaryRoute.fromAirport),
                  secondaryValue: _airportSecondaryLabel(
                    primaryRoute.fromAirport,
                  ),
                  placeholder: 'Seleccionar aeropuerto',
                  onTap: onPickOrigin,
                ),
                const SizedBox(height: 12),
                ConciergeField(
                  label: 'Destino',
                  value: _airportPrimaryLabel(primaryRoute.toAirport),
                  secondaryValue: _airportSecondaryLabel(primaryRoute.toAirport),
                  placeholder: 'Seleccionar aeropuerto',
                  onTap: onPickDestination,
                ),
                const SizedBox(height: 12),
                ConciergeField(
                  label: 'Salida',
                  value:
                      primaryRoute.startDate == null
                          ? 'Seleccionar fecha'
                          : dateFormat.format(primaryRoute.startDate!),
                  onTap: onPickPrimaryDate,
                  trailing: const Icon(
                    Icons.calendar_today_outlined,
                    size: 24,
                    color: Color(0xFF111111),
                  ),
                  placeholder: 'Seleccionar fecha',
                ),
                const SizedBox(height: 8),
                InlinePreferenceButton(
                  title:
                      departureTime == null
                          ? 'Agregar hora'
                          : 'Hora de salida: ${departureTime!.format(context)}',
                  onTap: onPickDepartureTime,
                ),
                if (tripType == 'Ida y vuelta') ...[
                  const SizedBox(height: 14),
                  ConciergeField(
                    label: 'Fecha de regreso',
                    value:
                        returnDate == null
                            ? 'dd/mm/aaaa'
                            : dateFormat.format(returnDate!),
                    onTap: onPickReturnDate,
                    trailing: const Icon(
                      Icons.calendar_today_outlined,
                      size: 24,
                      color: Color(0xFF111111),
                    ),
                    placeholder: 'dd/mm/aaaa',
                  ),
                  const SizedBox(height: 8),
                  InlinePreferenceButton(
                    title:
                        returnTime == null
                            ? 'Agregar hora de regreso'
                            : 'Hora de regreso: ${returnTime!.format(context)}',
                    onTap: onPickReturnTime,
                  ),
                ],
                if (tripType == 'Multidestino') ...[
                  const SizedBox(height: 14),
                  ...List.generate(
                    reservation.routes.length - 1,
                    (extraIndex) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MultiLegCard(
                        index: extraIndex + 1,
                        route: reservation.routes[extraIndex + 1],
                        onPickOrigin: () => onPickRouteOrigin(extraIndex + 1),
                        onPickDestination:
                            () => onPickRouteDestination(extraIndex + 1),
                        onPickDate: () => onPickRouteDate(extraIndex + 1),
                        onRemove: () => onRemoveRoute(extraIndex + 1),
                        formatDate: dateFormat,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: primaryRoute.toAirport == null ? null : onAddRoute,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Agregar tramo'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      side: const BorderSide(color: Color(0xFF111111)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      foregroundColor: const Color(0xFF111111),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        reservation.isLoadingQuotePreview ? null : onPreview,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF050505),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(64),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
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
                              'Buscar aeronaves disponibles',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                letterSpacing: -0.2,
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cotización estimada. Sujeta a disponibilidad, FBO, permisos y operación.',
                  style: TextStyle(
                    color: Color(0xFF6F6F6F),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
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
                  color: Color(0xFF111111),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _airportPrimaryLabel(Airport? airport) {
    if (airport == null) return 'Seleccionar aeropuerto';
    return airport.city;
  }

  static String? _airportSecondaryLabel(Airport? airport) {
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
}

class QuickActionRail extends StatelessWidget {
  const QuickActionRail({
    super.key,
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
          QuickActionCard(
            icon: Icons.flash_on_rounded,
            title: 'Vuelo inmediato',
            subtitle: 'Disponibilidad prioritaria para salir hoy.',
            tint: const Color(0xFF111111),
            onTap: onTodayTrip,
          ),
          const SizedBox(width: 12),
          QuickActionCard(
            icon: Icons.swap_calls_rounded,
            title: 'Ida y vuelta',
            subtitle: 'Agenda ejecutiva con regreso coordinado.',
            tint: const Color(0xFF111111),
            onTap: onRoundTrip,
          ),
          const SizedBox(width: 12),
          QuickActionCard(
            icon: Icons.travel_explore_rounded,
            title: 'Multidestino',
            subtitle: 'Ruta privada con varias ciudades.',
            tint: const Color(0xFF111111),
            onTap: onMultiCity,
          ),
        ],
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    super.key,
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
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE5E5E5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF050505),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModeIntroCard extends StatelessWidget {
  const ModeIntroCard({
    super.key,
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
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E1E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF111111),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF050505),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF606060),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class SuggestedDestinationCard extends StatelessWidget {
  const SuggestedDestinationCard({
    super.key,
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
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5E5E5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
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
                  color: Color(0xFF111111),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
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
                  color: Color(0xFF050505),
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isMultiCity ? 'Agregar parada' : 'Usar destino',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF050505),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RouteHeader extends StatelessWidget {
  const RouteHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF111111),
        fontWeight: FontWeight.w900,
        fontSize: 12,
        letterSpacing: 0.8,
      ),
    );
  }
}

class InlinePreferenceButton extends StatelessWidget {
  const InlinePreferenceButton({
    super.key,
    required this.title,
    required this.onTap,
  });

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
          foregroundColor: const Color(0xFF050505),
          backgroundColor: const Color(0xFFF1F1F1),
          shape: const StadiumBorder(),
        ),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      ),
    );
  }
}

class PassengerRow extends StatelessWidget {
  const PassengerRow({super.key, required this.value, required this.onChanged});

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
              fontWeight: FontWeight.w900,
              color: Color(0xFF050505),
            ),
          ),
        ),
        PassengerButton(
          icon: Icons.remove_rounded,
          onTap: value <= 1 ? null : () => onChanged(value - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Color(0xFF050505),
            ),
          ),
        ),
        PassengerButton(
          icon: Icons.add_rounded,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class PassengerButton extends StatelessWidget {
  const PassengerButton({super.key, required this.icon, required this.onTap});

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
          color: onTap == null ? const Color(0xFFF1F1F1) : const Color(0xFF050505),
          shape: BoxShape.circle,
          border: Border.all(
            color: onTap == null ? const Color(0xFFE0E0E0) : const Color(0xFF050505),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? const Color(0xFFB0B0B0) : Colors.white,
        ),
      ),
    );
  }
}

class MultiLegCard extends StatelessWidget {
  const MultiLegCard({
    super.key,
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
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF050505),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
                color: const Color(0xFF111111),
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
              color: Color(0xFF111111),
            ),
            placeholder: 'dd/mm/aaaa',
          ),
        ],
      ),
    );
  }

  static String _airportPrimary(Airport? airport) {
    if (airport == null) return 'Seleccionar aeropuerto';
    return airport.city;
  }

  static String? _airportSecondary(Airport? airport) {
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

class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
        color: Color(0xFF111111),
      ),
    );
  }
}

class ReservationTextField extends StatefulWidget {
  const ReservationTextField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.hintText,
    required this.onChanged,
  });

  final String label;
  final String initialValue;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  State<ReservationTextField> createState() => _ReservationTextFieldState();
}

class _ReservationTextFieldState extends State<ReservationTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant ReservationTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      minLines: 1,
      maxLines: 2,
      style: const TextStyle(
        color: Color(0xFF050505),
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        labelStyle: const TextStyle(
          color: Color(0xFF444444),
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF9A9A9A),
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE1E1E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE1E1E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFF050505),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}