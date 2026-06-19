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
    final location =
        aircraft.homeBase.isEmpty ? aircraft.city : aircraft.homeBase;
    final capacityLabel = '${aircraft.capacityPassengers} pasajeros';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
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
            style: const TextStyle(
              color: kBlack,
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
          if (aircraft.imageUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _AircraftHeroImage(imageUrl: aircraft.imageUrl, title: title),
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: kBlack,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DESDE',
                  style: TextStyle(
                    color: Color(0xFFBBBBBB),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${formatMoney(baseFare)} USD',
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatMoney(aircraft.rentalPriceUsd)}/hr • Min. ${aircraft.minimumHours.toStringAsFixed(1)} hrs',
                  style: const TextStyle(
                    color: Color(0xFFD0D0D0),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCompleteData,
                  style: FilledButton.styleFrom(
                    backgroundColor: kBlack,
                    foregroundColor: kWhite,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.flight_takeoff_rounded, size: 18),
                  label: const Text(
                    'Reservar',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRequest,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kBlack,
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: kBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text(
                    'Cotizar',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                width: 52,
                child: OutlinedButton(
                  onPressed: onShare,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kBlack,
                    side: const BorderSide(color: kBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.ios_share_rounded, size: 19),
                ),
              ),
            ],
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
    final location =
        aircraft.homeBase.isEmpty ? aircraft.city : aircraft.homeBase;
    final description =
        '${aircraft.name.isEmpty ? 'Esta aeronave' : aircraft.name} es ideal para vuelos ejecutivos ${_routeScopeLabel(aircraft)} con capacidad para hasta ${aircraft.capacityPassengers} pasajeros.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Descripción',
            style: TextStyle(
              color: kBlack,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: kMuted,
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
              title: const Text(
                'Ver especificaciones',
                style: TextStyle(
                  color: kBlack,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_rounded,
                color: kBlack,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF7A7368)),
        const SizedBox(width: 4),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF7A7368),
            fontSize: 10.5,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3EE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFEAE4D9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF756D62)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF4C453C),
              fontSize: 12,
              fontWeight: FontWeight.w800,
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9E1D5)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF786C5B)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF7C7264),
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
                  style: const TextStyle(
                    color: kBlack,
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
