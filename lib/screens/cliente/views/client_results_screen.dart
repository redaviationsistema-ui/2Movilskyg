import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/reservation_provider.dart';
import '../widgets/client_mobile_flow_widgets.dart';

class ClientResultsScreen extends StatefulWidget {
  const ClientResultsScreen({
    super.key,
    this.onBackToSearch,
    this.userInitial = 'C',
  });

  final VoidCallback? onBackToSearch;
  final String userInitial;

  @override
  State<ClientResultsScreen> createState() => _ClientResultsScreenState();
}

class _ClientResultsScreenState extends State<ClientResultsScreen> {
  String _activeFilter = 'recommended';
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
                FilterChipButton(
                  label: _filterLabel(_activeFilter),
                  isActive: true,
                  onTap: _cycleFilter,
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
            _FeaturedMatchCard(match: featuredMatch),
            const SizedBox(height: 12),
            if (secondaryMatches.isNotEmpty)
              ...secondaryMatches.map(
                (match) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SecondaryMatchCard(match: match),
                ),
              ),
            const SizedBox(height: 6),
            _BackToSearchButton(onTap: _backToSearch),
          ],
        ],
      ),
    );
  }

  void _cycleFilter() {
    const order = ['recommended', 'value', 'fastest', 'exclusive'];
    final currentIndex = order.indexOf(_activeFilter);
    setState(() {
      _activeFilter = order[(currentIndex + 1) % order.length];
    });
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
    final matches = List<Map<String, dynamic>>.from(source);
    if (_activeFilter == 'value') {
      matches.sort((a, b) => _numericPrice(a).compareTo(_numericPrice(b)));
    } else if (_activeFilter == 'fastest') {
      matches.sort((a, b) => _durationScore(a).compareTo(_durationScore(b)));
    } else if (_activeFilter == 'exclusive') {
      matches.sort((a, b) => _exclusiveScore(b).compareTo(_exclusiveScore(a)));
    }
    return matches;
  }

  double _numericPrice(Map<String, dynamic> match) {
    final raw =
        match['final_price']?.toString() ??
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

  String _filterLabel(String filter) {
    switch (filter) {
      case 'value':
        return 'Mejor inversion';
      case 'fastest':
        return 'Mas rapido';
      case 'exclusive':
        return 'Mayor exclusividad';
      default:
        return 'Recomendado por asesor';
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
  const _FeaturedMatchCard({required this.match});

  final Map<String, dynamic> match;

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
        ],
      ),
    );
  }
}

class _SecondaryMatchCard extends StatelessWidget {
  const _SecondaryMatchCard({required this.match});

  final Map<String, dynamic> match;

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

    return ConciergeCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Opcion privada',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9A6F28),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  aircraft,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(time, style: const TextStyle(color: Color(0xFF5F564C))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(price, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
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
