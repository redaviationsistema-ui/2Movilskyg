import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/reservation_provider.dart';
import 'client_concierge_screen.dart';
import '../widgets/client_experience_widgets.dart';

class ClientTrackingScreen extends StatelessWidget {
  const ClientTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReservationProvider>();
    final syncLabel =
        provider.lastSyncAt == null
            ? 'Pendiente'
            : DateFormat('dd/MM HH:mm').format(provider.lastSyncAt!);

    return ClientExperienceShell(
      title: 'Seguimiento ejecutivo',
      subtitle: 'Seguimiento simple, visual y orientado a accion.',
      trailing: StatusBadge(
        label: provider.isOnline ? 'En linea' : 'Sin conexion',
        color:
            provider.isOnline
                ? const Color(0xFF1B8F4D)
                : const Color(0xFFB46A00),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          ClientHeroCard(
            badge: 'Estado del vuelo',
            title: 'El cliente debe sentir control en cada momento del vuelo',
            subtitle:
                'La experiencia tipo Uber aqui significa ver que sigue, quien lo esta resolviendo y cuando se actualizo por ultima vez.',
            metrics: [
              ClientHeroMetric(
                label: 'Reservas activas',
                value: provider.reservations.length.toString(),
              ),
              ClientHeroMetric(
                label: 'Ultima sincronizacion',
                value: syncLabel,
              ),
              const ClientHeroMetric(
                label: 'Soporte',
                value: 'Asistente + operaciones',
              ),
            ],
            primaryLabel: 'Abrir concierge',
            primaryAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClientConciergeScreen(),
                ),
              );
            },
            secondaryLabel: 'Actualizar vista',
            secondaryAction: () {},
          ),
          const SizedBox(height: 24),
          const ClientSectionTitle(
            title: 'Estado del servicio',
            subtitle:
                'Timeline pensado para clientes premium, no para backoffice.',
          ),
          const SizedBox(height: 14),
          const GlassInfoCard(
            child: BookingTimeline(
              steps: [
                TimelineStep(
                  title: 'Solicitud recibida',
                  caption:
                      'La ruta entro a revision con preferencia ejecutiva.',
                  isActive: true,
                ),
                TimelineStep(
                  title: 'Aeronave asignada',
                  caption:
                      'Se encontro la mejor combinacion entre imagen, tiempo y costo.',
                  isActive: true,
                ),
                TimelineStep(
                  title: 'Tripulacion confirmada',
                  caption: 'Operaciones valida slots, permisos y brief final.',
                  isActive: true,
                ),
                TimelineStep(
                  title: 'Pickup y embarque',
                  caption:
                      'Se comparte acceso, hora sugerida y soporte en tierra.',
                  isActive: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const ClientSectionTitle(
            title: 'Momentos clave',
            subtitle:
                'Tarjetas utiles para que el cliente sepa que puede hacer ahora.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final items = [
                GlassInfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      StatusBadge(label: 'T-90 min', color: Color(0xFF143955)),
                      SizedBox(height: 12),
                      Text(
                        'Acceso FBO',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10253A),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Envio de instrucciones, punto de llegada y contacto de apoyo.',
                        style: TextStyle(
                          color: Color(0xFF607080),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                GlassInfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      StatusBadge(label: 'VIP', color: Color(0xFFB46A00)),
                      SizedBox(height: 12),
                      Text(
                        'Cabina y catering',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10253A),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Preferencias visibles para que el cliente no tenga que repetirlas.',
                        style: TextStyle(
                          color: Color(0xFF607080),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ];

              if (constraints.maxWidth < 720) {
                return Column(
                  children:
                      items
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: item,
                            ),
                          )
                          .toList(),
                );
              }

              return Row(
                children:
                    items
                        .map(
                          (item) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: item,
                            ),
                          ),
                        )
                        .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
