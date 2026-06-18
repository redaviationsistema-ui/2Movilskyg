import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/acceso_comercial_cliente.dart';
import '../../../providers/proveedor_autenticacion.dart';
import '../../../providers/proveedor_reservaciones.dart';

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

  @override
  Widget build(BuildContext context) {
    final reservation = context.watch<ReservationProvider>();
    final auth = context.watch<AuthProvider>();
    final accessState = resolveCommercialAccessState(auth.accessData);
    final matches = reservation.quoteMatches;
    final selected = reservation.selectedQuoteMatch;
    final createActionLabel =
        accessState.canReserve ? 'Crear solicitud' : 'Activar acceso comercial';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
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
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                children: [
                  const Text(
                    'Aeronaves disponibles',
                    style: TextStyle(
                      color: Color(0xFF050505),
                      fontSize: 28,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Selecciona tu opcion y crea la solicitud en segundos.',
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (reservation.quoteError != null) ...[
                    _InfoCard(text: reservation.quoteError!),
                    const SizedBox(height: 14),
                  ],
                  if (matches.isEmpty)
                    _EmptyResultsCard(onBackToSearch: widget.onBackToSearch)
                  else
                    ...matches.map(
                      (match) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accessState.reservationBlockedMessage)),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud creada correctamente.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear la solicitud: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingRequest = false;
        });
      }
    }
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
    final imageUrl = _aircraftImageUrl(quote);
    final price = _moneyLabel(
      quote['final_price'] ?? quote['total'] ?? quote['price'],
    );
    final time = _firstText(quote, const ['flight_time', 'time', 'duration']);
    final reason = _firstText(quote, const ['match_reason', 'source_origin']);

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF050505) : const Color(0xFFE7E7E7),
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 18,
              offset: Offset(0, 8),
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
            const SizedBox(height: 12),
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
                        style: const TextStyle(
                          color: Color(0xFF050505),
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
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected) const Icon(Icons.check_circle_rounded),
              ],
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
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
                  backgroundColor: const Color(0xFF050505),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE4E4E4),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon:
                    isBusy
                        ? const SizedBox(
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF050505),
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
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              )
            else
              const Center(child: _AircraftMediaEmpty()),
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
                        color: Colors.white.withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF050505),
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
  const _AircraftMediaEmpty();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.flight_rounded, color: Colors.white, size: 28),
        SizedBox(height: 8),
        Text(
          'Imagen en validacion',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _EmptyResultsCard extends StatelessWidget {
  const _EmptyResultsCard({required this.onBackToSearch});

  final VoidCallback? onBackToSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No hay aeronaves para esta busqueda.',
            style: TextStyle(
              color: Color(0xFF050505),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ajusta origen, fecha o pasajeros y vuelve a buscar disponibilidad.',
            style: TextStyle(
              color: Color(0xFF666666),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onBackToSearch != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onBackToSearch,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF050505),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF111111),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE7E7E7)),
        ),
        child: Icon(icon, color: const Color(0xFF050505)),
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
