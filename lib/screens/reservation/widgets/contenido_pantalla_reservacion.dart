// Nota: este archivo concentra la composicion visual de la pantalla de
// reservacion y sus componentes reutilizables para evitar una vista monolitica.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/acceso_comercial_cliente.dart';
import '../../../models/aeropuerto.dart';
import '../../../models/modelo_ruta.dart';
import '../../../providers/proveedor_reservaciones.dart';
import '../../cliente/tema_cliente.dart';
import '../../cliente/widgets/widgets_flujo_movil_cliente.dart';

class ReservationScreenContent extends StatelessWidget {
  const ReservationScreenContent({
    super.key,
    required this.reservation,
    this.scrollController,
    this.routeKeyForIndex,
    required this.primaryRoute,
    required this.suggestedAirports,
    required this.dateFormat,
    required this.tripType,
    required this.departureTime,
    required this.returnDate,
    required this.returnTime,
    required this.commercialState,
    required this.hasCommercialAccessData,
    required this.onOpenMembership,
    required this.onTripTypeChanged,
    required this.onPickOrigin,
    required this.onPickDestination,
    required this.onPickPrimaryDate,
    required this.onPickDepartureTime,
    required this.onPickReturnDate,
    required this.onPickReturnTime,
    required this.onPassengerChanged,
    required this.onPickRouteOrigin,
    required this.onPickRouteDestination,
    required this.onPickRouteDate,
    required this.onPickRouteTime,
    required this.onRemoveRoute,
    required this.onAddRoute,
    required this.onApplySuggestedDestination,
    required this.onPreview,
  });

  final ReservationProvider reservation;
  final ScrollController? scrollController;
  final GlobalKey Function(int index)? routeKeyForIndex;
  final RouteModel primaryRoute;
  final List<Airport> suggestedAirports;
  final DateFormat dateFormat;
  final String tripType;
  final TimeOfDay? departureTime;
  final DateTime? returnDate;
  final TimeOfDay? returnTime;
  final CommercialAccessState commercialState;
  final bool hasCommercialAccessData;
  final VoidCallback onOpenMembership;
  final ValueChanged<String> onTripTypeChanged;
  final VoidCallback onPickOrigin;
  final VoidCallback onPickDestination;
  final VoidCallback onPickPrimaryDate;
  final VoidCallback onPickDepartureTime;
  final VoidCallback onPickReturnDate;
  final VoidCallback onPickReturnTime;
  final ValueChanged<int> onPassengerChanged;
  final ValueChanged<int> onPickRouteOrigin;
  final ValueChanged<int> onPickRouteDestination;
  final ValueChanged<int> onPickRouteDate;
  final ValueChanged<int> onPickRouteTime;
  final ValueChanged<int> onRemoveRoute;
  final VoidCallback onAddRoute;
  final ValueChanged<Airport> onApplySuggestedDestination;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final isPrimaryFormReady =
        primaryRoute.fromAirport != null &&
        primaryRoute.toAirport != null &&
        primaryRoute.startDate != null;
    final canRenderQuoteForm =
        hasCommercialAccessData &&
        commercialState.isConfirmedActive &&
        commercialState.canQuote;

    return ColoredBox(
      color: const Color(0xFF07111D),
      child: ListView(
        controller: scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 136),
        children: [
          _FlightSearchHero(
            hasActiveMembership:
                commercialState.hasPaidAccess || commercialState.canReserve,
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child:
                canRenderQuoteForm
                    ? _LuxuryQuoteForm(
                      key: const ValueKey('quote-form'),
                      reservation: reservation,
                      routeKeyForIndex: routeKeyForIndex,
                      primaryRoute: primaryRoute,
                      dateFormat: dateFormat,
                      tripType: tripType,
                      departureTime: departureTime,
                      returnDate: returnDate,
                      returnTime: returnTime,
                      isReady: isPrimaryFormReady,
                      onTripTypeChanged: onTripTypeChanged,
                      onPickOrigin: onPickOrigin,
                      onPickDestination: onPickDestination,
                      onPickDate: onPickPrimaryDate,
                      onPickTime: onPickDepartureTime,
                      onPickReturnDate: onPickReturnDate,
                      onPickReturnTime: onPickReturnTime,
                      onPassengerChanged: onPassengerChanged,
                      onPickRouteOrigin: onPickRouteOrigin,
                      onPickRouteDestination: onPickRouteDestination,
                      onPickRouteDate: onPickRouteDate,
                      onPickRouteTime: onPickRouteTime,
                      onRemoveRoute: onRemoveRoute,
                      onAddRoute: onAddRoute,
                      commercialState: commercialState,
                      onPreview: onPreview,
                    )
                    : !hasCommercialAccessData
                    ? _CommercialAccessCheckCard(
                      key: const ValueKey('commercial-check'),
                      isLoading: reservation.isLoadingWorkspace,
                    )
                    : _CommercialAccessBanner(
                      key: const ValueKey('commercial-banner'),
                      commercialState: commercialState,
                      onOpenMembership: onOpenMembership,
                    ),
          ),
          const SizedBox(height: 26),
          if (suggestedAirports.isNotEmpty)
            _SuggestedDestinationRail(
              airports: suggestedAirports.take(4).toList(),
              isMultiCity: tripType == 'Multidestino',
              onTap: onApplySuggestedDestination,
            ),
          const SizedBox(height: 20),
          if (reservation.isLoadingWorkspace) ...[
            const LoadingBand(text: 'Sincronizando rutas del cliente...'),
          ],
          if (reservation.quoteError != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101C2D),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                reservation.quoteError!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LuxuryQuoteForm extends StatelessWidget {
  const _LuxuryQuoteForm({
    super.key,
    required this.reservation,
    this.routeKeyForIndex,
    required this.primaryRoute,
    required this.dateFormat,
    required this.tripType,
    required this.departureTime,
    required this.returnDate,
    required this.returnTime,
    required this.isReady,
    required this.onTripTypeChanged,
    required this.onPickOrigin,
    required this.onPickDestination,
    required this.onPickDate,
    required this.onPickTime,
    required this.onPickReturnDate,
    required this.onPickReturnTime,
    required this.onPassengerChanged,
    required this.onPickRouteOrigin,
    required this.onPickRouteDestination,
    required this.onPickRouteDate,
    required this.onPickRouteTime,
    required this.onRemoveRoute,
    required this.onAddRoute,
    required this.commercialState,
    required this.onPreview,
  });

  final ReservationProvider reservation;
  final GlobalKey Function(int index)? routeKeyForIndex;
  final RouteModel primaryRoute;
  final DateFormat dateFormat;
  final String tripType;
  final TimeOfDay? departureTime;
  final DateTime? returnDate;
  final TimeOfDay? returnTime;
  final bool isReady;
  final ValueChanged<String> onTripTypeChanged;
  final VoidCallback onPickOrigin;
  final VoidCallback onPickDestination;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onPickReturnDate;
  final VoidCallback onPickReturnTime;
  final ValueChanged<int> onPassengerChanged;
  final ValueChanged<int> onPickRouteOrigin;
  final ValueChanged<int> onPickRouteDestination;
  final ValueChanged<int> onPickRouteDate;
  final ValueChanged<int> onPickRouteTime;
  final ValueChanged<int> onRemoveRoute;
  final VoidCallback onAddRoute;
  final CommercialAccessState commercialState;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final canAddMultiCityRoute =
        tripType == 'Multidestino' &&
        reservation.routes.isNotEmpty &&
        _isRouteComplete(reservation.routes.last);
    final canPreview = switch (tripType) {
      'Multidestino' => _completeRouteCount(reservation.routes) >= 2,
      'Ida y vuelta' => isReady && returnDate != null,
      _ => isReady,
    };

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeOutCubic,
      builder:
          (_, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 24 * (1 - value)),
              child: child,
            ),
          ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF101C2D),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.flight_takeoff_rounded,
                  color: Color(0xFFD9B25F),
                  size: 24,
                ),
                SizedBox(width: 10),
                Text(
                  'Cotiza tu vuelo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _LuxuryTripTabs(value: tripType, onChanged: onTripTypeChanged),
            const SizedBox(height: 14),
            KeyedSubtree(
              key: routeKeyForIndex?.call(0),
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  Column(
                    children: [
                      _LuxuryFormField(
                        icon: Icons.location_on_outlined,
                        label: 'Origen',
                        value: _airportValue(primaryRoute.fromAirport),
                        placeholder: '¿Desde dónde sales?',
                        onTap: onPickOrigin,
                      ),
                      const SizedBox(height: 14),
                      _LuxuryFormField(
                        icon: Icons.place_outlined,
                        label: 'Destino',
                        value: _airportValue(primaryRoute.toAirport),
                        placeholder: '¿A dónde vuelas?',
                        onTap: onPickDestination,
                      ),
                    ],
                  ),
                  IgnorePointer(
                    child: Container(
                      width: 42,
                      height: 42,
                      margin: const EdgeInsets.only(right: 13),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF16253B),
                        border: Border.all(
                          color: const Color(0xFFD9B25F).withValues(alpha: .42),
                        ),
                      ),
                      child: const Icon(
                        Icons.swap_vert_rounded,
                        color: Color(0xFFD9B25F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _LuxuryFormField(
                    icon: Icons.calendar_month_outlined,
                    label: 'Fecha',
                    value:
                        primaryRoute.startDate == null
                            ? ''
                            : dateFormat.format(primaryRoute.startDate!),
                    placeholder: 'Seleccionar',
                    onTap: onPickDate,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _LuxuryFormField(
                    icon: Icons.schedule_rounded,
                    label: 'Hora',
                    value: departureTime?.format(context) ?? '',
                    placeholder: 'Seleccionar',
                    onTap: onPickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _LuxuryPassengerField(
              value: reservation.passengers,
              onChanged: onPassengerChanged,
            ),
            if (tripType == 'Ida y vuelta') ...[
              const SizedBox(height: 14),
              KeyedSubtree(
                key: routeKeyForIndex?.call(1),
                child: Row(
                  children: [
                    Expanded(
                      child: _LuxuryFormField(
                        icon: Icons.event_repeat_outlined,
                        label: 'Regreso',
                        value:
                            returnDate == null
                                ? ''
                                : dateFormat.format(returnDate!),
                        placeholder: 'Fecha',
                        onTap: onPickReturnDate,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _LuxuryFormField(
                        icon: Icons.more_time_rounded,
                        label: 'Hora',
                        value: returnTime?.format(context) ?? '',
                        placeholder: 'Seleccionar',
                        onTap: onPickReturnTime,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (tripType == 'Multidestino') ...[
              const SizedBox(height: 14),
              const RouteHeader(title: 'Tramo 1'),
              const SizedBox(height: 10),
              ...List.generate(
                reservation.routes.length - 1,
                (extraIndex) => KeyedSubtree(
                  key: routeKeyForIndex?.call(extraIndex + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MultiLegCard(
                      index: extraIndex + 1,
                      route: reservation.routes[extraIndex + 1],
                      onPickOrigin: () => onPickRouteOrigin(extraIndex + 1),
                      onPickDestination:
                          () => onPickRouteDestination(extraIndex + 1),
                      onPickDate: () => onPickRouteDate(extraIndex + 1),
                      onPickTime: () => onPickRouteTime(extraIndex + 1),
                      onRemove: () => onRemoveRoute(extraIndex + 1),
                      formatDate: dateFormat,
                      originLocked: true,
                    ),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: canAddMultiCityRoute ? onAddRoute : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('+ Agregar otro destino'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD9B25F),
                  minimumSize: const Size.fromHeight(48),
                  side: BorderSide(
                    color: const Color(0xFFD9B25F).withValues(alpha: .45),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _QuoteScaleButton(
              onTap:
                  reservation.isLoadingQuotePreview ||
                          (!canPreview && commercialState.canQuote)
                      ? null
                      : onPreview,
              child: Container(
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient:
                      commercialState.canQuote && canPreview
                          ? const LinearGradient(
                            colors: [Color(0xFFF0D58F), Color(0xFFD9B25F)],
                          )
                          : const LinearGradient(
                            colors: [Color(0xFF344052), Color(0xFF273344)],
                          ),
                  boxShadow:
                      commercialState.canQuote && canPreview
                          ? [
                            BoxShadow(
                              color: const Color(
                                0xFFD9B25F,
                              ).withValues(alpha: .18),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ]
                          : null,
                ),
                child:
                    reservation.isLoadingQuotePreview
                        ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Color(0xFF111820),
                          ),
                        )
                        : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              commercialState.canQuote
                                  ? Icons.flight_takeoff_rounded
                                  : Icons.lock_reset_rounded,
                              color:
                                  commercialState.canQuote && canPreview
                                      ? const Color(0xFF111820)
                                      : Colors.white.withValues(alpha: .45),
                            ),
                            const SizedBox(width: 9),
                            Text(
                              commercialState.canQuote
                                  ? 'Buscar vuelos'
                                  : commercialState.quoteActionLabel,
                              style: TextStyle(
                                color:
                                    commercialState.canQuote && canPreview
                                        ? const Color(0xFF111820)
                                        : Colors.white.withValues(alpha: .45),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _airportValue(Airport? airport) {
    if (airport == null) return '';
    final code = airport.iata?.trim().toUpperCase() ?? '';
    return code.isEmpty ? airport.city : '$code · ${airport.city}';
  }

  static int _completeRouteCount(List<RouteModel> routes) {
    return routes.where(_isRouteComplete).length;
  }

  static bool _isRouteComplete(RouteModel route) {
    return route.fromAirport != null &&
        route.toAirport != null &&
        route.startDate != null;
  }
}

class _CommercialAccessCheckCard extends StatelessWidget {
  const _CommercialAccessCheckCard({super.key, required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2D),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFD9B25F).withValues(alpha: .15),
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                isLoading
                    ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFD9B25F),
                      ),
                    )
                    : const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFFD9B25F),
                    ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoading
                      ? 'Comprobando acceso comercial'
                      : 'No pudimos comprobar tu acceso',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  isLoading
                      ? 'Estamos validando tu estado para habilitar el cotizador.'
                      : 'Reintenta la sincronizacion. El cotizador permanecera oculto hasta confirmar tu acceso.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .72),
                    fontSize: 13,
                    height: 1.38,
                    fontWeight: FontWeight.w600,
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

class _CommercialAccessBanner extends StatelessWidget {
  const _CommercialAccessBanner({
    super.key,
    required this.commercialState,
    required this.onOpenMembership,
  });

  final CommercialAccessState commercialState;
  final VoidCallback onOpenMembership;

  @override
  Widget build(BuildContext context) {
    final bool isCritical =
        commercialState.isExpired || commercialState.isSuspended;
    final Color borderColor =
        isCritical ? const Color(0xFFF1A9A0) : const Color(0xFFD9B25F);
    final Color backgroundColor =
        isCritical ? const Color(0xFF2B1720) : const Color(0xFF101C2D);
    final Color accentColor =
        isCritical ? const Color(0xFFFFD7D2) : const Color(0xFFD9B25F);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor.withValues(alpha: .6)),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: .12),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isCritical
                      ? Icons.warning_amber_rounded
                      : Icons.workspace_premium_outlined,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      commercialState.accessBannerTitle,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      commercialState.accessBannerMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpenMembership,
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: const Color(0xFF111820),
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.credit_card_rounded),
              label: Text(
                commercialState.paymentActionLabel,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          if (commercialState.requiresPayment && !commercialState.canQuote)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'La cotizacion permanecera bloqueada hasta completar la reactivacion del acceso comercial.',
                style: TextStyle(
                  color: Color(0xFFF8E9E6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LuxuryTripTabs extends StatelessWidget {
  const _LuxuryTripTabs({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = ['Solo ida', 'Redondo', 'Multidestino'];
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF07111D).withValues(alpha: .65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children:
            options.map((option) {
              final active = option == value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          active ? const Color(0xFF16253B) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border:
                          active
                              ? Border.all(
                                color: const Color(
                                  0xFFD9B25F,
                                ).withValues(alpha: .55),
                              )
                              : null,
                    ),
                    child: Text(
                      option,
                      maxLines: 1,
                      style: TextStyle(
                        color:
                            active
                                ? const Color(0xFFD9B25F)
                                : Colors.white.withValues(alpha: .62),
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _LuxuryFormField extends StatelessWidget {
  const _LuxuryFormField({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF07111D).withValues(alpha: .5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFD9B25F), size: 22),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .72),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value.isEmpty ? placeholder : value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          value.isEmpty
                              ? Colors.white.withValues(alpha: .42)
                              : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LuxuryPassengerField extends StatelessWidget {
  const _LuxuryPassengerField({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF07111D).withValues(alpha: .5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline_rounded, color: Color(0xFFD9B25F)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pasajeros',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .72),
                    fontSize: 12,
                  ),
                ),
                Text(
                  '$value ${value == 1 ? 'pasajero' : 'pasajeros'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: value <= 1 ? null : () => onChanged(value - 1),
            color: const Color(0xFFD9B25F),
            icon: const Icon(Icons.remove_rounded),
          ),
          IconButton(
            onPressed: () => onChanged(value + 1),
            color: const Color(0xFFD9B25F),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _QuoteScaleButton extends StatefulWidget {
  const _QuoteScaleButton({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_QuoteScaleButton> createState() => _QuoteScaleButtonState();
}

class _QuoteScaleButtonState extends State<_QuoteScaleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown:
          widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 1.02 : 1,
        duration: const Duration(milliseconds: 140),
        child: widget.child,
      ),
    );
  }
}

class _FlightSearchHero extends StatelessWidget {
  const _FlightSearchHero({required this.hasActiveMembership});

  final bool hasActiveMembership;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder:
          (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - value)),
              child: child,
            ),
          ),
      child: SizedBox(
        height: 220,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/home/HomeCel.png',
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF12243B),
                            const Color(0xFF101C2D),
                            const Color(0xFF1A3E5A),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF07111D).withValues(alpha: .88),
                      const Color(0xFF07111D).withValues(alpha: .55),
                      Colors.black.withValues(alpha: .48),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroStatusPill(
                      label: 'EXPERIENCIA SKY GROUP',
                      icon:
                          hasActiveMembership
                              ? Icons.verified_rounded
                              : Icons.bolt_rounded,
                    ),
                    const Spacer(),
                    Text(
                      'Viaja sin límites.',
                      style: const TextStyle(
                        fontSize: 29,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.8,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Aviación privada con un servicio excepcional.',
                      style: TextStyle(
                        color: Color(0xFFD9B25F),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .12),
                        ),
                      ),
                      child: const Text(
                        'Conoce más',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Expanded(
                          child: _HeroTrustBadge(
                            icon: Icons.verified_user_outlined,
                            label: 'Aeronaves\nverificadas',
                          ),
                        ),
                        Expanded(
                          child: _HeroTrustBadge(
                            icon: Icons.badge_outlined,
                            label: 'Pilotos\ncertificados',
                          ),
                        ),
                        Expanded(
                          child: _HeroTrustBadge(
                            icon: Icons.support_agent_rounded,
                            label: 'Concierge\n24/7',
                          ),
                        ),
                        Expanded(
                          child: _HeroTrustBadge(
                            icon: Icons.bolt_rounded,
                            label: 'Respuesta\ninmediata',
                          ),
                        ),
                      ],
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

class _HeroStatusPill extends StatelessWidget {
  const _HeroStatusPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF07111D).withValues(alpha: .56),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF31D158).withValues(alpha: .35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF31D158)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF31D158),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTrustBadge extends StatelessWidget {
  const _HeroTrustBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: const Color(0xFFD9B25F)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SuggestedDestinationRail extends StatelessWidget {
  const _SuggestedDestinationRail({
    required this.airports,
    required this.isMultiCity,
    required this.onTap,
  });

  final List<Airport> airports;
  final bool isMultiCity;
  final ValueChanged<Airport> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Destinos populares',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              'Ver todos',
              style: const TextStyle(
                color: Color(0xFFD9B25F),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: airports.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder:
                (_, index) => SizedBox(
                  width: 160,
                  child: SuggestedDestinationCard(
                    airport: airports[index],
                    isMultiCity: isMultiCity,
                    onTap: () => onTap(airports[index]),
                  ),
                ),
          ),
        ),
      ],
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
    final code = airport.iata?.trim().toUpperCase() ?? 'RUTA';
    final location = _displayCityForCode(code, airport.city);
    final imageUrls = _imageUrlsForCode(code);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF101C2D),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: SizedBox(
                height: 98,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _SuggestedDestinationImage(
                      imageUrls: imageUrls,
                      location: location,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.08),
                            Colors.black.withValues(alpha: 0.32),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9B25F),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          code,
                          style: TextStyle(
                            color: const Color(0xFF111820),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.favorite_border_rounded,
                        color: Colors.white.withValues(alpha: .9),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isMultiCity ? 'Agregar parada  →' : 'Usar destino  →',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFD9B25F),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _displayCityForCode(String code, String fallback) {
    switch (code) {
      case 'MEX':
        return 'Ciudad de Mexico';
      case 'CUN':
        return 'Cancun';
      case 'MTY':
        return 'Monterrey';
      case 'SJD':
        return 'Los Cabos';
      default:
        return fallback;
    }
  }

  static List<String> _imageUrlsForCode(String code) {
    switch (code) {
      case 'MEX':
        return const [
          'https://images.unsplash.com/photo-1518105779142-d975f22f1b0a?auto=format&fit=crop&w=900&q=80',
          'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=900&q=80',
        ];
      case 'CUN':
        return const [
          'https://images.unsplash.com/photo-1510097467424-192d713fd8b2?auto=format&fit=crop&w=900&q=80',
          'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=900&q=80',
        ];
      case 'MTY':
        return const [
          'https://images.unsplash.com/photo-1512813195386-6cf811ad3542?auto=format&fit=crop&w=900&q=80',
          'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=900&q=80',
        ];
      case 'SJD':
        return const [
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=900&q=80',
          'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=900&q=80',
        ];
      default:
        return const [
          'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=900&q=80',
        ];
    }
  }
}

class _SuggestedDestinationImage extends StatefulWidget {
  const _SuggestedDestinationImage({
    required this.imageUrls,
    required this.location,
  });

  final List<String> imageUrls;
  final String location;

  @override
  State<_SuggestedDestinationImage> createState() =>
      _SuggestedDestinationImageState();
}

class _SuggestedDestinationImageState
    extends State<_SuggestedDestinationImage> {
  int _imageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.imageUrls[_imageIndex],
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        if (_imageIndex < widget.imageUrls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _imageIndex += 1;
            });
          });
          return const SizedBox.expand();
        }
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF12243B), Color(0xFF07111D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                widget.location,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
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
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5EBF2)),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(14),
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
                  fontSize: 14.5,
                  letterSpacing: -0.3,
                  color: palette.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_right_rounded,
              color: palette.primary,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5EBF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FB),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.person_outline_rounded,
              color: palette.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pasajeros',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          PassengerButton(
            icon: Icons.remove_rounded,
            onTap: value <= 1 ? null : () => onChanged(value - 1),
          ),
          const SizedBox(width: 10),
          PassengerButton(
            icon: Icons.add_rounded,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFFF1F4F7) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: onTap == null ? const Color(0xFFD9E1E8) : palette.primary,
          ),
          boxShadow:
              onTap == null
                  ? null
                  : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? palette.textSecondary : palette.primary,
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
    required this.onPickTime,
    required this.onRemove,
    required this.formatDate,
    this.originLocked = false,
  });

  final int index;
  final RouteModel route;
  final VoidCallback onPickOrigin;
  final VoidCallback onPickDestination;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onRemove;
  final DateFormat formatDate;
  final bool originLocked;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return ConciergeCard(
      padding: const EdgeInsets.all(12),
      dark: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Tramo ${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
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
            helperText:
                originLocked
                    ? 'Origen automático del tramo anterior'
                    : 'Selecciona el punto de partida',
            leadingIcon: Icons.location_on_outlined,
            secondaryValue: _airportSecondary(route.fromAirport),
            placeholder: 'Seleccionar aeropuerto',
            dark: true,
            onTap: originLocked ? () {} : onPickOrigin,
            trailing:
                originLocked
                    ? Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: palette.accent,
                    )
                    : null,
          ),
          const SizedBox(height: 10),
          ConciergeField(
            label: 'Destino',
            value: _airportPrimary(route.toAirport),
            helperText: 'Selecciona el siguiente destino',
            leadingIcon: Icons.place_outlined,
            secondaryValue: _airportSecondary(route.toAirport),
            placeholder: 'Seleccionar aeropuerto',
            dark: true,
            onTap: onPickDestination,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ConciergeField(
                  label: 'Fecha',
                  value:
                      route.startDate == null
                          ? 'Seleccionar fecha'
                          : formatDate.format(route.startDate!),
                  helperText: 'Programa la salida',
                  leadingIcon: Icons.calendar_month_outlined,
                  dark: true,
                  onTap: onPickDate,
                  trailing: Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: palette.accent,
                  ),
                  placeholder: 'Seleccionar fecha',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ConciergeField(
                  label: 'Hora',
                  value:
                      route.startDate == null
                          ? 'Seleccionar hora'
                          : TimeOfDay.fromDateTime(
                            route.startDate!,
                          ).format(context),
                  helperText: 'Hora de salida',
                  leadingIcon: Icons.schedule_rounded,
                  dark: true,
                  onTap: onPickTime,
                  trailing: Icon(
                    Icons.more_time_rounded,
                    size: 18,
                    color: palette.accent,
                  ),
                  placeholder: 'Seleccionar hora',
                ),
              ),
            ],
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
