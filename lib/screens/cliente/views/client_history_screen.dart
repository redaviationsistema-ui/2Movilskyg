import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/reservation_provider.dart';
import '../widgets/client_experience_widgets.dart';

class ClientHistoryScreen extends StatefulWidget {
  const ClientHistoryScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<ClientHistoryScreen> createState() => _ClientHistoryScreenState();
}

class _ClientHistoryScreenState extends State<ClientHistoryScreen> {
  @override
  void initState() {
    super.initState();
    final provider = context.read<ReservationProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      provider.loadClientWorkspaceData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReservationProvider>();
    final requests = provider.flightRequests;

    return ClientExperienceShell(
      title: 'Mis vuelos',
      subtitle: 'Historial real de solicitudes y operaciones del cliente.',
      showBackButton: widget.showBackButton,
      trailing: StatusBadge(
        label: '${requests.length} registros',
        color: const Color(0xFF143955),
      ),
      child: RefreshIndicator(
        onRefresh: () => provider.loadClientWorkspaceData(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            ClientHeroCard(
              badge: 'Flight requests',
              title: 'Tu historial ya sale directo del backend',
              subtitle:
                  provider.workspaceMessage ??
                  'Esta vista se alimenta de tus solicitudes reales y del estado operativo recibido por la API.',
              metrics: [
                ClientHeroMetric(
                  label: 'Solicitudes',
                  value: requests.length.toString(),
                ),
                ClientHeroMetric(
                  label: 'Activas',
                  value:
                      requests
                          .where((item) => !_isClosed(item))
                          .length
                          .toString(),
                ),
                ClientHeroMetric(
                  label: 'Cerradas',
                  value: requests.where(_isClosed).length.toString(),
                ),
              ],
              primaryLabel: 'Actualizar',
              primaryAction:
                  () => provider.loadClientWorkspaceData(force: true),
              secondaryLabel: 'Sincronizar flota',
              secondaryAction: () => provider.loadInitialData(),
            ),
            const SizedBox(height: 24),
            const ClientSectionTitle(
              title: 'Historial de solicitudes',
              subtitle:
                  'Cada tarjeta representa un registro real devuelto por la base de datos.',
            ),
            const SizedBox(height: 14),
            if (provider.isLoadingWorkspace && requests.isEmpty)
              const GlassInfoCard(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (requests.isEmpty)
              const GlassInfoCard(
                child: Text(
                  'No hay vuelos registrados para esta cuenta.',
                  style: TextStyle(color: Color(0xFF607080), height: 1.35),
                ),
              )
            else
              ...requests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _FlightRequestCard(request: request),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isClosed(Map<String, dynamic> request) {
    final status =
        request['workflow_status']?.toString().toLowerCase() ??
        request['status']?.toString().toLowerCase() ??
        '';
    return status.contains('completed') ||
        status.contains('cancel') ||
        status.contains('final');
  }
}

class _FlightRequestCard extends StatelessWidget {
  const _FlightRequestCard({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final route = _routeLabel();
    final status =
        request['workflow_status']?.toString() ??
        request['status']?.toString() ??
        'pendiente';
    final departure =
        request['departure_datetime']?.toString() ??
        request['date']?.toString() ??
        'Sin fecha';
    final aircraft =
        request['aircraft']?.toString() ??
        request['aircraft_model']?.toString() ??
        request['assigned_aircraft_model']?.toString() ??
        'Por asignar';
    final total =
        request['estimated_total']?.toString() ??
        request['final_price']?.toString() ??
        request['price']?.toString() ??
        'Pendiente';

    return GlassInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10253A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      departure,
                      style: const TextStyle(
                        color: Color(0xFF607080),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(label: status, color: const Color(0xFF143955)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: PricePill(label: 'Aeronave', value: aircraft)),
              const SizedBox(width: 10),
              Expanded(child: PricePill(label: 'Total', value: total)),
            ],
          ),
        ],
      ),
    );
  }

  String _routeLabel() {
    final legs = request['legs'];
    if (legs is List && legs.isNotEmpty) {
      final first = legs.first;
      if (first is Map) {
        final origin = first['origin']?.toString() ?? '';
        final destination = first['destination']?.toString() ?? '';
        if (origin.isNotEmpty || destination.isNotEmpty) {
          return '$origin -> $destination';
        }
      }
    }

    final origin = request['origin']?.toString() ?? '';
    final destination = request['destination']?.toString() ?? '';
    if (origin.isNotEmpty || destination.isNotEmpty) {
      return '$origin -> $destination';
    }

    return 'Ruta por confirmar';
  }
}
