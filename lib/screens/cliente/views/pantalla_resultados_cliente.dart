import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/acceso_comercial_cliente.dart';
import '../../../core/media_utils.dart';
import '../../../models/modelo_ruta.dart';
import '../../../providers/proveedor_autenticacion.dart';
import '../../../providers/proveedor_reservaciones.dart';
import '../tema_cliente.dart';

class ClientResultsScreen extends StatefulWidget {
  const ClientResultsScreen({
    super.key,
    this.showBackButton = true,
    this.onOpenContract,
    this.onOpenPayment,
    this.userInitial = 'C',
    this.onBackToSearch,
    this.onReservationCreated,
    this.onCommercialAccessRequired,
  });

  final bool showBackButton;
  final ValueChanged<Map<String, dynamic>>? onOpenContract;
  final ValueChanged<Map<String, dynamic>>? onOpenPayment;
  final String userInitial;
  final VoidCallback? onBackToSearch;
  final ValueChanged<String?>? onReservationCreated;
  final VoidCallback? onCommercialAccessRequired;

  @override
  State<ClientResultsScreen> createState() => _ClientResultsScreenState();
}

class _ClientResultsScreenState extends State<ClientResultsScreen> {
  bool _isCreatingRequest = false;
  _ResultsSortCriterion _sortCriterion = _ResultsSortCriterion.advisor;

  @override
  Widget build(BuildContext context) {
    final reservation = context.watch<ReservationProvider>();
    final auth = context.watch<AuthProvider>();
    final accessState = resolveCommercialAccessState(auth.accessData);
    final matches = _sortMatches(reservation.quoteMatches);
    final selected = reservation.selectedQuoteMatch;
    final createActionLabel =
        accessState.canReserve ? 'Crear solicitud' : 'Activar acceso comercial';

    return Scaffold(
      backgroundColor: const Color(0xFF07111D),
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (widget.showBackButton)
                        _RoundIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap:
                              widget.onBackToSearch ??
                              () => Navigator.pop(context),
                        ),
                      if (widget.showBackButton) const SizedBox(width: 12),
                      const _ResultsBrand(),
                      const Spacer(),
                      const _ResultsHeaderIcon(
                        icon: Icons.notifications_none_rounded,
                        showIndicator: true,
                      ),
                      const SizedBox(width: 8),
                      const _ResultsHeaderIcon(icon: Icons.tune_rounded),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Aeronaves disponibles',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.65,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Selecciona tu opción y crea la solicitud en segundos.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .68),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
                children: [
                  _ResultsSummaryBand(
                    routes: reservation.routes,
                    passengers: reservation.passengers,
                    isLoading: reservation.isLoadingQuotePreview,
                    onModify:
                        widget.onBackToSearch ?? () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 18),
                  _ResultsSortCard(
                    activeCriterion: _sortCriterion,
                    onSelect:
                        (criterion) => setState(() {
                          _sortCriterion = criterion;
                        }),
                  ),
                  const SizedBox(height: 18),
                  if (reservation.quoteError != null) ...[
                    _InfoCard(text: reservation.quoteError!),
                    const SizedBox(height: 16),
                  ],
                  if (matches.isEmpty)
                    _EmptyResultsCard(onBackToSearch: widget.onBackToSearch)
                  else
                    ...matches.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _QuoteMatchCard(
                          quote: entry.value,
                          isRecommended:
                              _sortCriterion == _ResultsSortCriterion.advisor &&
                              entry.key == 0,
                          isSelected: _sameQuote(entry.value, selected),
                          isBusy:
                              _isCreatingRequest &&
                              _sameQuote(entry.value, selected),
                          onSelect: () {
                            reservation.setSelectedQuoteMatch(entry.value);
                          },
                          onCreateRequest: () => _createRequest(entry.value),
                          actionLabel: createActionLabel,
                        ),
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

  Future<void> _createRequest(Map<String, dynamic> quote) async {
    if (_isCreatingRequest) return;

    final reservation = context.read<ReservationProvider>();
    final auth = context.read<AuthProvider>();
    final accessState = resolveCommercialAccessState(auth.accessData);

    if (!accessState.canReserve) {
      if (!mounted) return;
      _showResultAlert(
        accessState.reservationBlockedMessage,
        icon: Icons.workspace_premium_rounded,
      );
      widget.onCommercialAccessRequired?.call();
      return;
    }

    reservation.setSelectedQuoteMatch(quote);

    setState(() {
      _isCreatingRequest = true;
    });

    try {
      final response = await reservation.createFlightRequestForMatch(quote);
      await auth.refreshCommercialAccessStatus();
      final createdId = reservation.createdFlightRequestIdFromResponse(
        response,
      );
      await reservation.loadClientWorkspaceData(force: true);
      reservation.rememberCreatedFlightRequest(response);
      if (!mounted) return;

      reservation.resetForm();

      if (widget.onReservationCreated != null) {
        widget.onReservationCreated!(createdId);
        return;
      }

      _showResultAlert(
        'Solicitud creada correctamente. Ya puedes seguirla en Reservas.',
        icon: Icons.check_circle_rounded,
      );
    } catch (error) {
      if (!mounted) return;
      _showResultAlert(
        'No fue posible crear la solicitud: $error',
        icon: Icons.error_outline_rounded,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingRequest = false;
        });
      }
    }
  }

  void _showResultAlert(
    String message, {
    required IconData icon,
    bool isError = false,
  }) {
    final palette = context.clientPalette;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          backgroundColor:
              isError ? Theme.of(context).colorScheme.error : palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              Icon(
                icon,
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

  bool _sameQuote(Map<String, dynamic> quote, Map<String, dynamic>? selected) {
    if (selected == null) return false;

    final quoteId =
        quote['match_id']?.toString() ??
        quote['id']?.toString() ??
        quote['aircraft_id']?.toString();
    final selectedId =
        selected['match_id']?.toString() ??
        selected['id']?.toString() ??
        selected['aircraft_id']?.toString();

    if (quoteId != null && selectedId != null) {
      return quoteId == selectedId;
    }

    return identical(quote, selected);
  }

  List<Map<String, dynamic>> _sortMatches(List<Map<String, dynamic>> matches) {
    final indexed =
        matches
            .asMap()
            .entries
            .map((entry) => (index: entry.key, match: entry.value))
            .toList();

    indexed.sort((current, next) {
      final comparison = switch (_sortCriterion) {
        _ResultsSortCriterion.advisor => _advisorScore(
          next.match,
        ).compareTo(_advisorScore(current.match)),
        _ResultsSortCriterion.investment => _quoteTotalValue(
          current.match,
        ).compareTo(_quoteTotalValue(next.match)),
        _ResultsSortCriterion.fastest => _quoteTimeValue(
          current.match,
        ).compareTo(_quoteTimeValue(next.match)),
        _ResultsSortCriterion.exclusive => _exclusivityScore(
          next.match,
        ).compareTo(_exclusivityScore(current.match)),
      };

      if (comparison != 0) return comparison;
      return current.index.compareTo(next.index);
    });

    return indexed.map((entry) => entry.match).toList();
  }

  double _advisorScore(Map<String, dynamic> match) {
    final exclusivity = _exclusivityScore(match);
    final time = _safeScoreDenominator(_quoteTimeValue(match));
    final total = _safeScoreDenominator(_quoteTotalValue(match));
    return exclusivity * 10 + (1 / time) * 1600 + (1 / total) * 220000;
  }

  double _quoteTotalValue(Map<String, dynamic> match) {
    return _extractNumber(
      match['total'] ?? match['final_price'] ?? match['price'],
    );
  }

  double _quoteTimeValue(Map<String, dynamic> match) {
    final raw = _firstText(match, const [
      'time',
      'flight_time',
      'duration',
      'display_time',
      'card_time',
    ]);
    if (raw.isEmpty) return double.maxFinite;

    final lower = raw.toLowerCase();
    final hourMatch = RegExp(r'(\d+(?:\.\d+)?)\s*h').firstMatch(lower);
    final minuteMatch = RegExp(r'(\d+(?:\.\d+)?)\s*m').firstMatch(lower);
    final hours = double.tryParse(hourMatch?.group(1) ?? '') ?? 0;
    final minutes = double.tryParse(minuteMatch?.group(1) ?? '') ?? 0;
    final totalMinutes = hours * 60 + minutes;
    if (totalMinutes > 0) return totalMinutes;

    final numeric = _extractNumber(raw);
    return numeric > 0 ? numeric : double.maxFinite;
  }

  double _exclusivityScore(Map<String, dynamic> match) {
    final cabin =
        _firstText(match, const [
          'cabin',
          'category',
          'aircraft_type',
        ]).toLowerCase();
    final capacity = _extractNumber(
      match['capacity'] ?? match['capacity_passengers'],
    );
    final amenities =
        match['amenities'] is List ? (match['amenities'] as List).length : 0;
    final price = _quoteTotalValue(match);

    var cabinScore = 0.0;
    if (cabin.contains('heavy')) cabinScore += 40;
    if (cabin.contains('long range')) cabinScore += 32;
    if (cabin.contains('super midsize')) cabinScore += 24;
    if (cabin.contains('midsize')) cabinScore += 18;
    if (cabin.contains('light')) cabinScore += 10;
    if (cabin.contains('vip') || cabin.contains('elite')) cabinScore += 20;

    return cabinScore + capacity + (amenities * 2) + (price / 1000);
  }

  double _safeScoreDenominator(double value) {
    if (value.isNaN || value <= 0 || value == double.maxFinite) return 1;
    return value;
  }

  double _extractNumber(dynamic value) {
    if (value is num) return value.toDouble();
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return 0;
    return double.tryParse(text.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;
  }
}

enum _ResultsSortCriterion { advisor, investment, fastest, exclusive }

extension on _ResultsSortCriterion {
  String get label {
    switch (this) {
      case _ResultsSortCriterion.advisor:
        return 'Recomendado';
      case _ResultsSortCriterion.investment:
        return 'Mejor precio';
      case _ResultsSortCriterion.fastest:
        return 'Más rápido';
      case _ResultsSortCriterion.exclusive:
        return 'Más lujo';
    }
  }
}

class _ResultsSummaryBand extends StatelessWidget {
  const _ResultsSummaryBand({
    required this.routes,
    required this.passengers,
    required this.isLoading,
    required this.onModify,
  });

  final List<RouteModel> routes;
  final int passengers;
  final bool isLoading;
  final VoidCallback onModify;

  @override
  Widget build(BuildContext context) {
    final primaryRoute = routes.isEmpty ? null : routes.first;
    final origin = _airportCode(primaryRoute?.fromAirport);
    final destination = _airportCode(primaryRoute?.toAirport);
    final routeLabel =
        origin.isNotEmpty && destination.isNotEmpty
            ? '$origin -> $destination'
            : 'Ruta por confirmar';
    final completeSegments =
        routes
            .where(
              (route) =>
                  route.fromAirport != null &&
                  route.toAirport != null &&
                  route.startDate != null,
            )
            .length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFD8B15D).withValues(alpha: .1),
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.center,
            child: Icon(
              isLoading ? Icons.sync_rounded : Icons.flight_takeoff_rounded,
              color: const Color(0xFFD8B15D),
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$passengers ${passengers == 1 ? 'pasajero' : 'pasajeros'}  •  $completeSegments ${completeSegments == 1 ? 'tramo' : 'tramos'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .62),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onModify,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD8B15D),
              side: BorderSide(
                color: const Color(0xFFD8B15D).withValues(alpha: .5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Modificar',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _airportCode(dynamic airport) {
    if (airport == null) return '';
    final icao = airport.icao?.toString().trim().toUpperCase() ?? '';
    if (icao.isNotEmpty) return icao;
    final iata = airport.iata?.toString().trim().toUpperCase() ?? '';
    if (iata.isNotEmpty) return iata;
    return airport.city?.toString().trim() ?? '';
  }
}

class _ResultsSortCard extends StatelessWidget {
  const _ResultsSortCard({
    required this.activeCriterion,
    required this.onSelect,
  });

  final _ResultsSortCriterion activeCriterion;
  final ValueChanged<_ResultsSortCriterion> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children:
            _ResultsSortCriterion.values.map((criterion) {
              final active = criterion == activeCriterion;
              return Padding(
                padding: const EdgeInsets.only(right: 9),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onSelect(criterion),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color:
                          active
                              ? const Color(0xFFD8B15D).withValues(alpha: .12)
                              : const Color(0xFF101C2D),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color:
                            active
                                ? const Color(0xFFD8B15D)
                                : Colors.white.withValues(alpha: .08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                active
                                    ? const Color(0xFFD8B15D)
                                    : Colors.white.withValues(alpha: .28),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          criterion.label,
                          style: TextStyle(
                            color:
                                active
                                    ? const Color(0xFFD8B15D)
                                    : Colors.white.withValues(alpha: .62),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _QuoteMatchCard extends StatelessWidget {
  const _QuoteMatchCard({
    required this.quote,
    required this.isRecommended,
    required this.isSelected,
    required this.isBusy,
    required this.onSelect,
    required this.onCreateRequest,
    required this.actionLabel,
  });

  final Map<String, dynamic> quote;
  final bool isRecommended;
  final bool isSelected;
  final bool isBusy;
  final VoidCallback onSelect;
  final VoidCallback onCreateRequest;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final aircraft = _aircraftName(quote);
    final cabin = _firstText(quote, const [
      'cabin',
      'category',
      'aircraft_type',
    ]);
    final capacity = _firstText(quote, const [
      'capacity',
      'capacity_passengers',
    ]);
    final provider = _providerName(quote);
    final imageUrl = resolveMediaUrl(_aircraftImageUrl(quote));
    final price = _moneyLabel(
      quote['final_price'] ?? quote['total'] ?? quote['price'],
    );
    final time = _firstText(quote, const ['time', 'flight_time', 'duration']);
    final autonomy = _firstText(quote, const [
      'range',
      'autonomy',
      'range_km',
      'aircraft_range',
    ]);
    final base = _firstText(quote, const [
      'city',
      'base',
      'home_base',
      'base_airport',
      'base_airport_code',
      'source_origin',
      'queried_base_airport',
      'origin',
    ]);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder:
          (_, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - value)),
              child: child,
            ),
          ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(28),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 204,
          decoration: BoxDecoration(
            color: const Color(0xFF101C2D),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color:
                  isSelected
                      ? const Color(0xFFD8B15D)
                      : Colors.white.withValues(alpha: .08),
              width: isSelected ? 1.35 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 142,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _AircraftMedia(
                              imageUrl: imageUrl,
                              label: cabin.isEmpty ? 'Jet privado' : cabin,
                            ),
                            if (isRecommended)
                              Positioned(
                                top: 9,
                                left: 9,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF30D158),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    '★ Recomendado',
                                    style: TextStyle(
                                      color: Color(0xFF07111D),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IgnorePointer(
                                child: Container(
                                  width: 31,
                                  height: 31,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(
                                      0xFF07111D,
                                    ).withValues(alpha: .72),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: .16,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.favorite_border_rounded,
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 9,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF07111D,
                                  ).withValues(alpha: .78),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFD8B15D,
                                    ).withValues(alpha: .48),
                                  ),
                                ),
                                child: Text(
                                  cabin.isEmpty ? 'Jet privado' : cabin,
                                  style: const TextStyle(
                                    color: Color(0xFFD8B15D),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(13, 13, 11, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      aircraft,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        height: 1.02,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -.35,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 5),
                                      child: Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFFD8B15D),
                                        size: 18,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                [
                                  if (provider.isNotEmpty) provider,
                                  if (cabin.isNotEmpty) cabin,
                                  if (capacity.isNotEmpty)
                                    '$capacity pasajeros',
                                ].join('  •  '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .58),
                                  fontSize: 9.5,
                                  height: 1.25,
                                ),
                              ),
                              if (base.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      color: Color(0xFFD8B15D),
                                      size: 12,
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        'Base operativa en ${base.toUpperCase()}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: .68,
                                          ),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const Spacer(),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _AircraftDataBox(
                                      label: 'TOTAL',
                                      value: price,
                                      valueFontSize: 15.5,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    flex: 2,
                                    child: _AircraftDataBox(
                                      label: 'TIEMPO',
                                      value: time.isEmpty ? '—' : time,
                                      valueFontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              if (autonomy.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.route_rounded,
                                      color: Color(0xFFD8B15D),
                                      size: 11,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Autonomía $autonomy',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: .58,
                                          ),
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: _ResultsScaleButton(
                    onTap: isBusy ? null : onCreateRequest,
                    child: Container(
                      height: 38,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? const Color(0xFFD8B15D)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFD8B15D),
                          width: 1,
                        ),
                      ),
                      child:
                          isBusy
                              ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFD8B15D),
                                ),
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.flight_takeoff_rounded,
                                    color: Color(0xFFD8B15D),
                                    size: 17,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    actionLabel.contains('Activar')
                                        ? 'Activar aeronave'
                                        : 'Crear solicitud',
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? const Color(0xFF07111D)
                                              : const Color(0xFFD8B15D),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Spacer(),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color:
                                          isSelected
                                              ? const Color(0xFF07111D)
                                              : const Color(0xFFD8B15D),
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AircraftDataBox extends StatelessWidget {
  const _AircraftDataBox({
    required this.label,
    required this.value,
    required this.valueFontSize,
  });

  final String label;
  final String value;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF07111D).withValues(alpha: .45),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .52),
              fontSize: 7.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: const Color(0xFFD8B15D),
                fontSize: valueFontSize,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsScaleButton extends StatefulWidget {
  const _ResultsScaleButton({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_ResultsScaleButton> createState() => _ResultsScaleButtonState();
}

class _ResultsScaleButtonState extends State<_ResultsScaleButton> {
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

class _AircraftMedia extends StatelessWidget {
  const _AircraftMedia({required this.imageUrl, required this.label});

  final String imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF242424), Color(0xFF0F0F0F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _AircraftMediaEmpty(label: label),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _AircraftMediaEmpty(label: label);
                },
              )
            else
              _AircraftMediaEmpty(label: label),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x0A000000), Color(0x6B000000)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AircraftMediaEmpty extends StatelessWidget {
  const _AircraftMediaEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flight_rounded, color: Colors.white, size: 30),
          const SizedBox(height: 8),
          Text(
            label.trim().isEmpty ? 'Aeronave privada' : label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Imagen en validacion',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyResultsCard extends StatelessWidget {
  const _EmptyResultsCard({required this.onBackToSearch});

  final VoidCallback? onBackToSearch;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? palette.accentBorder : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No hay aeronaves para esta busqueda.',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajusta origen, fecha o pasajeros y vuelve a buscar disponibilidad.',
            style: TextStyle(
              color: palette.textSecondary,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onBackToSearch != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onBackToSearch,
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Volver a buscar'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF101C2D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .10)),
        ),
        child: Icon(icon, color: const Color(0xFFD8B15D), size: 20),
      ),
    );
  }
}

class _ResultsBrand extends StatelessWidget {
  const _ResultsBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          child: Image.asset(
            'assets/LOGOINTERNO.png',
            width: 42,
            height: 34,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 7),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'RED SKY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'G R O U P',
              style: TextStyle(
                color: Colors.white,
                fontSize: 5.5,
                height: 1,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResultsHeaderIcon extends StatelessWidget {
  const _ResultsHeaderIcon({required this.icon, this.showIndicator = false});

  final IconData icon;
  final bool showIndicator;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF101C2D),
              border: Border.all(color: Colors.white.withValues(alpha: .10)),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          if (showIndicator)
            const Positioned(
              top: 1,
              right: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFD8B15D),
                ),
                child: SizedBox(width: 7, height: 7),
              ),
            ),
        ],
      ),
    );
  }
}

String _aircraftName(Map<String, dynamic> quote) {
  return _firstText(quote, const [
    'aircraft_name',
    'aircraft',
    'model',
    'registration',
    'name',
  ], fallback: 'Aeronave disponible');
}

String _providerName(Map<String, dynamic> quote) {
  final provider = quote['provider'];
  if (provider is Map) {
    final company = provider['company_name']?.toString().trim();
    if (company != null && company.isNotEmpty) return company;

    final name = provider['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
  }

  return _firstText(quote, const ['provider_name', 'operator_name']);
}

String _aircraftImageUrl(Map<String, dynamic> quote) {
  final direct = _firstText(quote, const [
    'image_url',
    'imageUrl',
    'aircraft_image',
    'main_image',
    'photo_url',
    'thumbnail_url',
  ]);
  if (direct.isNotEmpty) return direct;

  final images = quote['images'];
  if (images is List) {
    for (final image in images) {
      if (image is Map) {
        final imageUrl =
            image['imageUrl'] ??
            image['image_url'] ??
            image['url'] ??
            image['path'];
        final text = imageUrl?.toString().trim() ?? '';
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }

      final text = image?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
  }

  return '';
}

String _firstText(
  Map<String, dynamic> raw,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = raw[key];
    if (value == null) continue;
    if (value is Map) continue;

    final text = value.toString().trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }

  return fallback;
}

String _moneyLabel(dynamic value) {
  if (value == null) return 'Por confirmar';
  if (value is num) return 'USD ${value.toStringAsFixed(0)}';

  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return 'Por confirmar';
  if (text.toUpperCase().contains('USD') || text.contains(r'$')) return text;

  final numeric = double.tryParse(text.replaceAll(RegExp(r'[^0-9.\-]'), ''));
  if (numeric != null) return 'USD ${numeric.toStringAsFixed(0)}';

  return text;
}
