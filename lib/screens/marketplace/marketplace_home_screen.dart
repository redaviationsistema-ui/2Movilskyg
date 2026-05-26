// Nota: este archivo decide que workspace mostrar segun el rol autenticado;
// las vistas concretas del marketplace viven separadas por rol.
import 'package:flutter/material.dart';

import '../../providers/auth_provider.dart';
import '../cliente/client_mobile_workspace_screen.dart';
import '../shared/widgets/role_workspace_shell.dart';
import 'views/admin_marketplace_views.dart';
import 'views/provider_marketplace_views.dart';

class MarketplaceHomeScreen extends StatelessWidget {
  const MarketplaceHomeScreen({super.key, required this.role});

  final AppUserRole role;

  @override
  Widget build(BuildContext context) {
    switch (role) {
      case AppUserRole.client:
        return const ClientWorkspaceScreen();
      case AppUserRole.operator:
        return const OperatorWorkspaceScreen();
      case AppUserRole.admin:
        return const AdminWorkspaceScreen();
      case AppUserRole.unknown:
        return const ClientWorkspaceScreen();
    }
  }
}

class ClientWorkspaceScreen extends StatelessWidget {
  const ClientWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ClientMobileWorkspaceScreen();
  }
}

class OperatorWorkspaceScreen extends StatelessWidget {
  const OperatorWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleWorkspaceShell(
      branchLabel: 'Operaciones',
      roleLabel: 'Proveedor certificado',
      title: 'Red Sky Proveedor',
      items: [
        RoleWorkspaceItem(
          label: 'Dashboard',
          shortLabel: 'Inicio',
          icon: Icons.dashboard_customize_rounded,
          screen: ProviderHomeScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Aeronaves',
          shortLabel: 'Aviones',
          icon: Icons.airplanemode_active_rounded,
          screen: ProviderAircraftScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Disponibilidad',
          shortLabel: 'Agenda',
          icon: Icons.calendar_month_rounded,
          screen: ProviderCalendarScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Solicitudes',
          shortLabel: 'Solic.',
          icon: Icons.request_quote_rounded,
          screen: ProviderRequestsScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Operacion',
          shortLabel: 'Vuelos',
          icon: Icons.event_available_rounded,
          screen: ProviderOperationsScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Perfil',
          shortLabel: 'Perfil',
          icon: Icons.business_center_rounded,
          screen: ProviderProfileScreen(),
        ),
      ],
    );
  }
}

class AdminWorkspaceScreen extends StatelessWidget {
  const AdminWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleWorkspaceShell(
      branchLabel: 'Administracion',
      roleLabel: 'Administrador',
      title: 'Red Sky Administracion',
      items: [
        RoleWorkspaceItem(
          label: 'Dashboard',
          shortLabel: 'Inicio',
          icon: Icons.dashboard_rounded,
          screen: AdminHomeScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Usuarios',
          shortLabel: 'Usuarios',
          icon: Icons.people_alt_rounded,
          screen: AdminUsersScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Proveedores',
          shortLabel: 'Prov.',
          icon: Icons.groups_rounded,
          screen: AdminProvidersScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Aeronaves',
          shortLabel: 'Flota',
          icon: Icons.flight_class_rounded,
          screen: AdminAircraftScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Solicitudes',
          shortLabel: 'Solic.',
          icon: Icons.request_quote_rounded,
          screen: AdminRequestsScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Cotizaciones',
          shortLabel: 'Cotiza',
          icon: Icons.receipt_long_rounded,
          screen: AdminQuotesScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Reportes',
          shortLabel: 'Reportes',
          icon: Icons.query_stats_rounded,
          screen: AdminReportsScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Configuracion',
          shortLabel: 'Config',
          icon: Icons.settings_rounded,
          screen: AdminSettingsScreen(),
        ),
      ],
    );
  }
}
