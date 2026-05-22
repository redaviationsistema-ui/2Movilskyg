import 'package:flutter/material.dart';

import '../widgets/client_experience_widgets.dart';

class ClientBookingConfirmationScreen extends StatelessWidget {
  const ClientBookingConfirmationScreen({
    super.key,
    required this.request,
    required this.onOpenTrips,
    this.showBackButton = true,
  });

  final Map<String, dynamic> request;
  final VoidCallback onOpenTrips;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return ClientExperienceShell(
      title: 'Confirmacion',
      subtitle: 'Tu solicitud ya entro al flujo comercial y operativo.',
      showBackButton: showBackButton,
      trailing: const StatusBadge(
        label: 'Reserva registrada',
        color: Color(0xFF2D6A4F),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2D6A4F),
                  size: 84,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Tu solicitud fue enviada al proveedor',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _routeLabel(request),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF625D55),
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Ya puedes dar seguimiento desde Mis vuelos. Cuando el proveedor acepte la operacion veras el avance a contrato, pago y confirmacion final del vuelo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF3B3428), height: 1.4),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: onOpenTrips,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: const Color(0xFF10253A),
                  ),
                  child: const Text('Ver mis vuelos'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _routeLabel(Map<String, dynamic> request) {
    final origin =
        request['origin']?.toString() ??
        request['base_airport']?.toString() ??
        'Origen';
    final destination = request['destination']?.toString() ?? 'Destino';
    return '$origin -> $destination';
  }
}
