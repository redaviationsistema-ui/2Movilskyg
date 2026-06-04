import 'package:flutter/material.dart';

import '../../../models/modelos_mercado.dart';
import '../../shared/widgets/componentes_ui_rol.dart';

class AdminSupportScreen extends StatelessWidget {
  const AdminSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureDetailScreen(
      title: 'Disputas y soporte',
      subtitle:
          'Vista para incidencias, cancelaciones, cambios operativos, soporte al cliente y mediacion con operadores.',
      metrics: [
        MarketplaceMetric(
          label: 'Disputas',
          value: '3 activas',
          helper: 'Casos abiertos con seguimiento y evidencia.',
        ),
        MarketplaceMetric(
          label: 'Soporte',
          value: 'Multicanal',
          helper: 'Email, WhatsApp y concierge interno.',
        ),
        MarketplaceMetric(
          label: 'SLA',
          value: 'Atencion priorizada',
          helper: 'Tiempos de primera respuesta y resolucion.',
        ),
      ],
      sections: [
        MarketplaceModule(
          title: 'Mesa de ayuda',
          description: 'Tickets por prioridad, canal y responsable.',
        ),
        MarketplaceModule(
          title: 'Disputas',
          description: 'Historial, adjuntos, resolucion y seguimiento.',
        ),
        MarketplaceModule(
          title: 'Cancelaciones complejas',
          description:
              'Clima, restricciones ATC, mantenimiento y fuerza mayor.',
        ),
      ],
    );
  }
}
