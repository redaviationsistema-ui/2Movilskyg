import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/aircraft.dart';
import '../../../models/workflow_models.dart';
import '../../../providers/workflow_provider.dart';
import '../../reservation/reservation_screen.dart';
import '../../shared/widgets/workflow_crud_sheet.dart';
import '../widgets/client_experience_widgets.dart';

class ClientAircraftDetailScreen extends StatelessWidget {
  const ClientAircraftDetailScreen({super.key, required this.aircraft});

  final Aircraft aircraft;

  String get _category {
    final type = aircraft.aircraftType.toLowerCase();
    if (type.contains('heavy')) return 'Jet pesado';
    if (type.contains('super')) return 'Super mediano';
    if (type.contains('mid')) return 'Jet mediano';
    if (type.contains('turbo')) return 'Turbohelice';
    if (type.contains('helic')) return 'Helicoptero';
    return 'Jet ligero';
  }

  List<TimelineStep> get _serviceMoments => const [
    TimelineStep(
      title: 'Brief previo al vuelo',
      caption: 'Ruta, slots, tripulacion y permisos validados por operaciones.',
      isActive: true,
    ),
    TimelineStep(
      title: 'Pickup ejecutivo',
      caption: 'Coordinacion de traslado terrestre y acceso FBO.',
      isActive: true,
    ),
    TimelineStep(
      title: 'Cabina personalizada',
      caption: 'Catering, privacidad, mascotas y WiFi sujetos a solicitud.',
      isActive: true,
    ),
  ];

  void _openQuoteSheet(BuildContext context) {
    const flowId = 'Cliente::Detalle aeronave';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => Padding(
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
                    color: Color(0xFF10253A),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'La solicitud quedaria lista para enviar al proveedor con ruta, pasajeros, horario y preferencias VIP.',
                  style: TextStyle(color: Color(0xFF607080), height: 1.35),
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
                                'Solicitud guardada y asignada al proveedor para ruta, pasajeros, horario y preferencias VIP.',
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
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Enviar solicitud'),
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
                        icon: const Icon(Icons.edit_calendar_rounded),
                        label: const Text('Completar datos'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
      title: aircraft.name.isEmpty ? 'Aeronave ejecutiva' : aircraft.name,
      subtitle: 'Detalle premium para una decision rapida y bien informada.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          ClientHeroCard(
            badge: _category,
            title:
                '${aircraft.capacityPassengers} pasajeros con salida desde ${aircraft.city}',
            subtitle:
                'Inspirada en la experiencia fleet: capacidades claras, base operativa y propuesta ejecutiva en una sola vista.',
            metrics: [
              ClientHeroMetric(
                label: 'Tarifa',
                value: '${formatMoney(aircraft.rentalPriceUsd)}/hr',
              ),
              ClientHeroMetric(
                label: 'Velocidad',
                value: '${aircraft.cruiseSpeedKnots.toStringAsFixed(0)} kts',
              ),
              ClientHeroMetric(
                label: 'Minimo',
                value: '${aircraft.minimumHours.toStringAsFixed(1)} hrs',
              ),
            ],
            primaryLabel: 'Solicitar esta aeronave',
            primaryAction: () => _openQuoteSheet(context),
            secondaryLabel: 'Compartir opcion',
            secondaryAction: () {
              final record = StaticRecord(
                title: 'Link ${aircraft.name}',
                subtitle:
                    'Enlace interno generado para compartir esta aeronave con un cliente o ejecutivo comercial.',
                status: 'Activo',
                amount: 'Compartir',
              );
              context.read<WorkflowProvider>().createRecord(flowId, record);
              _openAircraftRecord(context, flowId, record);
            },
          ),
          const SizedBox(height: 24),
          const ClientSectionTitle(
            title: 'Snapshot operativo',
            subtitle: 'Lo esencial para evaluar rapidez, confort y viabilidad.',
          ),
          const SizedBox(height: 14),
          GlassInfoCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PricePill(
                        label: 'Salida estimada',
                        value: '45-90 min',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PricePill(label: 'Base', value: aircraft.homeBase),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: PricePill(
                        label: 'Costo desde',
                        value: formatMoney(baseFare),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PricePill(
                        label: 'Overnight crew',
                        value: formatMoney(aircraft.crewOvernightUsd),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const ClientSectionTitle(
            title: 'Experiencia a bordo',
            subtitle:
                'Una mezcla de practicidad tipo on-demand y trato corporativo.',
          ),
          const SizedBox(height: 14),
          GlassInfoCard(child: BookingTimeline(steps: _serviceMoments)),
          const SizedBox(height: 24),
          const ClientSectionTitle(
            title: 'Por que encaja',
            subtitle:
                'Argumentos cortos, utiles y nada estaticos para apoyar la seleccion.',
          ),
          const SizedBox(height: 14),
          GlassInfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _ReasonRow(
                  icon: Icons.bolt_rounded,
                  title: 'Respuesta veloz',
                  subtitle:
                      'Pensada para cotizaciones rapidas, traslados ejecutivos y agendas apretadas.',
                ),
                SizedBox(height: 14),
                _ReasonRow(
                  icon: Icons.luggage_rounded,
                  title: 'Capacidad equilibrada',
                  subtitle:
                      'Combina espacio, velocidad y costo para equipos pequenos y directivos.',
                ),
                SizedBox(height: 14),
                _ReasonRow(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Imagen premium',
                  subtitle:
                      'Presentacion sobria y profesional alineada con la landing fleet.',
                ),
              ],
            ),
          ),
        ],
      ),
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

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF143955).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF143955)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF10253A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF607080), height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
