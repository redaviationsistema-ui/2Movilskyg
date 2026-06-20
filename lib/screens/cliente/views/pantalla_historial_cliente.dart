import 'package:flutter/material.dart';

import '../widgets/lista_vuelos_cliente.dart';

class ClientHistoryScreen extends StatelessWidget {
  const ClientHistoryScreen({
    super.key,
    this.showBackButton = true,
    this.onOpenSearch,
    this.onOpenContract,
    this.onOpenPayment,
    this.onCommercialAccessRequired,
  });

  final bool showBackButton;
  final VoidCallback? onOpenSearch;
  final ValueChanged<Map<String, dynamic>>? onOpenContract;
  final ValueChanged<Map<String, dynamic>>? onOpenPayment;
  final VoidCallback? onCommercialAccessRequired;

  @override
  Widget build(BuildContext context) {
    return ClientFlightsList(
      heading: 'Tus vuelos',
      description: 'Consulta tus reservas de forma simple.',
      showBackButton: showBackButton,
      onOpenSearch: onOpenSearch,
      onOpenContract: onOpenContract,
      onOpenPayment: onOpenPayment,
      onCommercialAccessRequired: onCommercialAccessRequired,
    );
  }
}
