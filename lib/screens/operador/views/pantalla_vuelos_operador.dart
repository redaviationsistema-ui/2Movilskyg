import 'package:flutter/material.dart';

import '../../../models/modelos_mercado.dart';
import '../../shared/widgets/componentes_ui_rol.dart';

class OperatorFlightsScreen extends StatelessWidget {
  const OperatorFlightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureDetailScreen(
      title: 'Vuelos confirmados',
      subtitle:
          'Vista para administrar operaciones, tripulacion, horario, restricciones y ejecucion del vuelo.',
      metrics: [
        MarketplaceMetric(
          label: 'Operacion',
          value: 'En curso',
          helper: 'Control desde confirmacion hasta cierre del servicio.',
        ),
        MarketplaceMetric(
          label: 'Tripulacion',
          value: 'Asignable',
          helper: 'Pilotos, pernocta y observaciones por vuelo.',
        ),
        MarketplaceMetric(
          label: 'Restricciones',
          value: 'Trazables',
          helper: 'Slots, permisos, clima y observaciones de aeropuerto.',
        ),
      ],
      sections: [
        MarketplaceModule(
          title: 'Agenda operativa',
          description: 'Calendario de salidas, arribos y tiempos de rotacion.',
        ),
        MarketplaceModule(
          title: 'Tripulacion',
          description: 'Asignacion, relevos, hotel y necesidades operativas.',
        ),
        MarketplaceModule(
          title: 'Incidencias',
          description: 'Bitacora de cambios, atrasos y cancelaciones.',
        ),
      ],
    );
  }
}
