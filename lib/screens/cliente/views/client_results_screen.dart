import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/reservation_provider.dart';
import '../../reservation/quote_preview_screen.dart';
import '../widgets/client_mobile_flow_widgets.dart';

class ClientResultsScreen extends StatefulWidget {
  const ClientResultsScreen({
    super.key,
    this.onBackToSearch,
    this.onReservationCreated,
    this.userInitial = 'C',
  });

  final VoidCallback? onBackToSearch;
  final ValueChanged<String?>? onReservationCreated;
  final String userInitial;

  @override
  State<ClientResultsScreen> createState() => _ClientResultsScreenState();
}

class _ClientResultsScreenState extends State<ClientResultsScreen> {
  String _activeFilter = 'recommended';
  String? _reservingAircraftId;
  final DateFormat _dateFormat = DateFormat(
    "d 'de' MMMM 'de' y · h:mm a",
    'es',
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReservationProvider>();
    final sortedMatches = _sortedMatches(provider.quoteMatches);
    final featuredMatch = sortedMatches.isEmpty ? null : sortedMatches.first;
    final secondaryMatches =
        sortedMatches.length <= 1 ? const [] : sortedMatches.sublist(1);

    return ClientMobileScreenShell(
      userInitial: widget.userInitial,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
        children: [
          const EyebrowLabel(label: 'Luxury concierge selection'),
          const SizedBox(height: 6),
          Text(
            _headline(provider),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _dateLine(provider),
            style: const TextStyle(color: Color(0xFF5F564C)),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tu asesor privado ha seleccionado las mejores opciones para esta ruta.',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
              height: 1.35,
            ),
          ),
          const Text(
            'Opciones verificadas segun velocidad, costo y nivel de experiencia.',
            style: TextStyle(color: Color(0xFF5F564C), height: 1.35),
          ),
          const SizedBox(height: 12),
          ConciergeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COMPARAR POR',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E2A26),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Prioriza criterio experto, inversion, rapidez o exclusividad.',
                  style: TextStyle(
                    color: Color(0xFF4F473E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _filterOptions.map((filter) {
                        return _ResultFilterButton(
                          label: filter.label,
                          isActive: _activeFilter == filter.key,
                          onTap:
                              () => setState(() {
                                _activeFilter = filter.key;
                              }),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'PAQUETE DE SERVICIO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E2A26),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option
                        in ReservationProvider.priorityLabels.entries)
                      ChoiceChip(
                        label: Text(option.value),
                        selected: provider.selectedPriorityType == option.key,
                        onSelected:
                            (_) => provider.setSelectedPriorityType(option.key),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (provider.isLoadingQuotePreview)
            const LoadingBand(text: 'Haciendo match con operadores activos...')
          else if (provider.quoteError != null && sortedMatches.isEmpty)
            ConciergeCard(
              child: Text(
                provider.quoteError!,
                style: const TextStyle(
                  color: Color(0xFF8D1F1A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (featuredMatch == null)
            ConciergeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Todavia no hay una opcion para reservar.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vuelve a buscar desde la pantalla anterior para consultar opciones vivas del backend.',
                    style: TextStyle(color: Color(0xFF5F564C), height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  _BackToSearchButton(onTap: _backToSearch),
                ],
              ),
            )
          else ...[
            _FeaturedMatchCard(
              match: featuredMatch,
              isReserving: _isReserving(featuredMatch),
              onReserve: () => _reserve(featuredMatch),
            ),
            const SizedBox(height: 12),
            if (secondaryMatches.isNotEmpty)
              ...secondaryMatches.map(
                (match) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SecondaryMatchCard(
                    match: match,
                    isReserving: _isReserving(match),
                    onReserve: () => _reserve(match),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            _BackToSearchButton(onTap: _backToSearch),
          ],
        ],
      ),
    );
  }

  String _headline(ReservationProvider provider) {
    final route = provider.routes.first;
    final origin =
        route.fromAirport?.city ?? route.fromAirport?.iata ?? 'Origen';
    final destination =
        route.toAirport?.city ?? route.toAirport?.iata ?? 'Destino';
    return '$origin -> $destination';
  }

  String _dateLine(ReservationProvider provider) {
    final route = provider.routes.first;
    final departure = route.startDate ?? provider.startDate;
    if (departure == null) {
      return 'Salida por confirmar';
    }
    return _dateFormat.format(departure);
  }

  List<Map<String, dynamic>> _sortedMatches(List<Map<String, dynamic>> source) {
    final matches =
        source
            .asMap()
            .entries
            .map((entry) => {...entry.value, '_originalIndex': entry.key})
            .toList();
    if (_activeFilter == 'value') {
      matches.sort((a, b) => _numericPrice(a).compareTo(_numericPrice(b)));
    } else if (_activeFilter == 'fastest') {
      matches.sort((a, b) => _durationScore(a).compareTo(_durationScore(b)));
    } else if (_activeFilter == 'exclusive') {
      matches.sort((a, b) => _exclusiveScore(b).compareTo(_exclusiveScore(a)));
    } else {
      matches.sort(
        (a, b) => _recommendedScore(b).compareTo(_recommendedScore(a)),
      );
    }
    return matches;
  }

  double _numericPrice(Map<String, dynamic> match) {
    final raw =
        match['final_price']?.toString() ??
        match['total']?.toString() ??
        match['price']?.toString() ??
        match['estimated_total']?.toString() ??
        '';
    final normalized = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(normalized) ?? double.infinity;
  }

  double _durationScore(Map<String, dynamic> match) {
    final raw =
        match['flight_time']?.toString() ?? match['time']?.toString() ?? '';
    final values =
        RegExp(r'\d+').allMatches(raw).map((m) => m.group(0)).toList();
    if (values.isEmpty) return double.infinity;
    final hours = double.tryParse(values.first ?? '') ?? 0;
    final minutes =
        values.length > 1 ? double.tryParse(values[1] ?? '') ?? 0 : 0;
    return hours * 60 + minutes;
  }

  double _exclusiveScore(Map<String, dynamic> match) {
    final capacity = double.tryParse(match['capacity']?.toString() ?? '') ?? 0;
    final price = _numericPrice(match);
    return capacity + (price.isFinite ? price / 100000 : 0);
  }

  double _recommendedScore(Map<String, dynamic> match) {
    final price = _numericPrice(match);
    final duration = _durationScore(match);
    final exclusivity = _exclusiveScore(match);
    final mediaScore = _aircraftImage(match)?.isNotEmpty == true ? 8 : 0;
    final originScore =
        (match['source_origin']?.toString().trim().isNotEmpty ?? false) ? 6 : 0;
    final originalIndex =
        double.tryParse(match['_originalIndex']?.toString() ?? '') ?? 0;

    final priceComponent = price.isFinite ? 250000 / (price + 1) : 0;
    final durationComponent = duration.isFinite ? 1500 / (duration + 1) : 0;

    return exclusivity * 12 +
        mediaScore +
        originScore +
        durationComponent +
        priceComponent +
        (originalIndex == 0 ? 24 : 0);
  }

  List<({String key, String label})> get _filterOptions => const [
    (key: 'recommended', label: 'Recomendado por asesor'),
    (key: 'value', label: 'Mejor inversion'),
    (key: 'fastest', label: 'Salida mas rapida'),
    (key: 'exclusive', label: 'Mayor exclusividad'),
  ];

  bool _isReserving(Map<String, dynamic> match) {
    final id =
        match['match_id']?.toString() ??
        match['matched_option_id']?.toString() ??
        match['id']?.toString() ??
        '';
    return _reservingAircraftId != null && _reservingAircraftId == id;
  }

  Future<void> _reserve(Map<String, dynamic> match) async {
    final reservation = context.read<ReservationProvider>();
    final matchId =
        match['match_id']?.toString() ??
        match['matched_option_id']?.toString() ??
        match['id']?.toString() ??
        '';

    setState(() {
      _reservingAircraftId = matchId;
    });

    try {
      reservation.setSelectedQuoteMatch(match);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => QuotePreviewScreen(
                onReservationCreated: widget.onReservationCreated,
              ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al reservar: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _reservingAircraftId = null;
        });
      }
    }
  }

  void _backToSearch() {
    if (widget.onBackToSearch != null) {
      widget.onBackToSearch!();
      return;
    }
    Navigator.of(context).maybePop();
  }
}

class _FeaturedMatchCard extends StatelessWidget {
  const _FeaturedMatchCard({
    required this.match,
    required this.onReserve,
    required this.isReserving,
  });

  final Map<String, dynamic> match;
  final VoidCallback onReserve;
  final bool isReserving;

  @override
  Widget build(BuildContext context) {
    final aircraft =
        (match['aircraft_name'] ??
                match['aircraft'] ??
                match['model'] ??
                'Aeronave')
            .toString();
    final price =
        (match['final_price'] ?? match['price'] ?? 'Cotizacion privada')
            .toString();
    final time =
        (match['flight_time'] ?? match['time'] ?? 'Tiempo por confirmar')
            .toString();
    final reason =
        (match['match_reason'] ??
                'Seleccion destacada por disponibilidad real.')
            .toString();
    final sourceOrigin =
        (match['source_origin'] ?? 'Base operativa').toString();

    return ConciergeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AircraftMedia(
            imageUrl: _aircraftImage(match),
            height: 196,
            label: aircraft,
            badge: 'Selección privada',
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEE4),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Recomendado',
              style: TextStyle(
                color: Color(0xFF2B2723),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            aircraft,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '$time · $sourceOrigin',
            style: const TextStyle(
              color: Color(0xFF5F564C),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tarifa estimada total',
            style: const TextStyle(
              color: Color(0xFF6F675E),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            style: const TextStyle(color: Color(0xFF3D3832), height: 1.35),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isReserving ? null : onReserve,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF151515),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(isReserving ? 'Reservando...' : 'Reservar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryMatchCard extends StatelessWidget {
  const _SecondaryMatchCard({
    required this.match,
    required this.onReserve,
    required this.isReserving,
  });

  final Map<String, dynamic> match;
  final VoidCallback onReserve;
  final bool isReserving;

  @override
  Widget build(BuildContext context) {
    final aircraft =
        (match['aircraft_name'] ??
                match['aircraft'] ??
                match['model'] ??
                'Aeronave')
            .toString();
    final price =
        (match['final_price'] ?? match['price'] ?? 'Cotizacion privada')
            .toString();
    final time =
        (match['flight_time'] ?? match['time'] ?? 'Tiempo por confirmar')
            .toString();
    final sourceOrigin =
        (match['source_origin'] ?? 'Base operativa').toString();
    final reason =
        (match['match_reason'] ??
                'Seleccion destacada por disponibilidad real.')
            .toString();

    return ConciergeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AircraftMedia(
            imageUrl: _aircraftImage(match),
            height: 168,
            label: aircraft,
            badge: 'Selección privada',
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F3E8),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Opción privada',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9A6F28),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            aircraft,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '$time · $sourceOrigin',
            style: const TextStyle(
              color: Color(0xFF5F564C),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tarifa estimada total',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6F675E),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF3D3832), height: 1.35),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isReserving ? null : onReserve,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF151515),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(isReserving ? 'Reservando...' : 'Reservar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultFilterButton extends StatelessWidget {
  const _ResultFilterButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF151515) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? const Color(0xFF151515) : const Color(0xFFE0D6C8),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF1F1B18),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _AircraftMedia extends StatelessWidget {
  const _AircraftMedia({
    required this.imageUrl,
    required this.height,
    required this.label,
    this.badge,
  });

  final String? imageUrl;
  final double height;
  final String label;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final media = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors:
                    imageUrl == null || imageUrl!.isEmpty
                        ? const [Color(0xFFE7DDD0), Color(0xFFBDAA8E)]
                        : const [Color(0xFFDCCFBE), Color(0xFF8E7A63)],
              ),
            ),
          ),
          if (imageUrl != null && imageUrl!.isNotEmpty)
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => const Center(
                    child: Icon(
                      Icons.flight_rounded,
                      size: 42,
                      color: Colors.white70,
                    ),
                  ),
            )
          else
            const Center(
              child: Icon(
                Icons.flight_rounded,
                size: 42,
                color: Colors.white70,
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.06),
                  Colors.black.withValues(alpha: 0.42),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return SizedBox(width: double.infinity, height: height, child: media);
  }
}

String? _aircraftImage(Map<String, dynamic> match) {
  final directCandidates = [
    match['image_url'],
    match['imageUrl'],
    match['main_image'],
    match['aircraft_image'],
  ];

  for (final candidate in directCandidates) {
    final value = candidate?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }

  final nestedCandidates = [
    match['aircraft'],
    match['aeronave'],
    match['selected_aircraft'],
  ];

  for (final candidate in nestedCandidates) {
    if (candidate is Map) {
      final value =
          candidate['image_url']?.toString().trim() ??
          candidate['imageUrl']?.toString().trim() ??
          candidate['main_image']?.toString().trim() ??
          '';
      if (value.isNotEmpty) return value;
    }
  }

  final imageCollection = match['aircraft_images'] ?? match['images'];
  if (imageCollection is List) {
    for (final item in imageCollection) {
      if (item is Map) {
        final value =
            item['image_url']?.toString().trim() ??
            item['imageUrl']?.toString().trim() ??
            item['url']?.toString().trim() ??
            '';
        if (value.isNotEmpty) return value;
      }
    }
  }

  return null;
}

class _BackToSearchButton extends StatelessWidget {
  const _BackToSearchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF151515),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Volver a buscar',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
