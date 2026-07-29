// Nota: este archivo encapsula el selector modal de aeropuertos para mantener
// la pantalla principal enfocada en la logica del flujo de reservacion.
import 'package:flutter/material.dart';

import '../../../models/aeropuerto.dart';

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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF101C2D), Color(0xFF07111D)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9B25F).withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ciudad, aeropuerto o código',
                        filled: true,
                        fillColor: const Color(
                          0xFF07111D,
                        ).withValues(alpha: .7),
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: .42),
                          fontSize: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFFD9B25F),
                        ),
                        suffixIcon:
                            search.isEmpty
                                ? null
                                : IconButton(
                                  tooltip: 'Limpiar',
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: Colors.white.withValues(alpha: .5),
                                  ),
                                ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 17,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: .08),
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          borderSide: BorderSide(
                            color: Color(0xFFD9B25F),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    search.isEmpty
                        ? const _AirportEmptyState(
                          icon: Icons.travel_explore_rounded,
                          message: 'Busca tu próximo aeropuerto.',
                        )
                        : filtered.isEmpty
                        ? const _AirportEmptyState(
                          icon: Icons.location_off_outlined,
                          message: 'No encontramos ese aeropuerto.',
                        )
                        : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(24, 2, 24, 28),
                          itemBuilder: (context, index) {
                            final airport = filtered[index];
                            final code =
                                airport.iata?.isNotEmpty == true
                                    ? airport.iata!
                                    : '--';

                            return Material(
                              color: const Color(0xFF101C2D),
                              borderRadius: BorderRadius.circular(22),
                              child: InkWell(
                                onTap: () => Navigator.pop(context, airport),
                                borderRadius: BorderRadius.circular(22),
                                child: Container(
                                  height: 78,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: .08,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFD9B25F,
                                          ).withValues(alpha: .1),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        child: Text(
                                          code.toUpperCase(),
                                          style: const TextStyle(
                                            color: Color(0xFFD9B25F),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 13),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              airport.city,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              airport.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: .55,
                                                ),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: Colors.white.withValues(
                                          alpha: .42,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 10),
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

class _AirportEmptyState extends StatelessWidget {
  const _AirportEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF101C2D),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Icon(icon, color: const Color(0xFFD9B25F), size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .58),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
