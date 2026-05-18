import 'package:flutter/material.dart';

import '../../../models/marketplace_models.dart';

class AdminRoadmapList extends StatelessWidget {
  const AdminRoadmapList({super.key, required this.items});

  final List<RoadmapPhase> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) => _RoadmapCard(phase: item)).toList(),
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({required this.phase});

  final RoadmapPhase phase;

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
          Text(
            phase.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0E2238),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            phase.description,
            style: const TextStyle(color: Color(0xFF536274), height: 1.35),
          ),
        ],
      ),
    );
  }
}
