import 'package:flutter/material.dart';
import '../models/airport.dart';

class AirportSelector extends StatelessWidget {
  final List<Airport> airports;
  final Airport? selectedAirport;
  final ValueChanged<Airport?> onChanged;
  final String label;

  const AirportSelector({
    super.key,
    required this.airports,
    required this.selectedAirport,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Airport>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();

        // No mostrar nada si no han escrito
        if (query.isEmpty) {
          return const Iterable<Airport>.empty();
        }

        return airports.where((airport) {
          return airport.city.toLowerCase().contains(query) ||
              airport.name.toLowerCase().contains(query) ||
              (airport.state ?? "").toLowerCase().contains(query);
        });
      },

      displayStringForOption: (Airport airport) {
        return "${airport.city} - ${airport.name}";
      },

      onSelected: (Airport airport) {
        onChanged(airport);
      },

      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        if (selectedAirport != null && controller.text.isEmpty) {
          controller.text =
              "${selectedAirport!.city} - ${selectedAirport!.name}";
        }

        return TextField(
          controller: controller,
          focusNode: focusNode,

          decoration: InputDecoration(
            labelText: label,
            hintText: "Search airport...",
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },

      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,

          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),

            child: Container(
              constraints: const BoxConstraints(maxHeight: 280),

              width: MediaQuery.of(context).size.width * 0.9,

              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,

                itemBuilder: (context, index) {
                  final airport = options.elementAt(index);

                  return ListTile(
                    leading: const Icon(Icons.flight, color: Colors.blue),

                    title: Text(
                      airport.city,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    subtitle: Text(
                      airport.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    trailing:
                        airport.state != null
                            ? Text(
                              airport.state!,
                              style: const TextStyle(color: Colors.grey),
                            )
                            : null,

                    onTap: () {
                      onSelected(airport);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
