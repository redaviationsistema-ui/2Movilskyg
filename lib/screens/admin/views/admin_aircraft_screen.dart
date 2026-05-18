import 'package:flutter/material.dart';

import '../../../models/marketplace_models.dart';
import '../../shared/widgets/role_ui_components.dart';

class AdminAircraftScreen extends StatelessWidget {
  const AdminAircraftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureDetailScreen(
      title: 'Aprobacion de aeronaves',
      subtitle:
          'Vista para revisar matrículas, documentos, categoría, condiciones comerciales y liberación operativa.',
      metrics: [
        MarketplaceMetric(
          label: 'Aeronaves',
          value: 'En revision',
          helper: 'Unidades esperando aprobacion administrativa.',
        ),
        MarketplaceMetric(
          label: 'Categorias',
          value: 'Ligero a pesado',
          helper: 'Clasificacion visible para el marketplace.',
        ),
        MarketplaceMetric(
          label: 'Estado',
          value: 'Activa / inactiva',
          helper: 'Control de disponibilidad comercial.',
        ),
      ],
      sections: [
        MarketplaceModule(
          title: 'Ficha de aeronave',
          description: 'Modelo, pasajeros, alcance, base y datos tecnicos.',
        ),
        MarketplaceModule(
          title: 'Revision documental',
          description: 'Permisos, seguros, certificados y fechas de vigencia.',
        ),
        MarketplaceModule(
          title: 'Liberacion comercial',
          description:
              'Habilitacion para aparecer en resultados y solicitudes.',
        ),
      ],
    );
  }
}
