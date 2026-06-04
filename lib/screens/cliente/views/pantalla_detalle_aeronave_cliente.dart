import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/aeronave.dart';
import '../../../models/modelos_flujo_trabajo.dart';
import '../../../providers/proveedor_flujo_trabajo.dart';
import '../../reservation/pantalla_reservacion.dart';
import '../../shared/widgets/hoja_crud_flujo_trabajo.dart';
import '../widgets/widgets_experiencia_cliente.dart';

const Color kBg = Color(0xFFF7F7F7);
const Color kWhite = Colors.white;
const Color kBlack = Color(0xFF050505);
const Color kText = Color(0xFF111111);
const Color kMuted = Color(0xFF666666);
const Color kBorder = Color(0xFFE6E6E6);
const Color kSoft = Color(0xFFF2F2F2);

class ClientAircraftDetailScreen extends StatelessWidget {
  const ClientAircraftDetailScreen({super.key, required this.aircraft});

  final Aircraft aircraft;

  String get _category {
    final type = aircraft.aircraftType.toLowerCase();

    if (type.contains('heavy')) return 'Jet pesado';
    if (type.contains('super')) return 'Super mediano';
    if (type.contains('mid')) return 'Jet mediano';
    if (type.contains('turbo')) return 'Turbohélice';
    if (type.contains('helic')) return 'Helicóptero';

    return 'Jet ligero';
  }

  void _openQuoteSheet(BuildContext context) {
    const flowId = 'Cliente::Detalle aeronave';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aircraft.name.isEmpty
                      ? 'Solicitar aeronave'
                      : 'Solicitar ${aircraft.name}',
                  style: const TextStyle(
                    color: kBlack,
                    fontSize: 26,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Completa ruta, pasajeros, horario y preferencias para continuar con la solicitud.',
                  style: TextStyle(
                    color: kMuted,
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);

                          final record = StaticRecord(
                            title: 'Solicitud ${aircraft.name}',
                            subtitle:
                                'Solicitud guardada para ruta, pasajeros, horario y preferencias.',
                            status: 'Enviada',
                            amount:
                                '\$${(aircraft.rentalPriceUsd * aircraft.minimumHours).toStringAsFixed(0)} USD',
                          );

                          context.read<WorkflowProvider>().watch(
                            flowId: flowId,
                            initialRecords: const [],
                          );

                          context.read<WorkflowProvider>().createRecord(
                            flowId,
                            record,
                          );

                          _openAircraftRecord(context, flowId, record);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: kBlack,
                          foregroundColor: kWhite,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text(
                          'Enviar',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReservationScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kBlack,
                          minimumSize: const Size.fromHeight(52),
                          side: const BorderSide(color: kBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                        label: const Text(
                          'Completar',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseFare = aircraft.rentalPriceUsd * aircraft.minimumHours;
    const flowId = 'Cliente::Detalle aeronave';

    context.watch<WorkflowProvider>().watch(
      flowId: flowId,
      initialRecords: const [],
    );

    return ClientExperienceShell(
      title: aircraft.name.isEmpty ? 'Aeronave' : aircraft.name,
      subtitle: 'Detalle ejecutivo.',
      child: Container(
        color: kBg,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _AircraftHeaderCard(
              aircraft: aircraft,
              category: _category,
              baseFare: baseFare,
              onRequest: () => _openQuoteSheet(context),
              onCompleteData: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReservationScreen()),
                );
              },
              onShare: () {
                final record = StaticRecord(
                  title: 'Link ${aircraft.name}',
                  subtitle:
                      'Enlace interno generado para compartir esta aeronave.',
                  status: 'Activo',
                  amount: 'Compartir',
                );

                context.read<WorkflowProvider>().createRecord(flowId, record);
                _openAircraftRecord(context, flowId, record);
              },
            ),

            const SizedBox(height: 16),

            _AircraftSpecsCard(aircraft: aircraft, baseFare: baseFare),

            const SizedBox(height: 16),

            _MinimalServiceCard(
              title: 'Servicio',
              items: const [
                'Brief previo al vuelo',
                'Coordinación FBO',
                'Soporte concierge',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AircraftHeaderCard extends StatelessWidget {
  const _AircraftHeaderCard({
    required this.aircraft,
    required this.category,
    required this.baseFare,
    required this.onRequest,
    required this.onCompleteData,
    required this.onShare,
  });

  final Aircraft aircraft;
  final String category;
  final double baseFare;
  final VoidCallback onRequest;
  final VoidCallback onCompleteData;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final title = aircraft.name.isEmpty ? 'Aeronave ejecutiva' : aircraft.name;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SmallBadge(label: category),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: kBlack,
              fontSize: 34,
              height: 0.98,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${aircraft.capacityPassengers} pasajeros · Base ${aircraft.city}',
            style: const TextStyle(
              color: kMuted,
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'Tarifa',
                  value: '${formatMoney(aircraft.rentalPriceUsd)}/hr',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  label: 'Desde',
                  value: formatMoney(baseFare),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onRequest,
                  style: FilledButton.styleFrom(
                    backgroundColor: kBlack,
                    foregroundColor: kWhite,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Solicitar',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCompleteData,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kBlack,
                    minimumSize: const Size.fromHeight(54),
                    side: const BorderSide(color: kBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Reservar',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onShare,
              style: TextButton.styleFrom(
                foregroundColor: kBlack,
                minimumSize: const Size.fromHeight(46),
              ),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text(
                'Compartir opción',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          _SpecRow(
            label: 'Capacidad',
            value: '${aircraft.capacityPassengers} pasajeros',
          ),
          _SpecRow(
            label: 'Velocidad',
            value: '${aircraft.cruiseSpeedKnots.toStringAsFixed(0)} kts',
          ),
          _SpecRow(
            label: 'Mínimo',
            value: '${aircraft.minimumHours.toStringAsFixed(1)} hrs',
          ),
          _SpecRow(
            label: 'Base',
            value:
                aircraft.homeBase.isEmpty ? aircraft.city : aircraft.homeBase,
          ),
          _SpecRow(label: 'Costo desde', value: formatMoney(baseFare)),
          _SpecRow(
            label: 'Overnight',
            value: formatMoney(aircraft.crewOvernightUsd),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _MinimalServiceCard extends StatelessWidget {
  const _MinimalServiceCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBlack,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFBDBDBD),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  const Icon(Icons.check_rounded, color: kWhite, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: kWhite,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBorder),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: kBlack,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: kMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kBlack,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              child: Text(
                label,
                style: const TextStyle(
                  color: kMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: kBlack,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
        if (showDivider) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: kBorder),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

Future<void> _openAircraftRecord(
  BuildContext context,
  String flowId,
  StaticRecord record,
) {
  final provider = context.read<WorkflowProvider>();

  return showWorkflowRecordDetail(
    context,
    record: record,
    onAdvance: () => provider.advanceRecord(flowId, record),
    onActivate:
        () => provider.updateRecord(
          flowId,
          record,
          record.copyWith(status: 'Confirmado'),
        ),
    onBlock:
        () => provider.updateRecord(
          flowId,
          record,
          record.copyWith(status: 'Bloqueado'),
        ),
    onDelete: () => provider.deleteRecord(flowId, record),
    onEdit: () async {
      final updated = await showWorkflowRecordForm(
        context,
        title: 'Editar solicitud',
        initial: record,
      );

      if (updated != null && context.mounted) {
        provider.updateRecord(flowId, record, updated);
      }
    },
  );
}
