import 'package:flutter/material.dart';

import '../../../models/marketplace_models.dart';
import '../../shared/widgets/role_ui_components.dart';

class OperatorPerformanceScreen extends StatelessWidget {
  const OperatorPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureDetailScreen(
      title: 'Desempeno del operador',
      subtitle:
          'Vista para KPIs de aceptacion, ingresos, tiempos de respuesta, cancelaciones y scoring.',
      metrics: [
        MarketplaceMetric(
          label: 'Aceptacion',
          value: '82%',
          helper: 'Relacion entre solicitudes recibidas y vuelos tomados.',
        ),
        MarketplaceMetric(
          label: 'Cancelaciones',
          value: '1.8%',
          helper: 'Control para calidad operativa y reputacion.',
        ),
        MarketplaceMetric(
          label: 'Ingresos',
          value: 'Mensual / anual',
          helper: 'Seguimiento comercial y payout estimado.',
        ),
      ],
      sections: [
        MarketplaceModule(
          title: 'KPIs comerciales',
          description: 'Tasa de conversion, tickets y revenue generado.',
        ),
        MarketplaceModule(
          title: 'KPIs operativos',
          description: 'Atrasos, cumplimiento y tiempos de reaccion.',
        ),
        MarketplaceModule(
          title: 'Scoring y reviews',
          description: 'Calificacion del operador frente a clientes y admin.',
        ),
      ],
    );
  }
}
