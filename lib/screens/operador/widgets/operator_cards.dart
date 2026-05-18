import 'package:flutter/material.dart';

import '../../../models/aircraft.dart';
import '../../../models/marketplace_models.dart';

class OperatorRequestList extends StatelessWidget {
  const OperatorRequestList({super.key, required this.requests});

  final List<OperatorRequest> requests;

  @override
  Widget build(BuildContext context) {
    return Column(
      children:
          requests
              .map((request) => _OperatorRequestCard(request: request))
              .toList(),
    );
  }
}

class OperatorFleetList extends StatelessWidget {
  const OperatorFleetList({super.key, required this.aircraft});

  final List<Aircraft> aircraft;

  @override
  Widget build(BuildContext context) {
    return Column(
      children:
          aircraft
              .map((item) => _OperatorAircraftCard(aircraft: item))
              .toList(),
    );
  }
}

class _OperatorRequestCard extends StatelessWidget {
  const _OperatorRequestCard({required this.request});

  final OperatorRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E9EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0E2238),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.route,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E2238),
                  ),
                ),
              ),
              _StatusPill(label: request.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${request.aircraftCategory} | ${request.etaResponse}',
            style: const TextStyle(
              color: Color(0xFF1E5D8C),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            request.notes,
            style: const TextStyle(color: Color(0xFF536274), height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _OperatorAircraftCard extends StatelessWidget {
  const _OperatorAircraftCard({required this.aircraft});

  final Aircraft aircraft;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF8FBFD)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E9EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  aircraft.name.isEmpty ? 'Aeronave sin nombre' : aircraft.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E2238),
                  ),
                ),
              ),
              const _StatusPill(label: 'Activa'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${aircraft.aircraftType} | ${aircraft.capacityPassengers} pasajeros | Base ${aircraft.homeBase}',
            style: const TextStyle(color: Color(0xFF536274)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SpecChip(
                label:
                    'Tarifa \$${aircraft.rentalPriceUsd.toStringAsFixed(0)}/hr',
              ),
              _SpecChip(
                label:
                    'Gasto nac. \$${aircraft.nationalExpensesUsd.toStringAsFixed(0)}',
              ),
              _SpecChip(
                label:
                    'Pernocta \$${aircraft.crewOvernightUsd.toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final color =
        normalized.contains('nueva')
            ? const Color(0xFF1B8F4D)
            : normalized.contains('activa')
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
