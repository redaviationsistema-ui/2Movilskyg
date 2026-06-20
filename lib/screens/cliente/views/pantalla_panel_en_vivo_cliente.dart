import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/client_workflow_status.dart';
import '../../../providers/proveedor_autenticacion.dart';
import '../../../providers/proveedor_reservaciones.dart';
import '../tema_cliente.dart';
import '../widgets/widgets_experiencia_cliente.dart';

class ClientLiveDashboardScreen extends StatefulWidget {
  const ClientLiveDashboardScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<ClientLiveDashboardScreen> createState() =>
      _ClientLiveDashboardScreenState();
}

class _ClientLiveDashboardScreenState extends State<ClientLiveDashboardScreen> {
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
    final auth = context.watch<AuthProvider>();
    final reservation = context.watch<ReservationProvider>();

    final metrics = Map<String, dynamic>.from(
      reservation.dashboardData?['metrics'] is Map
          ? reservation.dashboardData!['metrics'] as Map
          : <String, dynamic>{},
    );
    final requests = reservation.flightRequests;
    final fleet = reservation.aircraftFleet;
    final activeAccess = auth.accessData ?? const <String, dynamic>{};

    return ClientExperienceShell(
      title: 'Cabina Red Sky',
      subtitle: 'Datos reales de tus solicitudes, acceso y flota disponible.',
      showBackButton: widget.showBackButton,
      trailing: StatusBadge(
        label: reservation.isOnline ? 'En linea' : 'Offline',
        color:
            reservation.isOnline
                ? const Color(0xFF1B8F4D)
                : const Color(0xFFB46A00),
      ),
      child: RefreshIndicator(
        onRefresh: () => reservation.loadClientWorkspaceData(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            ClientHeroCard(
              badge: auth.displayName,
              title: 'Tu operacion privada ya vive dentro de la app',
              subtitle:
                  reservation.workspaceMessage ??
                  'Sincroniza tu cabina para ver solicitudes, acceso y aeronaves disponibles.',
              metrics: [
                ClientHeroMetric(
                  label: 'Solicitudes',
                  value: '${metrics['solicitudes'] ?? requests.length}',
                ),
                ClientHeroMetric(
                  label: 'Operaciones activas',
                  value: '${metrics['operaciones_activas'] ?? 0}',
                ),
                ClientHeroMetric(
                  label: 'Acceso',
                  value: _accessLabel(activeAccess),
                ),
              ],
              primaryLabel: 'Sincronizar',
              primaryAction:
                  () => reservation.loadClientWorkspaceData(force: true),
              secondaryLabel: 'Ver vuelos',
              secondaryAction: () {},
            ),
            const SizedBox(height: 24),
            const ClientSectionTitle(
              title: 'Resumen en vivo',
              subtitle:
                  'Lectura rapida de tu estado actual usando la informacion real del backend.',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  title: 'Flota visible',
                  value: '${fleet.length}',
                  helper: 'Aeronaves disponibles para el marketplace cliente.',
                ),
                _MetricCard(
                  title: 'Ultima sincronizacion',
                  value: _syncLabel(reservation),
                  helper: 'Marca la ultima vez que la app refresco tu cabina.',
                ),
                _MetricCard(
                  title: 'Cuenta',
                  value: auth.user?.email ?? 'Sin correo',
                  helper: 'Correo autenticado en sesion actual.',
                ),
              ],
            ),
            const SizedBox(height: 24),
            const ClientSectionTitle(
              title: 'Solicitudes recientes',
              subtitle:
                  'Las ultimas operaciones cargadas directamente desde tu historial real.',
            ),
            const SizedBox(height: 14),
            if (reservation.isLoadingWorkspace && requests.isEmpty)
              const GlassInfoCard(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (requests.isEmpty)
              const GlassInfoCard(
                child: Text(
                  'No hay solicitudes registradas para esta cuenta.',
                  style: TextStyle(color: Color(0xFF607080), height: 1.35),
                ),
              )
            else
              ...requests.take(4).map((request) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RequestCard(request: request),
                );
              }),
            const SizedBox(height: 24),
            const ClientSectionTitle(
              title: 'Flota conectada',
              subtitle:
                  'Muestra real de la base de aeronaves disponible para esta experiencia.',
            ),
            const SizedBox(height: 14),
            if (fleet.isEmpty)
              const GlassInfoCard(
                child: Text(
                  'Todavia no hay aeronaves disponibles para mostrar.',
                  style: TextStyle(color: Color(0xFF607080), height: 1.35),
                ),
              )
            else
              ...fleet.take(3).map((aircraft) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassInfoCard(
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF143955,
                            ).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.flight_takeoff_rounded,
                            color: Color(0xFF143955),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                aircraft.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: ClientThemeColors.brandNavy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${aircraft.capacityPassengers} pasajeros · ${aircraft.homeBase}',
                                style: const TextStyle(
                                  color: Color(0xFF607080),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(
                          label:
                              '\$${aircraft.rentalPriceUsd.toStringAsFixed(0)}/hr',
                          color: const Color(0xFF143955),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _accessLabel(Map<String, dynamic> access) {
    final subscription = access['subscription'];
    if (subscription is Map && subscription['status'] != null) {
      return subscription['status'].toString();
    }
    if (access['subscription_status'] != null) {
      return access['subscription_status'].toString();
    }
    if (access['has_access'] == true) {
      return 'Activo';
    }
    return 'Pendiente';
  }

  String _syncLabel(ReservationProvider provider) {
    final date = provider.lastWorkspaceSyncAt ?? provider.lastSyncAt;
    if (date == null) return 'Pendiente';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.helper,
  });

  final String title;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: GlassInfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF607080),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: ClientThemeColors.brandNavy,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              helper,
              style: const TextStyle(color: Color(0xFF607080), height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final route = _routeLabel(request);
    final status = resolveClientWorkflowLabel(request, fallback: 'Pendiente');
    final passengers = request['passengers']?.toString() ?? 'N/D';
    final departure =
        request['departure_datetime']?.toString() ??
        request['date']?.toString() ??
        'Sin fecha';

    return GlassInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  route,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ClientThemeColors.brandNavy,
                  ),
                ),
              ),
              StatusBadge(label: status, color: const Color(0xFF143955)),
            ],
          ),
          const SizedBox(height: 8),
          Text(departure, style: const TextStyle(color: Color(0xFF607080))),
          const SizedBox(height: 4),
          Text(
            '$passengers pasajeros',
            style: const TextStyle(color: Color(0xFF607080)),
          ),
        ],
      ),
    );
  }

  String _routeLabel(Map<String, dynamic> request) {
    final legs = request['legs'];
    if (legs is List && legs.isNotEmpty) {
      final first = legs.first;
      if (first is Map) {
        final origin = first['origin']?.toString() ?? '';
        final destination = first['destination']?.toString() ?? '';
        if (origin.isNotEmpty && destination.isNotEmpty) {
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
