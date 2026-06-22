import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../models/aeronave.dart';
import '../tema_cliente.dart';
import '../widgets/widgets_experiencia_cliente.dart';

class ClientAircraftDetailScreen extends StatelessWidget {
  const ClientAircraftDetailScreen({
    super.key,
    required this.aircraft,
    this.request,
  });

  final Aircraft aircraft;
  final Map<String, dynamic>? request;

  String get _category {
    final type = aircraft.aircraftType.toLowerCase();

    if (type.contains('heavy')) return 'Jet pesado';
    if (type.contains('super')) return 'Super mediano';
    if (type.contains('mid')) return 'Jet mediano';
    if (type.contains('turbo')) return 'Turbohélice';
    if (type.contains('helic')) return 'Helicóptero';

    return 'Jet ligero';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final baseFare = aircraft.rentalPriceUsd * aircraft.minimumHours;

    return ClientExperienceShell(
      title: aircraft.name.isEmpty ? 'Aeronave' : aircraft.name,
      subtitle: 'Detalle ejecutivo.',
      child: Container(
        color: palette.background,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _AircraftHeaderCard(
              aircraft: aircraft,
              request: request,
              category: _category,
              baseFare: baseFare,
            ),

            const SizedBox(height: 16),

            _AircraftSpecsCard(aircraft: aircraft, baseFare: baseFare),
          ],
        ),
      ),
    );
  }
}

class _AircraftHeaderCard extends StatelessWidget {
  const _AircraftHeaderCard({
    required this.aircraft,
    required this.request,
    required this.category,
    required this.baseFare,
  });

  final Aircraft aircraft;
  final Map<String, dynamic>? request;
  final String category;
  final double baseFare;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final isDark = context.isDarkMode;
    final title = aircraft.name.isEmpty ? 'Aeronave ejecutiva' : aircraft.name;
    final location =
        aircraft.homeBase.isEmpty ? aircraft.city : aircraft.homeBase;
    final capacityLabel = '${aircraft.capacityPassengers} pasajeros';
    final segments = _requestSegments(request);
    final hasRequestContext = request != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SmallBadge(label: category),
              const Spacer(),
              _TinyLabel(icon: Icons.place_rounded, label: location),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 32,
              height: 0.98,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(icon: Icons.groups_rounded, label: capacityLabel),
              _InfoChip(
                icon: Icons.speed_rounded,
                label: '${aircraft.cruiseSpeedKnots.toStringAsFixed(0)} kts',
              ),
              _InfoChip(
                icon: Icons.schedule_rounded,
                label: 'Min. ${aircraft.minimumHours.toStringAsFixed(1)} hrs',
              ),
            ],
          ),
          if (hasRequestContext) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.calendar_month_rounded,
                  label: _requestDepartureCopy(request),
                ),
                _InfoChip(
                  icon: Icons.groups_rounded,
                  label:
                      '${_requestPassengerCount(request)} ${_requestPassengerCount(request) == 1 ? 'pasajero' : 'pasajeros'}',
                ),
                if (segments.isNotEmpty)
                  _InfoChip(
                    icon: Icons.alt_route_rounded,
                    label: '${segments.length} tramos',
                  ),
              ],
            ),
          ],
          if (aircraft.imageUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _AircraftHeroImage(imageUrl: aircraft.imageUrl, title: title),
          ],
          if (segments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  segments
                      .map(
                        (segment) => _RouteSegmentChip(
                          label:
                              'Tramo ${segment.order} · ${segment.origin} -> ${segment.destination}',
                        ),
                      )
                      .toList(),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: isDark ? palette.primary : palette.surfaceSoft,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DESDE',
                  style: TextStyle(
                    color:
                        isDark
                            ? palette.heroTextSecondary
                            : palette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${formatMoney(baseFare)} USD',
                  style: TextStyle(
                    color:
                        isDark ? palette.heroTextPrimary : palette.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatMoney(aircraft.rentalPriceUsd)}/hr • Min. ${aircraft.minimumHours.toStringAsFixed(1)} hrs',
                  style: TextStyle(
                    color:
                        isDark
                            ? palette.heroTextSecondary
                            : palette.textSecondary,
                    fontSize: 12.5,
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
}

class _AircraftSpecsCard extends StatelessWidget {
  const _AircraftSpecsCard({required this.aircraft, required this.baseFare});

  final Aircraft aircraft;
  final double baseFare;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final location =
        aircraft.homeBase.isEmpty ? aircraft.city : aircraft.homeBase;
    final description =
        '${aircraft.name.isEmpty ? 'Esta aeronave' : aircraft.name} es ideal para vuelos ejecutivos ${_routeScopeLabel(aircraft)} con capacidad para hasta ${aircraft.capacityPassengers} pasajeros.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Descripción',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                'Ver especificaciones',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_rounded,
                color: palette.textPrimary,
                size: 18,
              ),
              children: [
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.95,
                  children: [
                    _SpecTile(
                      icon: Icons.place_rounded,
                      label: 'Base',
                      value: location.toUpperCase(),
                    ),
                    _SpecTile(
                      icon: Icons.nightlight_round,
                      label: 'Overnight',
                      value:
                          aircraft.crewOvernightUsd <= 0
                              ? 'Incluido'
                              : formatMoney(aircraft.crewOvernightUsd),
                    ),
                    _SpecTile(
                      icon: Icons.flag_rounded,
                      label: 'Nacional',
                      value:
                          aircraft.nationalExpensesUsd <= 0
                              ? 'Incluido'
                              : formatMoney(aircraft.nationalExpensesUsd),
                    ),
                    _SpecTile(
                      icon: Icons.public_rounded,
                      label: 'Internacional',
                      value:
                          aircraft.internationalExpensesUsd <= 0
                              ? 'Segun ruta'
                              : formatMoney(aircraft.internationalExpensesUsd),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AircraftHeroImage extends StatelessWidget {
  const _AircraftHeroImage({required this.imageUrl, required this.title});

  final String imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 112,
        width: double.infinity,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _AircraftImageFallback(title: title),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _AircraftImageFallback(title: title);
          },
        ),
      ),
    );
  }
}

String _routeScopeLabel(Aircraft aircraft) {
  final type = aircraft.aircraftType.toLowerCase();
  if (type.contains('heavy') || type.contains('super')) {
    return 'nacionales e internacionales';
  }
  return 'nacionales y regionales';
}

class _AircraftImageFallback extends StatelessWidget {
  const _AircraftImageFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF6F1E8), Color(0xFFE8DECC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          title.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF8C7D6A),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}

class _TinyLabel extends StatelessWidget {
  const _TinyLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: palette.textSecondary),
        const SizedBox(width: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:
            context.isDarkMode
                ? palette.surfaceSoft
                : Color.lerp(palette.surface, palette.background, 0.38) ??
                    palette.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: palette.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color:
            context.isDarkMode
                ? palette.accentSoft
                : Color.lerp(palette.accentSoft, palette.surface, 0.35) ??
                    palette.accentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _RouteSegmentChip extends StatelessWidget {
  const _RouteSegmentChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:
            context.isDarkMode
                ? palette.surfaceSoft
                : Color.lerp(palette.surface, palette.background, 0.38) ??
                    palette.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SpecTile extends StatelessWidget {
  const _SpecTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: palette.textSecondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    height: 1,
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

String _requestDepartureCopy(Map<String, dynamic>? request) {
  if (request == null) return 'Fecha por definir';
  final raw =
      request['departure_datetime']?.toString() ??
      request['start_datetime']?.toString() ??
      request['departure_at']?.toString() ??
      request['scheduled_at']?.toString() ??
      request['date']?.toString();
  final parsed = raw == null ? null : DateTime.tryParse(raw);
  if (parsed == null) return 'Fecha por definir';

  final hour =
      parsed.hour == 0
          ? 12
          : (parsed.hour > 12 ? parsed.hour - 12 : parsed.hour);
  final minute = parsed.minute.toString().padLeft(2, '0');
  final suffix = parsed.hour >= 12 ? 'p.m.' : 'a.m.';
  const months = [
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
  final month = months[parsed.month - 1];
  return '${parsed.day}-$month, $hour:$minute $suffix';
}

int _requestPassengerCount(Map<String, dynamic>? request) {
  if (request == null) return 1;
  final candidates = [
    request['passengers'],
    request['passenger_count'],
    request['pax'],
    request['seats'],
  ];
  for (final value in candidates) {
    if (value is num && value > 0) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null && parsed > 0) return parsed;
  }
  return 1;
}

class _RequestSegment {
  const _RequestSegment({
    required this.order,
    required this.origin,
    required this.destination,
  });

  final int order;
  final String origin;
  final String destination;
}

List<_RequestSegment> _requestSegments(Map<String, dynamic>? request) {
  if (request == null) return const [];

  final routeItems =
      request['routes'] ?? request['segments'] ?? request['legs'];
  if (routeItems is List) {
    final parsed =
        routeItems
            .asMap()
            .entries
            .map((entry) {
              final item = entry.value;
              if (item is! Map) return null;
              final map = Map<String, dynamic>.from(item);
              final origin =
                  (map['origin'] ??
                          map['source_origin'] ??
                          map['from'] ??
                          map['from_airport'] ??
                          '')
                      .toString()
                      .trim();
              final destination =
                  (map['destination'] ??
                          map['source_destination'] ??
                          map['to'] ??
                          map['to_airport'] ??
                          '')
                      .toString()
                      .trim();
              if (origin.isEmpty || destination.isEmpty) return null;
              return _RequestSegment(
                order: entry.key + 1,
                origin: origin.toUpperCase(),
                destination: destination.toUpperCase(),
              );
            })
            .whereType<_RequestSegment>()
            .toList();
    if (parsed.isNotEmpty) return parsed;
  }

  final requirements = request['requirements'];
  if (requirements is List && requirements.isNotEmpty) {
    final parsed = <_RequestSegment>[];
    final baseOrigin =
        (request['origin'] ??
                request['from'] ??
                request['source_origin'] ??
                request['from_airport'] ??
                '')
            .toString()
            .trim();
    final baseDestination =
        (request['destination'] ??
                request['to'] ??
                request['source_destination'] ??
                request['to_airport'] ??
                '')
            .toString()
            .trim();

    if (baseOrigin.isNotEmpty || baseDestination.isNotEmpty) {
      parsed.add(
        _RequestSegment(
          order: 1,
          origin:
              baseOrigin.isEmpty
                  ? 'ORIGEN POR CONFIRMAR'
                  : baseOrigin.toUpperCase(),
          destination:
              baseDestination.isEmpty
                  ? 'DESTINO POR CONFIRMAR'
                  : baseDestination.toUpperCase(),
        ),
      );
    }

    for (final leg in requirements) {
      if (leg is! Map) continue;
      final map = Map<String, dynamic>.from(leg);
      final origin = (map['origin'] ?? '').toString().trim();
      final destination = (map['destination'] ?? '').toString().trim();
      if (origin.isEmpty && destination.isEmpty) continue;
      parsed.add(
        _RequestSegment(
          order: parsed.length + 1,
          origin:
              origin.isEmpty ? 'ORIGEN POR CONFIRMAR' : origin.toUpperCase(),
          destination:
              destination.isEmpty
                  ? 'DESTINO POR CONFIRMAR'
                  : destination.toUpperCase(),
        ),
      );
    }

    if (parsed.isNotEmpty) return parsed;
  }

  final origin =
      (request['origin'] ??
              request['from'] ??
              request['source_origin'] ??
              request['from_airport'] ??
              '')
          .toString()
          .trim();
  final destination =
      (request['destination'] ??
              request['to'] ??
              request['source_destination'] ??
              request['to_airport'] ??
              '')
          .toString()
          .trim();
  if (origin.isEmpty || destination.isEmpty) return const [];
  return [
    _RequestSegment(
      order: 1,
      origin: origin.toUpperCase(),
      destination: destination.toUpperCase(),
    ),
  ];
}
