// Nota: este archivo encapsula el selector modal de aeropuertos para mantener
// la pantalla principal enfocada en la logica del flujo de reservacion.
import 'package:flutter/material.dart';

import '../../../models/aeropuerto.dart';
import '../../cliente/tema_cliente.dart';
import '../../cliente/widgets/widgets_flujo_movil_cliente.dart';

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
    final palette = context.clientPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final search = _query.trim().toUpperCase();
    final filtered =
        widget.airports
            .where((airport) {
              if (search.isEmpty) return false;
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: palette.appGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: palette.accentBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color:
                            isDark
                                ? palette.heroTextPrimary
                                : palette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _controller,
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
                      style: TextStyle(
                        color:
                            isDark
                                ? palette.heroTextPrimary
                                : palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar ciudad, aeropuerto o codigo',
                        filled: true,
                        fillColor: palette.surface,
                        hintStyle: TextStyle(
                          color:
                              isDark
                                  ? palette.heroTextSecondary
                                  : palette.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: palette.accent,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: palette.accentBorder),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    search.isEmpty
                        ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Escribe para buscar un aeropuerto.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color:
                                    isDark
                                        ? palette.heroTextSecondary
                                        : palette.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        : filtered.isEmpty
                        ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'No encontramos aeropuertos con esa búsqueda.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color:
                                    isDark
                                        ? palette.heroTextSecondary
                                        : palette.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                          itemBuilder: (context, index) {
                            final airport = filtered[index];
                            final code =
                                airport.iata?.isNotEmpty == true
                                    ? airport.iata!
                                    : '--';

                            return ConciergeCard(
                              padding: const EdgeInsets.all(16),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  airport.city,
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  '${airport.name}\n$code',
                                  style: TextStyle(
                                    height: 1.35,
                                    color: palette.textSecondary,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: palette.accent,
                                ),
                                onTap: () => Navigator.pop(context, airport),
                              ),
                            );
                          },
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
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
