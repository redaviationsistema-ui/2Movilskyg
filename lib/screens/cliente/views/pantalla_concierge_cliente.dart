import 'package:flutter/material.dart';

import '../../../core/cliente_api.dart';
import '../widgets/widgets_experiencia_cliente.dart';

class ClientConciergeScreen extends StatefulWidget {
  const ClientConciergeScreen({super.key, this.request});

  final Map<String, dynamic>? request;

  @override
  State<ClientConciergeScreen> createState() => _ClientConciergeScreenState();
}

class _ClientConciergeScreenState extends State<ClientConciergeScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ConciergeMessage> _messages = [
    const ConciergeMessage(
      sender: 'Asistente Sky',
      text:
          'Tenemos un canal listo para coordinar ruta, FBO, catering, documentos y cambios de horario.',
      time: 'Ahora',
      fromTeam: true,
    ),
  ];
  bool _sending = false;
  String _inlineMessage = '';

  @override
  void initState() {
    super.initState();
    final route = _routeLabel(widget.request ?? const {});
    if (route.isNotEmpty) {
      _messages.add(
        ConciergeMessage(
          sender: 'Ops Desk',
          text: 'Contexto vinculado a la reserva $route.',
          time: 'Ahora',
          fromTeam: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

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
                'Envia requerimientos reales al equipo: cambios de horario, catering, traslado, FBO, mascotas o documentos.',
            metrics: const [
              ClientHeroMetric(label: 'Respuesta', value: '< 5 min'),
              ClientHeroMetric(label: 'Canales', value: 'App + Ops'),
              ClientHeroMetric(label: 'Cobertura', value: '24/7'),
            ],
            primaryLabel: _sending ? 'Enviando...' : 'Enviar solicitud',
            primaryAction: _sending ? () {} : _sendMessage,
            secondaryLabel: 'Limpiar',
            secondaryAction:
                _sending ? () {} : () => _messageController.clear(),
          ),
          const SizedBox(height: 18),
          GlassInfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nueva solicitud',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText:
                        'Ej. Necesito catering premium, pickup terrestre y confirmacion de acceso FBO.',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                if (_inlineMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _inlineMessage,
                    style: const TextStyle(
                      color: Color(0xFF625D55),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const ClientSectionTitle(
            title: 'Conversacion activa',
            subtitle:
                'Mensajes cortos, enfocados en resolver y avanzar la reserva.',
          ),
          const SizedBox(height: 14),
          GlassInfoCard(child: ConciergeConversation(messages: _messages)),
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
                  onTap:
                      () => _quickMessage(
                        'Necesito coordinar traslado terrestre y acceso FBO.',
                      ),
                  tint: const Color(0xFF215B83),
                ),
                ActionShortcutCard(
                  icon: Icons.restaurant_menu_rounded,
                  title: 'Catering y amenidades',
                  subtitle:
                      'Solicitudes VIP, WiFi, mascotas y preferencias de cabina.',
                  onTap:
                      () => _quickMessage(
                        'Quiero revisar catering, amenidades y preferencias de cabina.',
                      ),
                  tint: const Color(0xFFB46A00),
                ),
                ActionShortcutCard(
                  icon: Icons.verified_user_rounded,
                  title: 'Compliance express',
                  subtitle:
                      'Documentos, validacion y autorizaciones sin friccion.',
                  onTap:
                      () => _quickMessage(
                        'Necesito apoyo con documentos, validacion o autorizaciones.',
                      ),
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

  void _quickMessage(String value) {
    _messageController.text = value;
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      setState(() => _inlineMessage = 'Escribe una solicitud para concierge.');
      return;
    }

    final request = widget.request ?? const <String, dynamic>{};
    final reservationId =
        request['reservation_id']?.toString() ?? request['id']?.toString();
    final flightRequestId =
        request['flight_request_id']?.toString() ?? request['id']?.toString();

    setState(() {
      _sending = true;
      _inlineMessage = 'Enviando solicitud a concierge...';
      _messages.add(
        ConciergeMessage(
          sender: 'Cliente',
          text: message,
          time: _timeLabel(),
          fromTeam: false,
        ),
      );
    });

    try {
      await ApiClient.instance.requestConcierge(
        message: message,
        reservationId: reservationId,
        flightRequestId: flightRequestId,
      );
      if (!mounted) return;
      setState(() {
        _messageController.clear();
        _inlineMessage = 'Solicitud enviada. Concierge dara seguimiento.';
        _messages.add(
          ConciergeMessage(
            sender: 'Ops Desk',
            text: 'Recibido. Ya quedo vinculado al flujo operativo.',
            time: _timeLabel(),
            fromTeam: true,
          ),
        );
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineMessage = 'No fue posible enviar la solicitud: $error';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _routeLabel(Map<String, dynamic> request) {
    final origin = request['origin']?.toString() ?? '';
    final destination = request['destination']?.toString() ?? '';
    if (origin.isEmpty && destination.isEmpty) return '';
    return '$origin - $destination';
  }

  String _timeLabel() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
