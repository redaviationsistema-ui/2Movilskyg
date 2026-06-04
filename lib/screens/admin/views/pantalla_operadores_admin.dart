import 'package:flutter/material.dart';

import '../../../models/modelos_mercado.dart';
import '../../shared/widgets/componentes_ui_rol.dart';

class AdminOperatorsScreen extends StatelessWidget {
  const AdminOperatorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureDetailScreen(
      title: 'Validacion de operadores',
      subtitle:
          'Vista para onboarding, documentos, cumplimiento, scoring inicial y aprobacion comercial.',
      metrics: [
        MarketplaceMetric(
          label: 'Pendientes',
          value: '14',
          helper: 'Operadores en espera de aprobacion.',
        ),
        MarketplaceMetric(
          label: 'Documentos',
          value: 'Checklist',
          helper: 'Revision de seguros, certificados y vigencias.',
        ),
        MarketplaceMetric(
          label: 'Estado',
          value: 'Aprobado / revision',
          helper: 'Semaforo administrativo y comercial.',
        ),
      ],
      sections: [
        MarketplaceModule(
          title: 'Expediente operador',
          description: 'Datos fiscales, licencias, seguros y contactos.',
        ),
        MarketplaceModule(
          title: 'Checklist documental',
          description: 'Documentos obligatorios y observaciones del revisor.',
        ),
        MarketplaceModule(
          title: 'Decision final',
          description:
              'Aprobacion, rechazo o solicitud de informacion adicional.',
        ),
      ],
    );
  }
}
