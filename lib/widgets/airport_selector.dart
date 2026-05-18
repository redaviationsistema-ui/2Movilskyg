import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
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
    return DropdownSearch<Airport>(
      selectedItem: selectedAirport,
      items: airports,

      popupProps: const PopupProps.menu(showSearchBox: true),

      /// TEXTO QUE SE MUESTRA
      itemAsString: (Airport airport) {
        return "${airport.city.toUpperCase()} - ${airport.name.toUpperCase()}";
      },

      /// 🔎 BUSQUEDA SIEMPRE EN MAYUSCULAS
      // filterFn: (airport, filter) {
      //   final search = filter.toUpperCase();

      //   return airport.city.toUpperCase().contains(search) ||
      //          airport.name.toUpperCase().contains(search);
      // },
      filterFn: (airport, filter) {
        final search = filter.trim().toUpperCase();

        final city = airport.city.trim().toUpperCase();
        final name = airport.name.trim().toUpperCase();

        return city.contains(search) || name.contains(search);
      },

      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),

      onChanged: onChanged,
    );
  }
}
