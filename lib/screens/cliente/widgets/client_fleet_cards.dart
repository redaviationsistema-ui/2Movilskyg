import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/aircraft.dart';
import '../../../models/marketplace_models.dart';
import '../../../providers/reservation_provider.dart';

class ClientFleetSection extends StatelessWidget {
  const ClientFleetSection({super.key, required this.aircraft});

  final List<Aircraft> aircraft;

  @override
  Widget build(BuildContext context) {
    return Column(
      children:
          aircraft
              .map((item) => _AircraftAvailabilityCard(aircraft: item))
              .toList(),
    );
  }
}

class ClientCancellationSection extends StatelessWidget {
  const ClientCancellationSection({super.key, required this.rules});

  final List<CancellationRule> rules;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rules.map((rule) => _CancellationRuleCard(rule: rule)).toList(),
    );
  }
}

class _AircraftAvailabilityCard extends StatelessWidget {
  const _AircraftAvailabilityCard({required this.aircraft});

  final Aircraft aircraft;

  AvailabilityBadgeData _resolveAvailability(ReservationProvider provider) {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    bool blockedFor(DateTime date) {
      return provider.reservations.any((reservation) {
        if (reservation['aircraftId'] != aircraft.id) return false;
        final start = reservation['startDatetime'] as DateTime?;
        final end = reservation['endDatetime'] as DateTime?;
        if (start == null || end == null) return false;
        return !date.isBefore(start) && !date.isAfter(end);
      });
    }

    if (!blockedFor(now)) {
      return const AvailabilityBadgeData(
        label: 'Disponible hoy',
        helper: 'Puede avanzar a reserva o preconfirmacion operativa.',
      );
    }
    if (!blockedFor(tomorrow)) {
      return const AvailabilityBadgeData(
        label: 'Disponible manana',
        helper: 'Salida de baja anticipacion con validacion rapida.',
      );
    }
    return const AvailabilityBadgeData(
      label: 'Bajo validacion',
      helper: 'Requiere revisar tripulacion, slots o reposicionamiento.',
    );
  }

  String _categoryLabel() {
    final type = aircraft.aircraftType.toLowerCase();
    if (type.contains('heavy')) return 'Heavy Jet';
    if (type.contains('super')) return 'Super mediano';
    if (type.contains('mid')) return 'Jet mediano';
    if (type.contains('turbo')) return 'Turbohelice';
    if (type.contains('helic')) return 'Helicoptero';
    return 'Light Jet';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReservationProvider>();
    final availability = _resolveAvailability(provider);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF8FBFD)],
        ),
        border: Border.all(color: const Color(0xFFE4EAF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120E2238),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      aircraft.name.isEmpty
                          ? 'Aeronave sin nombre'
                          : aircraft.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0E2238),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_categoryLabel()} | ${aircraft.capacityPassengers} pasajeros | Base ${aircraft.homeBase}',
                      style: const TextStyle(color: Color(0xFF536274)),
                    ),
                  ],
                ),
              ),
              _AvailabilityPill(label: availability.label),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            availability.helper,
            style: const TextStyle(color: Color(0xFF536274), height: 1.35),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SpecChip(
                label: '\$${aircraft.rentalPriceUsd.toStringAsFixed(0)}/hr',
              ),
              _SpecChip(
                label: '${aircraft.cruiseSpeedKnots.toStringAsFixed(0)} kts',
              ),
              _SpecChip(
                label: 'Min ${aircraft.minimumHours.toStringAsFixed(1)} hrs',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CancellationRuleCard extends StatelessWidget {
  const _CancellationRuleCard({required this.rule});

  final CancellationRule rule;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFCF6)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E1D2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.policy_outlined, color: Color(0xFFE0AF57)),
          const SizedBox(height: 10),
          Text(
            rule.window,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0E2238),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rule.penalty,
            style: const TextStyle(
              color: Color(0xFFB46A00),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rule.action,
            style: const TextStyle(color: Color(0xFF536274), height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final color =
        normalized.contains('hoy')
            ? const Color(0xFF1B8F4D)
            : normalized.contains('manana')
            ? const Color(0xFFB46A00)
            : const Color(0xFF345C84);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF0E2238),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
