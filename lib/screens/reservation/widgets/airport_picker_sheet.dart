// Nota: este archivo encapsula el selector modal de aeropuertos para mantener
// la pantalla principal enfocada en la logica del flujo de reservacion.
import 'package:flutter/material.dart';

import '../../../models/airport.dart';
import '../../cliente/widgets/client_mobile_flow_widgets.dart';

class AirportPickerSheet extends StatefulWidget {
  const AirportPickerSheet({
    super.key,
    required this.title,
    required this.airports,
  });

  final String title;
  final List<Airport> airports;

  @override
  State<AirportPickerSheet> createState() => _AirportPickerSheetState();
}

class _AirportPickerSheetState extends State<AirportPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        widget.airports
            .where((airport) {
              final search = _query.trim().toUpperCase();
              if (search.isEmpty) return true;
              return airport.city.toUpperCase().contains(search) ||
                  airport.name.toUpperCase().contains(search) ||
                  (airport.iata ?? '').toUpperCase().contains(search);
            })
            .take(30)
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F3EA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6CABC),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar ciudad, aeropuerto o codigo',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemBuilder: (context, index) {
                    final airport = filtered[index];
                    final code =
                        airport.iata?.isNotEmpty == true ? airport.iata! : '--';

                    return ConciergeCard(
                      padding: const EdgeInsets.all(12),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          airport.city,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${airport.name}\n$code',
                          style: const TextStyle(height: 1.35),
                        ),
                        onTap: () => Navigator.pop(context, airport),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: filtered.length,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
