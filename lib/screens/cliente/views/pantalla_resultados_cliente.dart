import 'package:flutter/material.dart';

import '../widgets/lista_vuelos_cliente.dart';

class ClientResultsScreen extends StatelessWidget {
  const ClientResultsScreen({
    super.key,
    this.showBackButton = true,
    this.onOpenContract,
    this.onOpenPayment,
    this.userInitial = 'C',
    this.onBackToSearch,
    this.onReservationCreated,
  });

  final bool showBackButton;
  final ValueChanged<Map<String, dynamic>>? onOpenContract;
  final ValueChanged<Map<String, dynamic>>? onOpenPayment;
  final String userInitial;
  final VoidCallback? onBackToSearch;
  final ValueChanged<String?>? onReservationCreated;

  @override
  Widget build(BuildContext context) {
    return ClientFlightsList(
      heading: 'Tus vuelos privados',
      description: 'Consulta el estado de cada reserva de forma simple.',
      showBackButton: showBackButton,
      onOpenContract: onOpenContract,
      onOpenPayment: onOpenPayment,
    );
  }
}
