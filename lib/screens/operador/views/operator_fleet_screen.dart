import 'package:flutter/material.dart';

import '../../../models/marketplace_models.dart';
import '../../shared/widgets/role_ui_components.dart';

class OperatorFleetScreen extends StatelessWidget {
  const OperatorFleetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureDetailScreen(
      title: 'Gestion de flota',
      subtitle:
          'Vista para alta, edicion y control de aeronaves, documentos, fotos, amenidades y base operativa.',
      metrics: [
        MarketplaceMetric(
          label: 'Catalogo',
          value: 'Multi-aeronave',
          helper: 'Preparada para una o varias bases operativas.',
        ),
        MarketplaceMetric(
          label: 'Estado',
          value: 'Activa / mantenimiento',
          helper: 'Control visible por aeronave.',
        ),
        MarketplaceMetric(
          label: 'Documentacion',
          value: 'Centralizada',
          helper: 'Certificados, permisos y seguros por unidad.',
        ),
      ],
      sections: [
        MarketplaceModule(
          title: 'Alta de aeronave',
          description:
              'Matricula, fabricante, modelo, pasajeros, alcance y categoria.',
        ),
        MarketplaceModule(
          title: 'Media y amenities',
          description: 'Fotos, cabina, WiFi, catering, pet friendly y extras.',
        ),
        MarketplaceModule(
          title: 'Compliance',
          description: 'Documentos, vencimientos y alertas de renovacion.',
        ),
      ],
    );
  }
}
