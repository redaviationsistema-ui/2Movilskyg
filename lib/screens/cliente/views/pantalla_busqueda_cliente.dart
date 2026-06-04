import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/proveedor_reservaciones.dart';
import '../../reservation/pantalla_reservacion.dart';
import 'pantalla_concierge_cliente.dart';
import '../widgets/widgets_experiencia_cliente.dart';

class ClientSearchScreen extends StatelessWidget {
  const ClientSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReservationProvider>();
    final suggestedPax = provider.passengers > 0 ? provider.passengers : 6;
    final fleetCount = provider.aircraftFleet.length;

    return ClientExperienceShell(
      title: 'Reserva inmediata',
      subtitle:
          'Una vista viva para arrancar la solicitud como si fuera movilidad premium.',
      trailing: const StatusBadge(
        label: 'Modo charter',
        color: Color(0xFF143955),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          ClientHeroCard(
            badge: 'Reserva',
            title: 'Pide una aeronave ejecutiva en pocos pasos',
            subtitle:
                'Tomamos la claridad de la landing reserva y la convertimos en una experiencia de app: ruta, categoria, velocidad de respuesta y concierge.',
            metrics: [
              ClientHeroMetric(
                label: 'Flota visible',
                value: '$fleetCount opciones',
              ),
              ClientHeroMetric(
                label: 'Pasajeros',
                value: '$suggestedPax sugeridos',
              ),
              const ClientHeroMetric(
                label: 'Cobertura',
                value: 'MX + internacional',
              ),
            ],
            primaryLabel: 'Abrir cotizador',
            primaryAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReservationScreen()),
              );
            },
            secondaryLabel: 'Hablar con concierge',
            secondaryAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClientConciergeScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const ClientSectionTitle(
            title: 'Accesos rapidos',
            subtitle:
                'En lugar de texto fijo, esta vista abre intenciones concretas de compra.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final items = [
                ActionShortcutCard(
                  icon: Icons.flash_on_rounded,
                  title: 'Salida hoy',
                  subtitle:
                      'Prioriza aeronaves con respuesta rapida y minima reposicion.',
                  onTap: () {},
                ),
                ActionShortcutCard(
                  icon: Icons.swap_calls_rounded,
                  title: 'Round trip',
                  subtitle:
                      'Ideal para agendas ejecutivas con regreso en el mismo dia.',
                  onTap: () {},
                  tint: const Color(0xFF1B8F4D),
                ),
                ActionShortcutCard(
                  icon: Icons.travel_explore_rounded,
                  title: 'Ruta especial',
                  subtitle:
                      'Internacional, multicity o necesidad VIP bajo revision operativa.',
                  onTap: () {},
                  tint: const Color(0xFFB46A00),
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
          const SizedBox(height: 24),
          const ClientSectionTitle(
            title: 'Que captura esta vista',
            subtitle: 'Campos y decisiones pensadas para convertir mas rapido.',
          ),
          const SizedBox(height: 14),
          GlassInfoCard(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _SearchChip(label: 'Origen y destino ejecutivos'),
                _SearchChip(label: 'Hora de salida'),
                _SearchChip(label: 'Categoria de aeronave'),
                _SearchChip(label: 'Pasajeros y equipaje'),
                _SearchChip(label: 'WiFi y catering'),
                _SearchChip(label: 'Mascotas o seguridad'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const ClientSectionTitle(
            title: 'Ritmo de reserva',
            subtitle:
                'La app debe responder con pasos claros, no con parrafos largos.',
          ),
          const SizedBox(height: 14),
          const GlassInfoCard(
            child: BookingTimeline(
              steps: [
                TimelineStep(
                  title: '1. Seleccionas la ruta',
                  caption:
                      'El usuario parte desde una intencion clara y concreta.',
                  isActive: true,
                ),
                TimelineStep(
                  title: '2. La app propone categoria',
                  caption: 'Se filtra por rango, urgencia y capacidad real.',
                  isActive: true,
                ),
                TimelineStep(
                  title: '3. El equipo confirma operacion',
                  caption:
                      'Si hace falta, concierge toma el caso y acelera el cierre.',
                  isActive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchChip extends StatelessWidget {
  const _SearchChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF10253A),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
