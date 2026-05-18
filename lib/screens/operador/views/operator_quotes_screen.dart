import 'package:flutter/material.dart';

import '../../../models/marketplace_models.dart';
import '../../shared/widgets/role_ui_components.dart';

class OperatorQuotesScreen extends StatelessWidget {
  const OperatorQuotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureDetailScreen(
      title: 'Solicitudes y cotizaciones',
      subtitle:
          'Vista para recibir solicitudes, responder ofertas, ajustar condiciones y controlar tiempos de respuesta.',
      metrics: [
        MarketplaceMetric(
          label: 'Solicitudes',
          value: 'En vivo',
          helper: 'Solicitudes filtrables por ruta, fecha y categoria.',
        ),
        MarketplaceMetric(
          label: 'Ofertas',
          value: 'Comparables',
          helper: 'Precio, notas operativas, validez y restricciones.',
        ),
        MarketplaceMetric(
          label: 'SLA',
          value: 'Tiempo de respuesta',
          helper: 'Indicador clave para scoring del operador.',
        ),
      ],
      sections: [
        MarketplaceModule(
          title: 'Bandeja de solicitudes',
          description:
              'Solicitudes entrantes con prioridad y semaforo operativo.',
        ),
        MarketplaceModule(
          title: 'Constructor de oferta',
          description:
              'Tarifa, pernocta, reposicionamiento y notas especiales.',
        ),
        MarketplaceModule(
          title: 'Historial comercial',
          description: 'Aceptadas, rechazadas, vencidas y en negociacion.',
        ),
      ],
    );
  }
}
