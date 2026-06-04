import 'package:flutter/material.dart';

import '../widgets/lista_vuelos_cliente.dart';

class ClientHistoryScreen extends StatelessWidget {
  const ClientHistoryScreen({
    super.key,
    this.showBackButton = true,
    this.onOpenContract,
    this.onOpenPayment,
  });

  final bool showBackButton;
  final ValueChanged<Map<String, dynamic>>? onOpenContract;
  final ValueChanged<Map<String, dynamic>>? onOpenPayment;

  @override
  Widget build(BuildContext context) {
    return ClientFlightsList(
      heading: 'Tus vuelos',
      description: 'Consulta tus reservas de forma simple.',
      showBackButton: showBackButton,
      onOpenContract: onOpenContract,
      onOpenPayment: onOpenPayment,
      includeUpcomingTab: false,
    );
  }
}
