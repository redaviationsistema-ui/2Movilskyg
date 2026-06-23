// Nota: este archivo concentra la composicion visual de la pantalla de
// reservacion y sus componentes reutilizables para evitar una vista monolitica.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/aeropuerto.dart';
import '../../../models/modelo_ruta.dart';
import '../../../providers/proveedor_reservaciones.dart';
import '../../cliente/tema_cliente.dart';
import '../../cliente/widgets/widgets_flujo_movil_cliente.dart';

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
    required this.hasActiveMembership,
    required this.remainingFreeQuotes,
    required this.onTodayTrip,
    required this.onRoundTrip,
    required this.onMultiCity,
    required this.onOpenMembership,
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
  final bool hasActiveMembership;
  final int remainingFreeQuotes;
  final VoidCallback onTodayTrip;
  final VoidCallback onRoundTrip;
  final VoidCallback onMultiCity;
  final VoidCallback onOpenMembership;
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
    final palette = context.clientPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final needsCommercialAccess =
        !hasActiveMembership && remainingFreeQuotes <= 0;
    final isPrimaryFormReady =
        primaryRoute.fromAirport != null &&
        primaryRoute.toAirport != null &&
        primaryRoute.startDate != null;

    return Container(
      color: palette.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 148),
        children: [
          const _HeroAccent(),
          const SizedBox(height: 4),
          Text(
            'Cotiza tu vuelo privado',
            style: TextStyle(
              fontSize: 24,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.9,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Selecciona ruta, fecha y pasajeros para ver aeronaves disponibles.',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (needsCommercialAccess) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surfaceSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: palette.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prueba gratuita consumida',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tu siguiente paso es activar el acceso comercial para poder reservar, firmar contrato y pagar el vuelo.',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onOpenMembership,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('Activar acceso comercial'),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          ConciergeCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FormSectionHeader(),
                const SizedBox(height: 12),
                SegmentedTripSelector(
                  value: tripType,
                  onChanged: onTripTypeChanged,
                ),
                if (tripType == 'Ida y vuelta') ...[
                  const SizedBox(height: 12),
                ] else if (tripType == 'Multidestino') ...[
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                if (tripType == 'Multidestino') ...[
                  const RouteHeader(title: 'Tramo 1'),
                  const SizedBox(height: 10),
                ],
                ConciergeField(
                  label: 'Origen',
                  value: _airportPrimaryLabel(primaryRoute.fromAirport),
                  helperText: '¿Desde donde sales?',
                  leadingIcon: Icons.location_on_outlined,
                  secondaryValue: _airportSecondaryLabel(
                    primaryRoute.fromAirport,
                  ),
                  placeholder: 'Seleccionar aeropuerto',
                  onTap: onPickOrigin,
                ),
                const SizedBox(height: 10),
                ConciergeField(
                  label: 'Destino',
                  value: _airportPrimaryLabel(primaryRoute.toAirport),
                  helperText: '¿A donde vuelas?',
                  leadingIcon: Icons.place_outlined,
                  secondaryValue: _airportSecondaryLabel(
                    primaryRoute.toAirport,
                  ),
                  placeholder: 'Seleccionar aeropuerto',
                  onTap: onPickDestination,
                ),
                const SizedBox(height: 10),
                ConciergeField(
                  label: 'Salida',
                  value:
                      primaryRoute.startDate == null
                          ? 'Seleccionar fecha'
                          : dateFormat.format(primaryRoute.startDate!),
                  helperText: 'Elige la fecha de salida',
                  leadingIcon: Icons.calendar_month_outlined,
                  onTap: onPickPrimaryDate,
                  trailing: Icon(
                    Icons.calendar_today_outlined,
                    size: 24,
                    color: isDark ? palette.accent : palette.primary,
                  ),
                  placeholder: 'Seleccionar fecha',
                ),
                const SizedBox(height: 8),
                InlinePreferenceButton(
                  title:
                      departureTime == null
                          ? 'Seleccionar hora de salida'
                          : 'Hora de salida: ${departureTime!.format(context)}',
                  icon: Icons.schedule_rounded,
                  onTap: onPickDepartureTime,
                ),
                if (tripType == 'Ida y vuelta') ...[
                  const SizedBox(height: 10),
                  ConciergeField(
                    label: 'Fecha de regreso',
                    value:
                        returnDate == null
                            ? 'Seleccionar fecha'
                            : dateFormat.format(returnDate!),
                    helperText: 'Programa tu regreso',
                    leadingIcon: Icons.event_repeat_outlined,
                    onTap: onPickReturnDate,
                    trailing: Icon(
                      Icons.calendar_today_outlined,
                      size: 24,
                      color: isDark ? palette.accent : palette.primary,
                    ),
                    placeholder: 'Seleccionar fecha',
                  ),
                  const SizedBox(height: 8),
                  InlinePreferenceButton(
                    title:
                        returnTime == null
                            ? 'Seleccionar hora de regreso'
                            : 'Hora de regreso: ${returnTime!.format(context)}',
                    icon: Icons.more_time_rounded,
                    onTap: onPickReturnTime,
                  ),
                ],
                if (tripType == 'Multidestino') ...[
                  const SizedBox(height: 10),
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
                    onPressed:
                        primaryRoute.toAirport == null ? null : onAddRoute,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Agregar tramo'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: BorderSide(
                        color: isDark ? palette.accentBorder : palette.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      foregroundColor: palette.textPrimary,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        reservation.isLoadingQuotePreview || !isPrimaryFormReady
                            ? null
                            : onPreview,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.primary,
                      disabledBackgroundColor: palette.surfaceSoft,
                      disabledForegroundColor: palette.textSecondary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                    child:
                        reservation.isLoadingQuotePreview
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Consultando disponibilidad...',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            )
                            : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPrimaryFormReady
                                      ? Icons.search_rounded
                                      : Icons.info_outline_rounded,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    isPrimaryFormReady
                                        ? 'Ver aeronaves disponibles'
                                        : 'Completa origen, destino y fecha',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cotizacion estimada, sujeta a disponibilidad y operacion.',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
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
                style: TextStyle(
                  color: palette.textPrimary,
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

class _HeroAccent extends StatelessWidget {
  const _HeroAccent();

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return SizedBox(
      height: 14,
      child: Stack(
        children: [
          Positioned(
            top: 2,
            left: 0,
            child: Container(
              width: 72,
              height: 1.5,
              decoration: BoxDecoration(
                color: palette.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Positioned(
            top: 7,
            left: 18,
            child: Container(
              width: 46,
              height: 1.5,
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSectionHeader extends StatelessWidget {
  const _FormSectionHeader();

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Row(
      children: [
        Icon(
          Icons.flight_outlined,
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? palette.accent
                  : palette.primary,
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          'Datos del vuelo',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
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
            title: 'Multi',
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
    final palette = context.clientPalette;
    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: palette.headerGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: palette.accentBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
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
                  color: palette.surfaceStrong,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: palette.accentBorder),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: palette.accent, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
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
    final palette = context.clientPalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              color: palette.accent,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: palette.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: TextStyle(
              color: palette.textSecondary,
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
    final palette = context.clientPalette;
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
            gradient: LinearGradient(
              colors: palette.headerGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: palette.accentBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
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
                style: TextStyle(
                  color: palette.accent,
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
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
                style: TextStyle(
                  color: palette.textPrimary,
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
    final palette = context.clientPalette;
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: palette.accent,
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
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final accentIcon = palette.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border),
          color: palette.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: palette.surfaceStrong,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.accentBorder),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: accentIcon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: -0.3,
                  color: palette.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_right_rounded,
              color: palette.accent,
              size: 22,
            ),
          ],
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
    final palette = context.clientPalette;
    final label = value == 1 ? '1 pasajero' : '$value pasajeros';

    return Row(
      children: [
        Expanded(
          child: Text(
            'Pasajeros',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: palette.textPrimary,
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
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: palette.textPrimary,
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
    final palette = context.clientPalette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: onTap == null ? palette.surfaceSoft : palette.accent,
          shape: BoxShape.circle,
          border: Border.all(
            color: onTap == null ? palette.border : palette.accent,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? palette.textSecondary : palette.textOnAccent,
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
    final palette = context.clientPalette;
    return ConciergeCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Tramo ${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
                color: palette.accent,
              ),
            ],
          ),
          ConciergeField(
            label: 'Origen',
            value: _airportPrimary(route.fromAirport),
            helperText: 'Selecciona el punto de partida',
            leadingIcon: Icons.location_on_outlined,
            secondaryValue: _airportSecondary(route.fromAirport),
            placeholder: 'Seleccionar aeropuerto',
            onTap: onPickOrigin,
          ),
          const SizedBox(height: 10),
          ConciergeField(
            label: 'Destino',
            value: _airportPrimary(route.toAirport),
            helperText: 'Selecciona el siguiente destino',
            leadingIcon: Icons.place_outlined,
            secondaryValue: _airportSecondary(route.toAirport),
            placeholder: 'Seleccionar aeropuerto',
            onTap: onPickDestination,
          ),
          const SizedBox(height: 10),
          ConciergeField(
            label: 'Fecha',
            value:
                route.startDate == null
                    ? 'Seleccionar fecha'
                    : formatDate.format(route.startDate!),
            helperText: 'Programa la salida de este tramo',
            leadingIcon: Icons.calendar_month_outlined,
            onTap: onPickDate,
            trailing: Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? palette.accent
                      : palette.primary,
            ),
            placeholder: 'Seleccionar fecha',
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
    final palette = context.clientPalette;
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
        color: palette.accent,
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
    final palette = context.clientPalette;
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      minLines: 1,
      maxLines: 2,
      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        labelStyle: TextStyle(
          color: palette.textSecondary,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(
          color: palette.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        fillColor: palette.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
