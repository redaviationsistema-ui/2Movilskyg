// import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

import 'pantalla_reservacion.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  void goHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ReservationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                /// ICON
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 110,
                ),

                const SizedBox(height: 30),

                /// TITLE
                Text(
                  "Reservacion confirmada",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                /// MESSAGE
                Text(
                  "Tu solicitud de reservacion fue recibida correctamente.\n"
                  "Nuestro equipo te contactara en breve para finalizar los detalles.",
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                /// BUTTON
                SizedBox(
                  width: double.infinity,

                  child: ElevatedButton(
                    onPressed: () => goHome(context),

                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),

                    child: const Text(
                      "Volver al inicio",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
