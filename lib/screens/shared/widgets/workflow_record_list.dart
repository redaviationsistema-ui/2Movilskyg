import 'package:flutter/material.dart';

import '../../../models/workflow_models.dart';

class WorkflowRecordList extends StatelessWidget {
  const WorkflowRecordList({
    super.key,
    required this.records,
    required this.onRecordTap,
  });

  final List<StaticRecord> records;
  final ValueChanged<StaticRecord> onRecordTap;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE4EAF0)),
        ),
        child: const Text(
          'No hay registros con este filtro. Toca Filtrar para volver a la vista completa.',
          style: TextStyle(color: Color(0xFF607080), height: 1.35),
        ),
      );
    }

    return Column(
      children:
          records.map((record) {
            return InkWell(
              onTap: () => onRecordTap(record),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE4EAF0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F0E2238),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2BD79).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.flight_takeoff_rounded,
                        color: Color(0xFF10253A),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.title,
                            style: const TextStyle(
                              color: Color(0xFF10253A),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            record.subtitle,
                            style: const TextStyle(
                              color: Color(0xFF607080),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Toca para avanzar estatus',
                            style: TextStyle(
                              color: Color(0xFF8A96A3),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _WorkflowStatusPill(label: record.status),
                        const SizedBox(height: 8),
                        Text(
                          record.amount,
                          style: const TextStyle(
                            color: Color(0xFF10253A),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }
}

class WorkflowAuditCard extends StatelessWidget {
  const WorkflowAuditCard({
    super.key,
    required this.operationCount,
    required this.lastAudit,
  });

  final int operationCount;
  final String lastAudit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10253A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x33E2BD79)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_done_rounded, color: Color(0xFFE2BD79)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Operaciones: $operationCount | $lastAudit',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowStatusPill extends StatelessWidget {
  const _WorkflowStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final color =
        normalized.contains('activo') ||
                normalized.contains('confirmado') ||
                normalized.contains('aprobado') ||
                normalized.contains('finalizado')
            ? const Color(0xFF1B8F4D)
            : normalized.contains('pendiente') ||
                normalized.contains('revision') ||
                normalized.contains('critica')
            ? const Color(0xFFB46A00)
            : const Color(0xFF345C84);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
