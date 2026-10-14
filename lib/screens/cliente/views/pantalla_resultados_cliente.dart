import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/acceso_comercial_cliente.dart';
import '../../../core/billable_hours_formatter.dart';
import '../../../core/cliente_api.dart';
import '../../../core/media_utils.dart';
import '../../../core/quote_price_formatter.dart';
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
    this.onCommercialAccessRequired,
    this.enableMapVectorProvider = true,
  });

  final bool showBackButton;
  final ValueChanged<Map<String, dynamic>>? onOpenContract;
  final ValueChanged<Map<String, dynamic>>? onOpenPayment;
  final String userInitial;
  final VoidCallback? onBackToSearch;
  final VoidCallback? onCommercialAccessRequired;
  final bool enableMapVectorProvider;

  @override
  State<ClientResultsScreen> createState() => _ClientResultsScreenState();
}

class _ClientResultsScreenState extends State<ClientResultsScreen> {
  bool _isCreatingRequest = false;
  String? _selectingQuoteId;
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
                      const Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _ResultsBrand(),
                          ),
                        ),
                      ),
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
                  _ResultsSortCard(
                    activeCriterion: _sortCriterion,
                    onSelect:
                        (criterion) => setState(() {
                          _sortCriterion = criterion;
                        }),
                  ),
                  const SizedBox(height: 18),
                  if (reservation.quoteError != null &&
                      !reservation.hasQuoteServerError) ...[
                    _InfoCard(text: reservation.quoteError!),
                    const SizedBox(height: 16),
                  ],
                  if (matches.isEmpty)
                    _ResultsStateCard(
                      state: reservation.quotePreviewState,
                      onBackToSearch: widget.onBackToSearch,
                      onRetry:
                          reservation.isLoadingQuotePreview
                              ? null
                              : reservation.previewCurrentSelection,
                    )
                  else
                    ...matches.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _AircraftCatalogRow(
                          quote: entry.value,
                          isRecommended:
                              _sortCriterion == _ResultsSortCriterion.advisor &&
                              entry.key == 0,
                          isSelected: _sameQuote(entry.value, selected),
                          isSelecting:
                              _selectingQuoteId != null &&
                              _sameQuoteId(entry.value, _selectingQuoteId),
                          isBusy:
                              _isCreatingRequest &&
                              _sameQuote(entry.value, selected),
                          onSelect: () => _selectQuote(entry.value),
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

    if (quote['is_available'] == false) {
      reservation.handleAircraftUnavailable(quote);
      if (!mounted) return;
      _showResultAlert(
        (quote['availability_reason']?.toString().trim().isNotEmpty ?? false)
            ? quote['availability_reason'].toString()
            : 'Disponibilidad actualizada. Esta aeronave ya no esta disponible. Te mostramos otras opciones para tu vuelo.',
        icon: Icons.info_outline_rounded,
        isError: true,
      );
      return;
    }

    reservation.setSelectedQuoteMatch(quote);

    setState(() {
      _selectingQuoteId = null;
      _isCreatingRequest = true;
    });

    try {
      final response = await reservation.createFlightRequestForMatch(quote);
      final createdId = reservation.createdFlightRequestIdFromResponse(
        response,
      );
      if (createdId == null || createdId.isEmpty) {
        throw StateError(
          'El servidor no devolvio el identificador de la solicitud.',
        );
      }

      // The request is already persisted. Refresh failures must not turn this
      // success into a retryable creation failure.
      try {
        await auth.refreshCommercialAccessStatus();
        await reservation.loadClientWorkspaceData(force: true);
      } catch (error) {
        debugPrint('Flight request workspace refresh failed: $error');
      }

      if (!mounted) return;
      Navigator.of(context).pop(createdId);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isAircraftAvailabilityConflict) {
        reservation.handleAircraftUnavailable({...quote, ...?error.payload});
        _showResultAlert(
          'Disponibilidad actualizada. La aeronave seleccionada ya no se encuentra disponible. Te mostramos otras opciones disponibles para tu vuelo.',
          icon: Icons.info_outline_rounded,
          isError: true,
        );
        return;
      }
      _showResultAlert(
        'No fue posible crear la solicitud: ${error.message}',
        icon: Icons.error_outline_rounded,
        isError: true,
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

  Future<void> _selectQuote(Map<String, dynamic> quote) async {
    final reservation = context.read<ReservationProvider>();
    final quoteId = _quoteIdentity(quote);

    if (_isCreatingRequest || quoteId.isEmpty || _selectingQuoteId == quoteId) {
      return;
    }

    setState(() {
      _selectingQuoteId = quoteId;
    });

    reservation.setSelectedQuoteMatch(quote);

    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted || _selectingQuoteId != quoteId) return;

    setState(() {
      _selectingQuoteId = null;
    });
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

    final quoteId = _quoteIdentity(quote);
    final selectedId = _quoteIdentity(selected);

    if (quoteId.isNotEmpty && selectedId.isNotEmpty) {
      return quoteId == selectedId;
    }

    return identical(quote, selected);
  }

  bool _sameQuoteId(Map<String, dynamic> quote, String? selectedId) {
    if (selectedId == null || selectedId.isEmpty) return false;
    return _quoteIdentity(quote) == selectedId;
  }

  String _quoteIdentity(Map<String, dynamic> quote) {
    return quote['match_id']?.toString() ??
        quote['id']?.toString() ??
        quote['aircraft_id']?.toString() ??
        '';
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
        _ResultsSortCriterion.advisor => 0,
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

  double _quoteTotalValue(Map<String, dynamic> match) {
    final pricing = _nestedMap(
      match['pricing'] ??
          match['pricing_breakdown'] ??
          match['pricing_context'],
    );
    return _extractNumber(
      pricing['total_amount'] ??
          match['amount_due'] ??
          match['selected_card_price'] ??
          match['estimated_total'] ??
          match['total_amount'] ??
          match['final_price'] ??
          match['total'] ??
          match['price'],
    );
  }

  double _quoteTimeValue(Map<String, dynamic> match) {
    if (!shouldDisplayBackendBillableHours(match)) return double.maxFinite;
    final billableHours = extractBackendBillableHours(match);
    if (billableHours != null && billableHours > 0) {
      return billableHours * 60;
    }
    return double.maxFinite;
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

class FlightSummaryCard extends StatelessWidget {
  const FlightSummaryCard({
    super.key,
    required this.routes,
    required this.itineraryLegs,
    required this.passengers,
    required this.isLoading,
    required this.onModify,
  });

  final List<RouteModel> routes;
  final List<Map<String, dynamic>> itineraryLegs;
  final int passengers;
  final bool isLoading;
  final VoidCallback onModify;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 390;
    final legs = _summaryLegs();
    final completeSegments = legs.length;

    return Container(
      padding: EdgeInsets.all(mobile ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF111E30),
        borderRadius: BorderRadius.circular(mobile ? 20 : 24),
        border: Border.all(color: const Color(0xFF354257)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLoading ? Icons.sync_rounded : Icons.flight_takeoff_rounded,
                color: const Color(0xFFD4AD58),
                size: mobile ? 17 : 18,
              ),
              SizedBox(width: mobile ? 8 : 10),
              Expanded(
                child: Text(
                  'Resumen del vuelo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFF4F6FA),
                    fontSize: mobile ? 14 : 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: mobile ? 6 : 8),
              TextButton(
                onPressed: onModify,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD4AD58),
                  padding: EdgeInsets.symmetric(
                    horizontal: mobile ? 10 : 12,
                    vertical: mobile ? 7 : 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(
                    color: const Color(0xFFD4AD58).withValues(alpha: .72),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  'Modificar',
                  style: TextStyle(
                    fontSize: mobile ? 10.5 : 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: mobile ? 12 : 14),
          ...legs.indexed.map((entry) {
            final isLast = entry.$1 == legs.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: _FlightSummaryLegRow(
                index: entry.$1,
                leg: entry.$2,
                showDivider: !isLast,
                compact: mobile,
              ),
            );
          }),
          SizedBox(height: mobile ? 12 : 14),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: mobile ? 10 : 12,
              vertical: mobile ? 9 : 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2A3D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF354257).withValues(alpha: .8),
              ),
            ),
            child: Row(
              children: [
                _FlightSummaryMetric(
                  icon: Icons.groups_2_rounded,
                  label:
                      '$passengers ${passengers == 1 ? 'pasajero' : 'pasajeros'}',
                  compact: mobile,
                ),
                Container(
                  width: 1,
                  height: 18,
                  margin: EdgeInsets.symmetric(horizontal: mobile ? 10 : 12),
                  color: const Color(0xFF354257),
                ),
                Expanded(
                  child: _FlightSummaryMetric(
                    icon: Icons.route_rounded,
                    label:
                        '$completeSegments ${completeSegments == 1 ? 'tramo' : 'tramos'}',
                    compact: mobile,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_FlightSummaryLeg> _summaryLegs() {
    if (itineraryLegs.isNotEmpty) {
      final legs =
          itineraryLegs
              .map((leg) {
                final origin = _airportSummary(
                  leg['origin_airport'],
                  cityFallback: leg['origin_city']?.toString(),
                  codeFallback:
                      leg['origin_iata']?.toString() ??
                      leg['origin_icao']?.toString() ??
                      leg['origin']?.toString(),
                );
                final destination = _airportSummary(
                  leg['destination_airport'],
                  cityFallback: leg['destination_city']?.toString(),
                  codeFallback:
                      leg['destination_iata']?.toString() ??
                      leg['destination_icao']?.toString() ??
                      leg['destination']?.toString(),
                );

                if (origin.label.isEmpty || destination.label.isEmpty) {
                  return null;
                }
                return _FlightSummaryLeg(
                  originCity: origin.label,
                  destinationCity: destination.label,
                  originCode: origin.code,
                  destinationCode: destination.code,
                );
              })
              .whereType<_FlightSummaryLeg>()
              .toList();

      if (legs.isNotEmpty) return legs;
    }

    final legs = <_FlightSummaryLeg>[];
    for (final route in routes) {
      final origin = _airportSummary(route.fromAirport);
      final destination = _airportSummary(route.toAirport);

      if (origin.label.isNotEmpty && destination.label.isNotEmpty) {
        legs.add(
          _FlightSummaryLeg(
            originCity: origin.label,
            destinationCity: destination.label,
            originCode: origin.code,
            destinationCode: destination.code,
          ),
        );
      }
    }

    return legs.isEmpty
        ? const [
          _FlightSummaryLeg(
            originCity: 'Ruta',
            destinationCity: 'por confirmar',
            originCode: '--',
            destinationCode: '--',
          ),
        ]
        : legs;
  }

  _AirportSummary _airportSummary(
    dynamic airport, {
    String? cityFallback,
    String? codeFallback,
  }) {
    if (airport is Map) {
      final city = _firstCleanText(airport, const [
        'city',
        'CIUDAD',
        'municipality',
        'ciudad',
      ]);
      final name = _firstCleanText(airport, const [
        'name',
        'airport',
        'AEROPUERTO',
        'nombre',
        'airport_name',
        'nombre_aeropuerto',
      ]);
      final iata = _firstCleanText(airport, const [
        'iata',
        'IATA',
        'iata_code',
        'codigo_iata',
      ]);
      final icao = _firstCleanText(airport, const [
        'icao',
        'ICAO',
        'icao_code',
        'codigo_icao',
        'gps_code',
        'ident',
      ]);
      final code = _airportCode(iata, icao, codeFallback);
      return _AirportSummary(
        label: city ?? name ?? code,
        code: code.isEmpty ? (city ?? name ?? '') : code,
      );
    }

    if (airport != null) {
      final city = airport.city?.toString().trim() ?? '';
      final name = airport.name?.toString().trim() ?? '';
      final code = _airportCode(
        airport.iata?.toString(),
        airport.icao?.toString(),
        codeFallback,
      );
      return _AirportSummary(
        label: city.isNotEmpty ? city : (name.isNotEmpty ? name : code),
        code: code.isEmpty ? (city.isNotEmpty ? city : name) : code,
      );
    }

    final fallbackCity = cityFallback?.trim() ?? '';
    final fallbackCode = _airportCode(null, null, codeFallback);
    return _AirportSummary(
      label: fallbackCity.isNotEmpty ? fallbackCity : fallbackCode,
      code: fallbackCode.isNotEmpty ? fallbackCode : fallbackCity,
    );
  }

  String? _firstCleanText(Map<dynamic, dynamic> values, List<String> keys) {
    for (final key in keys) {
      final value = values[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return null;
  }

  String _airportCode(String? iata, String? icao, String? fallback) {
    final iataText = iata?.trim().toUpperCase() ?? '';
    if (iataText.isNotEmpty) return iataText;

    final icaoText = icao?.trim().toUpperCase() ?? '';
    if (icaoText.isNotEmpty) return icaoText;

    return fallback?.trim().toUpperCase() ?? '';
  }
}

class _FlightSummaryLegRow extends StatelessWidget {
  const _FlightSummaryLegRow({
    required this.index,
    required this.leg,
    required this.showDivider,
    required this.compact,
  });

  final int index;
  final _FlightSummaryLeg leg;
  final bool showDivider;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: compact ? 32 : 34,
              height: compact ? 28 : 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1B2A3D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFD4AD58).withValues(alpha: .32),
                ),
              ),
              child: Text(
                (index + 1).toString().padLeft(2, '0'),
                style: TextStyle(
                  color: const Color(0xFFD4AD58),
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: compact ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /*  Row(
                    children: [
                      Expanded(
                        child: Text(
                          leg.originCity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFFF4F6FA),
                            fontSize: compact ? 13 : 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: const Color(0xFFD4AD58),
                          size: compact ? 15 : 16,
                        ),
                      ),
                     Expanded(
                        child: Text(
                          leg.destinationCity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: const Color(0xFFF4F6FA),
                            fontSize: compact ? 13 : 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),*/
                  const SizedBox(height: 4),
                  Text(
                    '${leg.originCode}  →  ${leg.destinationCode}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF9BAABD),
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(left: compact ? 42 : 46, top: 10),
            child: const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFF25364B),
            ),
          ),
      ],
    );
  }
}

class _FlightSummaryMetric extends StatelessWidget {
  const _FlightSummaryMetric({
    required this.icon,
    required this.label,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFD4AD58), size: compact ? 14 : 15),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFF4F6FA),
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _FlightSummaryLeg {
  const _FlightSummaryLeg({
    required this.originCity,
    required this.destinationCity,
    required this.originCode,
    required this.destinationCode,
  });

  final String originCity;
  final String destinationCity;
  final String originCode;
  final String destinationCode;
}

class _AirportSummary {
  const _AirportSummary({required this.label, required this.code});

  final String label;
  final String code;
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

class _AircraftCatalogRow extends StatelessWidget {
  const _AircraftCatalogRow({
    required this.quote,
    required this.isRecommended,
    required this.isSelected,
    required this.isSelecting,
    required this.isBusy,
    required this.onSelect,
    required this.onCreateRequest,
    required this.actionLabel,
  });

  final Map<String, dynamic> quote;
  final bool isRecommended;
  final bool isSelected;
  final bool isSelecting;
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
    final imageUrl = resolveMediaUrl(_aircraftImageUrl(quote));
    final price = formatQuotePriceLabel(quote);
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
            : 'Tiempo por confirmar';
    final backendBillableLabel =
        formattedTime.isNotEmpty
            ? 'Horas cobrables backend: $formattedTime'
            : '';

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
    final repositioning = _nestedMap(quote['repositioning']);
    final aircraftBaseAirport = _nestedMap(quote['aircraft_base_airport']);
    final requiresRepositioning = quote['requires_repositioning'] == true;
    final baseLabel = _repositioningBaseLabel(
      aircraftBaseAirport,
      fallback: base,
    );
    final repositioningRoute = _repositioningRouteLabel(quote, repositioning);
    final repositioningMeta = _repositioningMetaLabel(quote, repositioning);
    final showAutonomy = autonomy.isNotEmpty && !requiresRepositioning;

    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final compact = constraints.maxWidth < 320;
        final imageWidth = constraints.maxWidth * .40;
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isRecommended) ...[
              const Text(
                '★ Recomendado',
                style: TextStyle(
                  color: Color(0xFFD8B15D),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              aircraft,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 16 : 19,
                height: 1.15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              [
                if (cabin.isNotEmpty) cabin,
                if (capacity.isNotEmpty) '$capacity pasajeros',
              ].join(' · '),
              style: const TextStyle(
                color: Color(0xFFACB6C4),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 5),
              const Text(
                'Seleccionada',
                style: TextStyle(color: Color(0xFFD8B15D), fontSize: 11),
              ),
            ],
          ],
        );
        final commercial = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (requiresRepositioning &&
                (baseLabel.isNotEmpty ||
                    repositioningRoute.isNotEmpty ||
                    repositioningMeta.isNotEmpty))
              _RepositioningPill(
                baseLabel: baseLabel,
                routeLabel: repositioningRoute,
                metaLabel: repositioningMeta,
              )
            else if (base.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFFD8B15D),
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      baseLabel.isNotEmpty ? 'Base: $baseLabel' : 'Base: $base',
                      style: const TextStyle(
                        color: Color(0xFFACB6C4),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, metricConstraints) {
                final total = _AircraftCatalogMetric(
                  label: 'TOTAL',
                  value: price,
                  valueFontSize: 19,
                );
                final duration = _AircraftCatalogMetric(
                  label: 'TIEMPO',
                  value: time,
                  valueFontSize: 17,
                );
                if (largeText || metricConstraints.maxWidth < 170) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [total, const SizedBox(height: 10), duration],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: total),
                    Container(
                      width: 1,
                      height: 35,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: const Color(0x26FFFFFF),
                    ),
                    Expanded(flex: 2, child: duration),
                  ],
                );
              },
            ),
            if (showAutonomy) ...[
              const SizedBox(height: 9),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.route_rounded,
                    color: Color(0xFFD8B15D),
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Autonomía $autonomy',
                      style: const TextStyle(
                        color: Color(0xFFACB6C4),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (backendBillableLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              _BackendBillableHoursChip(
                label: backendBillableLabel,
                dense: true,
              ),
            ],
            const SizedBox(height: 8),
            Semantics(
              label:
                  '${actionLabel.contains('Activar') ? 'Activar aeronave' : 'Crear solicitud'} para $aircraft',
              button: true,
              child: TextButton(
                onPressed: isBusy || isSelecting ? null : onCreateRequest,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD8B15D),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size(48, 48),
                  alignment: Alignment.centerLeft,
                ),
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (isBusy || isSelecting)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFD8B15D),
                        ),
                      ),
                    Text(
                      isSelecting
                          ? 'Seleccionando...'
                          : isBusy
                          ? 'Creando solicitud...'
                          : actionLabel.contains('Activar')
                          ? 'Activar aeronave'
                          : 'Crear solicitud',
                    ),
                    if (!isBusy && !isSelecting)
                      const Icon(Icons.arrow_forward_rounded, size: 19),
                  ],
                ),
              ),
            ),
          ],
        );
        return Column(
          children: [
            InkWell(
              onTap: isSelecting || isBusy ? null : onSelect,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: imageWidth,
                    height: imageWidth * 1.25,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _AircraftMedia(
                          imageUrl: imageUrl,
                          label: cabin.isEmpty ? 'Jet privado' : cabin,
                        ),
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: Tooltip(
                            message: 'Favoritos no disponibles',
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(
                                Icons.favorite_border_rounded,
                                color: Colors.white,
                                size: 23,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        details,
                        if (!compact && !largeText) ...[
                          const SizedBox(height: 10),
                          commercial,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (compact || largeText) ...[
              const SizedBox(height: 14),
              commercial,
            ],
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1, color: Color(0x1FFFFFFF)),
          ],
        );
      },
    );
  }
}

class _AircraftCatalogMetric extends StatelessWidget {
  const _AircraftCatalogMetric({
    required this.label,
    required this.value,
    required this.valueFontSize,
  });

  final String label;
  final String value;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFACB6C4),
            fontSize: 10,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: const Color(0xFFD8B15D),
            fontSize: valueFontSize,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
      borderRadius: BorderRadius.circular(10),
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
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
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
      ),
    );
  }
}

class _ResultsStateCard extends StatelessWidget {
  const _ResultsStateCard({
    required this.state,
    required this.onBackToSearch,
    this.onRetry,
  });

  final QuotePreviewState state;
  final VoidCallback? onBackToSearch;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = switch (state) {
      QuotePreviewState.loading => (
        title: 'Consultando disponibilidad...',
        message: 'Estamos buscando aeronaves para tu itinerario.',
      ),
      QuotePreviewState.validationError || QuotePreviewState.idle => (
        title: 'Completa tu itinerario.',
        message:
            'Agrega origen, destino, fecha y pasajeros para consultar disponibilidad.',
      ),
      QuotePreviewState.serverError => (
        title: 'No fue posible consultar disponibilidad.',
        message:
            'La cotización falló mientras consultábamos el servidor. Puedes reintentar ahora o modificar la búsqueda.',
      ),
      QuotePreviewState.empty => (
        title: 'No encontramos aeronaves disponibles.',
        message:
            'Revisa el origen, la fecha o vuelve a intentarlo para consultar disponibilidad en el aeropuerto de origen y en bases cercanas.',
      ),
      QuotePreviewState.success => (
        title: 'No fue posible mostrar las aeronaves.',
        message:
            'Actualiza la búsqueda para consultar la disponibilidad nuevamente.',
      ),
    };
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
            content.title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content.message,
            style: TextStyle(
              color: palette.textSecondary,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reintentar'),
            ),
          ],
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

class _BackendBillableHoursChip extends StatelessWidget {
  const _BackendBillableHoursChip({required this.label, this.dense = false});

  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFD8B15D).withValues(alpha: dense ? .12 : .1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFD8B15D).withValues(alpha: dense ? .32 : .28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            color: const Color(0xFFD8B15D),
            size: dense ? 11 : 13,
          ),
          SizedBox(width: dense ? 4 : 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    dense
                        ? Colors.white.withValues(alpha: .86)
                        : const Color(0xFF6F4E12),
                fontSize: dense ? 8.5 : 11.5,
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

class _RepositioningPill extends StatelessWidget {
  const _RepositioningPill({
    required this.baseLabel,
    required this.routeLabel,
    required this.metaLabel,
  });

  final String baseLabel;
  final String routeLabel;
  final String metaLabel;

  String _compactBaseLabel() {
    final normalized = baseLabel.trim().toUpperCase();
    if (normalized.isEmpty) return '';

    final tokens =
        normalized
            .split(RegExp(r'\s+'))
            .where((token) => token.isNotEmpty)
            .toList();

    if (tokens.length <= 2) return normalized;

    final codeToken = tokens.firstWhere(
      (token) => RegExp(r'^[A-Z]{3,4}$').hasMatch(token),
      orElse: () => '',
    );
    if (codeToken.isNotEmpty) return codeToken;

    return tokens.take(2).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final compactBaseLabel = _compactBaseLabel();
    final title =
        compactBaseLabel.isEmpty
            ? 'Reposicionamiento'
            : 'Reposicionamiento desde $compactBaseLabel';
    final detailParts = <String>[
      if (routeLabel.trim().isNotEmpty) routeLabel.trim(),
      if (metaLabel.trim().isNotEmpty) metaLabel.trim(),
      'Incluido en la tarifa',
    ];
    final detailLine = detailParts.join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFD8B15D),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            detailLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .68),
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _repositioningBaseLabel(
  Map<String, dynamic> aircraftBaseAirport, {
  String fallback = '',
}) {
  return _firstText(aircraftBaseAirport, const [
        'city',
        'name',
        'icao',
        'iata',
      ]).trim().isNotEmpty
      ? _firstText(aircraftBaseAirport, const ['city', 'name', 'icao', 'iata'])
      : fallback;
}

String _repositioningRouteLabel(
  Map<String, dynamic> quote,
  Map<String, dynamic> repositioning,
) {
  final origin = _firstText(repositioning, const [
    'origin_icao',
    'origin_iata',
  ]);
  final destination = _firstText(repositioning, const [
    'destination_icao',
    'destination_iata',
  ]);
  if (origin.isEmpty || destination.isEmpty) return '';
  return '$origin -> $destination';
}

String _repositioningMetaLabel(
  Map<String, dynamic> quote,
  Map<String, dynamic> repositioning,
) {
  final distanceNm = _resultNumber(
    repositioning['distance_nm'] ?? quote['repositioning_distance_nm'],
  );
  final flightHours = _resultNumber(
    repositioning['flight_hours'] ??
        repositioning['operational_hours'] ??
        quote['repositioning_hours'],
  );
  final parts = <String>[];
  if (distanceNm > 0) {
    parts.add('${distanceNm.round()} NM');
  }
  final minutes = (flightHours * 60).round();
  if (minutes > 0) {
    parts.add('$minutes min');
  }
  return parts.join(' · ');
}

Map<String, dynamic> _nestedMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

double _resultNumber(dynamic value) {
  if (value is num) return value.toDouble();
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return 0;
  return double.tryParse(text.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;
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
