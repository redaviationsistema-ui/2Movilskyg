import 'package:flutter/material.dart';

import '../../../models/marketplace_models.dart';
import '../../shared/widgets/role_ui_components.dart';

class AdminFinanceScreen extends StatelessWidget {
  const AdminFinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureDetailScreen(
      title: 'Comisiones y pagos',
      subtitle:
          'Vista para controlar fees, payout a operadores, reembolsos, creditos y conciliacion.',
      metrics: [
        MarketplaceMetric(
          label: 'Comision',
          value: '11%',
          helper: 'Promedio visible por booking y operador.',
        ),
        MarketplaceMetric(
          label: 'Payout',
          value: 'Programado',
          helper: 'Liquidacion por vuelos completados.',
        ),
        MarketplaceMetric(
          label: 'Refunds',
          value: 'Trazables',
          helper: 'Reembolsos y creditos con evidencia.',
        ),
      ],
      sections: [
        MarketplaceModule(
          title: 'Conciliacion',
          description: 'Cobros, anticipos, devoluciones y diferencias.',
        ),
        MarketplaceModule(
          title: 'Payout operador',
          description: 'Calendario de pagos y estatus de liberacion.',
        ),
        MarketplaceModule(
          title: 'Wallet y creditos',
          description: 'Saldos corporativos, bonos y creditos futuros.',
        ),
      ],
    );
  }
}
