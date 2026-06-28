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
    final palette = context.clientPalette;
    final accessState = resolveCommercialAccessState(auth.accessData);
    final matches = _sortMatches(reservation.quoteMatches);
    final selected = reservation.selectedQuoteMatch;
    final createActionLabel =
        accessState.canReserve ? 'Crear solicitud' : 'Activar acceso comercial';

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: [
                  if (widget.showBackButton)
                    _RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap:
                          widget.onBackToSearch ?? () => Navigator.pop(context),
                    ),
                  const Spacer(),
                  _StatusBadge(label: '${matches.length} opciones'),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 34),
                children: [
                  Text(
                    'Aeronaves disponibles',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 28,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Selecciona tu opcion y crea la solicitud en segundos.',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ResultsSummaryBand(
                    routes: reservation.routes,
                    passengers: reservation.passengers,
                    tripLabel: reservation.currentTripTypeLabel,
                    isLoading: reservation.isLoadingQuotePreview,
                  ),
                  const SizedBox(height: 16),
                  _ResultsSortCard(
                    activeCriterion: _sortCriterion,
                    onSelect:
                        (criterion) => setState(() {
                          _sortCriterion = criterion;
                        }),
                  ),
                  const SizedBox(height: 16),
                  if (reservation.quoteError != null) ...[
                    _InfoCard(text: reservation.quoteError!),
                    const SizedBox(height: 16),
                  ],
                  if (matches.isEmpty)
                    _EmptyResultsCard(onBackToSearch: widget.onBackToSearch)
                  else
                    ...matches.map(
                      (match) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _QuoteMatchCard(
                          quote: match,
                          isSelected: _sameQuote(match, selected),
                          isBusy:
                              _isCreatingRequest && _sameQuote(match, selected),
                          onSelect: () {
                            reservation.setSelectedQuoteMatch(match);
                          },
                          onCreateRequest: () => _createRequest(match),
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
        return 'Recomendado por asesor';
      case _ResultsSortCriterion.investment:
        return 'Mejor inversion';
      case _ResultsSortCriterion.fastest:
        return 'Salida mas rapida';
      case _ResultsSortCriterion.exclusive:
        return 'Mayor exclusividad';
    }
  }
}

class _ResultsSummaryBand extends StatelessWidget {
  const _ResultsSummaryBand({
    required this.routes,
    required this.passengers,
    required this.tripLabel,
    required this.isLoading,
  });

  final List<RouteModel> routes;
  final int passengers;
  final String tripLabel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              isLoading ? Icons.sync_rounded : Icons.flight_takeoff_rounded,
              color: ClientThemeColors.textOnAccent,
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
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$tripLabel | $completeSegments tramos | $passengers pasajeros',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
    final palette = context.clientPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? palette.accentBorder : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMPARAR POR',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Prioriza criterio experto, inversion, rapidez o exclusividad.',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  _ResultsSortCriterion.values.map((criterion) {
                    final active = criterion == activeCriterion;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => onSelect(criterion),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color:
                                active
                                    ? (isDark
                                        ? palette.surfaceStrong
                                        : palette.textPrimary)
                                    : palette.surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color:
                                  active
                                      ? (isDark
                                          ? palette.accentBorder
                                          : palette.textPrimary)
                                      : (isDark
                                          ? palette.accentBorder
                                          : palette.border),
                            ),
                          ),
                          child: Text(
                            criterion.label,
                            style: TextStyle(
                              color:
                                  active ? Colors.white : palette.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteMatchCard extends StatelessWidget {
  const _QuoteMatchCard({
    required this.quote,
    required this.isSelected,
    required this.isBusy,
    required this.onSelect,
    required this.onCreateRequest,
    required this.actionLabel,
  });

  final Map<String, dynamic> quote;
  final bool isSelected;
  final bool isBusy;
  final VoidCallback onSelect;
  final VoidCallback onCreateRequest;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
    final reason = _displayMatchReason(quote);

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? palette.accentBorder : palette.border,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.10),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AircraftMedia(
              imageUrl: imageUrl,
              label: cabin.isEmpty ? 'Opcion privada' : cabin,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        aircraft,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 18,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (provider.isNotEmpty) provider,
                          if (cabin.isNotEmpty) cabin,
                          if (capacity.isNotEmpty) '$capacity pasajeros',
                        ].join(' | '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: palette.accent),
              ],
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _MetricBox(label: 'Total', value: price)),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricBox(
                    label: 'Tiempo',
                    value: time.isEmpty ? 'Por confirmar' : time,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isBusy ? null : onCreateRequest,
                style: FilledButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: palette.surfaceSoft,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon:
                    isBusy
                        ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  isBusy ? 'Creando solicitud...' : actionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? palette.accentBorder : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
    final palette = context.clientPalette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: double.infinity,
        height: 204,
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
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      imageUrl.isEmpty ? 'Imagen en validacion' : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (imageUrl.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxWidth: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: palette.accentSoft.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ClientThemeColors.textOnAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.accentBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.accent,
          fontSize: 12,
          fontWeight: FontWeight.w900,
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
    final palette = context.clientPalette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.border),
        ),
        child: Icon(icon, color: palette.accent),
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

String _displayMatchReason(Map<String, dynamic> quote) {
  final reason = _firstText(quote, const ['match_reason']);
  if (reason.isNotEmpty && !reason.toLowerCase().contains('base_airport')) {
    return reason;
  }

  final sourceOrigin = _firstText(quote, const ['source_origin']);
  if (sourceOrigin.isNotEmpty) {
    final baseMatch = quote['base_airport_match'] == true;
    return baseMatch
        ? 'Base operativa en $sourceOrigin'
        : 'Salida optimizada desde $sourceOrigin';
  }

  return '';
}
