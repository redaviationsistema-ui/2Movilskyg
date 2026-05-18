import 'package:flutter/material.dart';

import '../models/route_model.dart';
import '../models/airport.dart';
import 'airport_selector.dart';

class RouteForm extends StatelessWidget {
  final RouteModel route;
  final List<Airport> airports;

  final ValueChanged<Airport?> onFromAirport;
  final ValueChanged<Airport?> onToAirport;
  final String routeType;

  const RouteForm({
    super.key,
    required this.route,
    required this.airports,
    required this.onFromAirport,
    required this.onToAirport,
    required this.routeType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ruta",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            /// FROM AIRPORT
            AirportSelector(
              airports: airports,
              selectedAirport: route.fromAirport,
              onChanged: onFromAirport,
              label: "Aeropuerto de origen",
            ),

            const SizedBox(height: 12),

            /// TO AIRPORT
            AirportSelector(
              airports: airports,
              selectedAirport: route.toAirport,
              onChanged: onToAirport,
              label: "Aeropuerto de destino",
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
