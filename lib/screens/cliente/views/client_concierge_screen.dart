import 'package:flutter/material.dart';

import '../widgets/client_experience_widgets.dart';

class ClientConciergeScreen extends StatelessWidget {
  const ClientConciergeScreen({super.key});

  static const List<ConciergeMessage> _messages = [
    ConciergeMessage(
      sender: 'Asistente Sky',
      text:
          'Tenemos una opcion lista saliendo de Toluca con margen para pickup terrestre.',
      time: '09:12',
      fromTeam: true,
    ),
    ConciergeMessage(
      sender: 'Cliente',
      text: 'Necesito WiFi, catering ligero y salida antes de las 13:00.',
      time: '09:14',
      fromTeam: false,
    ),
    ConciergeMessage(
      sender: 'Ops Desk',
      text:
          'Confirmado. Ya estamos validando slots y acceso preferente en FBO.',
      time: '09:17',
      fromTeam: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ClientExperienceShell(
      title: 'Asistente ejecutivo',
      subtitle:
          'Soporte humano y operativo con tono premium, claro y accionable.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          ClientHeroCard(
            badge: 'Always on',
            title: 'Un canal que acompana desde la solicitud hasta el embarque',
            subtitle:
                'La experiencia tipo Uber aqui no es informal: es rapidez, seguimiento y decisiones claras con respaldo operativo.',
            metrics: const [
              ClientHeroMetric(label: 'Respuesta', value: '< 5 min'),
              ClientHeroMetric(label: 'Canales', value: 'App + WhatsApp'),
              ClientHeroMetric(label: 'Cobertura', value: '24/7'),
            ],
            primaryLabel: 'Abrir chat seguro',
            primaryAction: () {},
            secondaryLabel: 'Llamar ahora',
            secondaryAction: () {},
          ),
          const SizedBox(height: 24),
          const ClientSectionTitle(
            title: 'Conversacion activa',
            subtitle:
                'Mensajes cortos, enfocados en resolver y avanzar la reserva.',
          ),
          const SizedBox(height: 14),
          const GlassInfoCard(
            child: ConciergeConversation(messages: _messages),
          ),
          const SizedBox(height: 24),
          const ClientSectionTitle(
            title: 'Ayuda que mueve la operacion',
            subtitle:
                'Vistas complementarias para que el soporte no se quede en puro texto.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 700;
              final cards = [
                ActionShortcutCard(
                  icon: Icons.local_taxi_rounded,
                  title: 'Traslado terrestre',
                  subtitle: 'Coordinacion de pickup ejecutivo y acceso FBO.',
                  onTap: () {},
                  tint: const Color(0xFF215B83),
                ),
                ActionShortcutCard(
                  icon: Icons.restaurant_menu_rounded,
                  title: 'Catering y amenidades',
                  subtitle:
                      'Solicitudes VIP, WiFi, mascotas y preferencias de cabina.',
                  onTap: () {},
                  tint: const Color(0xFFB46A00),
                ),
                ActionShortcutCard(
                  icon: Icons.verified_user_rounded,
                  title: 'Compliance express',
                  subtitle:
                      'Documentos, validacion y autorizaciones sin friccion.',
                  onTap: () {},
                  tint: const Color(0xFF1B8F4D),
                ),
              ];

              if (!wide) {
                return Column(
                  children:
                      cards
                          .map(
                            (card) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: card,
                            ),
                          )
                          .toList(),
                );
              }

              return Row(
                children:
                    cards
                        .map(
                          (card) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: card,
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
