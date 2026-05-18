// ignore_for_file: unused_element

import 'package:flutter/material.dart';

import '../../models/marketplace_models.dart';
import '../../providers/auth_provider.dart';
import '../cliente/client_mobile_workspace_screen.dart';
import '../shared/static_role_screen.dart';
import '../shared/widgets/role_workspace_shell.dart';

class MarketplaceHomeScreen extends StatelessWidget {
  const MarketplaceHomeScreen({super.key, required this.role});

  final AppUserRole role;

  @override
  Widget build(BuildContext context) {
    switch (role) {
      case AppUserRole.client:
        return const _ClientWorkspaceScreen();
      case AppUserRole.operator:
        return const _OperatorWorkspaceScreen();
      case AppUserRole.admin:
        return const _AdminWorkspaceScreen();
      case AppUserRole.unknown:
        return const _ClientWorkspaceScreen();
    }
  }
}

class _ClientWorkspaceScreen extends StatelessWidget {
  const _ClientWorkspaceScreen();

  @override
  Widget build(BuildContext context) {
    return const ClientMobileWorkspaceScreen();
  }
}

class _OperatorWorkspaceScreen extends StatelessWidget {
  const _OperatorWorkspaceScreen();

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
          screen: _ProviderHomeScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Aeronaves',
          shortLabel: 'Aviones',
          icon: Icons.airplanemode_active_rounded,
          screen: _ProviderAircraftScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Disponibilidad',
          shortLabel: 'Agenda',
          icon: Icons.calendar_month_rounded,
          screen: _ProviderCalendarScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Solicitudes',
          shortLabel: 'Solic.',
          icon: Icons.request_quote_rounded,
          screen: _ProviderRequestsScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Operacion',
          shortLabel: 'Vuelos',
          icon: Icons.event_available_rounded,
          screen: _ProviderOperationsScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Perfil',
          shortLabel: 'Perfil',
          icon: Icons.business_center_rounded,
          screen: _ProviderProfileScreen(),
        ),
      ],
    );
  }
}

class _AdminWorkspaceScreen extends StatelessWidget {
  const _AdminWorkspaceScreen();

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
          screen: _AdminHomeScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Usuarios',
          shortLabel: 'Usuarios',
          icon: Icons.people_alt_rounded,
          screen: _AdminUsersScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Proveedores',
          shortLabel: 'Prov.',
          icon: Icons.groups_rounded,
          screen: _AdminProvidersScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Aeronaves',
          shortLabel: 'Flota',
          icon: Icons.flight_class_rounded,
          screen: _AdminAircraftScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Solicitudes',
          shortLabel: 'Solic.',
          icon: Icons.request_quote_rounded,
          screen: _AdminRequestsScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Cotizaciones',
          shortLabel: 'Cotiza',
          icon: Icons.receipt_long_rounded,
          screen: _AdminQuotesScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Reportes',
          shortLabel: 'Reportes',
          icon: Icons.query_stats_rounded,
          screen: _AdminReportsScreen(),
        ),
        RoleWorkspaceItem(
          label: 'Configuracion',
          shortLabel: 'Config',
          icon: Icons.settings_rounded,
          screen: _AdminSettingsScreen(),
        ),
      ],
    );
  }
}

class _ClientHomeScreen extends StatelessWidget {
  const _ClientHomeScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Inicio cliente',
      subtitle: 'Resumen para buscar, cotizar y reservar vuelos privados.',
      roleLabel: 'Cliente',
      heroTitle: 'Cotiza y reserva vuelos privados en pocos pasos',
      heroSubtitle:
          'La pantalla inicial muestra demo activa, proximas acciones, cotizaciones recientes y acceso directo al flujo de busqueda.',
      metrics: [
        MarketplaceMetric(
          label: 'Demo',
          value: '12 dias',
          helper: 'Periodo gratuito activo antes de requerir plan.',
        ),
        MarketplaceMetric(
          label: 'Cotizaciones',
          value: '3 abiertas',
          helper: 'Propuestas esperando decision del cliente.',
        ),
        MarketplaceMetric(
          label: 'Viajes',
          value: '1 confirmado',
          helper: 'Servicio con seguimiento y asistente ejecutivo.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.search_rounded,
          label: 'Buscar vuelo',
          message: 'Abre Buscar vuelos para crear una solicitud.',
        ),
        StaticAction(
          icon: Icons.workspace_premium_rounded,
          label: 'Ver plan',
          message: 'Estado de membresia listo para conectar pagos.',
        ),
        StaticAction(
          icon: Icons.support_agent_rounded,
          label: 'Asistente',
          message: 'Asistente ejecutivo listo para soporte VIP.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'Toluca -> Cancun',
          subtitle: '6 pasajeros | salida manana 09:30',
          status: 'Pendiente',
          amount: '\$18,900 USD',
        ),
        StaticRecord(
          title: 'Monterrey -> Los Cabos',
          subtitle: '4 pasajeros | jet ligero recomendado',
          status: 'Cotizado',
          amount: '\$21,400 USD',
        ),
        StaticRecord(
          title: 'Guadalajara -> Houston',
          subtitle: 'Ruta internacional con revision operativa',
          status: 'En revision',
          amount: '\$34,700 USD',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Buscar vuelos',
          description:
              'Origen, destino, fecha, hora y pasajeros desde una vista simple.',
        ),
        MarketplaceModule(
          title: 'Comparar aeronaves',
          description:
              'Precio estimado, capacidad, operador, autonomia y disponibilidad.',
        ),
        MarketplaceModule(
          title: 'Reservar o solicitar',
          description:
              'El cliente puede avanzar a cotizacion o reservacion segun el caso.',
        ),
      ],
    );
  }
}

class _ClientQuotesScreen extends StatelessWidget {
  const _ClientQuotesScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Mis cotizaciones',
      subtitle: 'Propuestas recibidas, pendientes, aceptadas y vencidas.',
      roleLabel: 'Cliente',
      heroTitle: 'Cotizaciones claras para decidir rapido',
      heroSubtitle:
          'Cada propuesta concentra ruta, aeronave sugerida, precio estimado, operador y vigencia.',
      metrics: [
        MarketplaceMetric(
          label: 'Pendientes',
          value: '2',
          helper: 'Esperando respuesta de proveedor.',
        ),
        MarketplaceMetric(
          label: 'Aceptadas',
          value: '1',
          helper: 'Lista para confirmar pago o reserva.',
        ),
        MarketplaceMetric(
          label: 'Vigencia',
          value: '24 h',
          helper: 'Tiempo promedio antes de actualizar tarifa.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.compare_arrows_rounded,
          label: 'Comparar',
          message: 'Comparador de cotizaciones listo.',
        ),
        StaticAction(
          icon: Icons.check_circle_rounded,
          label: 'Aceptar',
          message: 'Aceptacion preparada para conectar backend.',
        ),
        StaticAction(
          icon: Icons.close_rounded,
          label: 'Rechazar',
          message: 'Rechazo registrado como accion estatica.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'Citation CJ3 | TLC -> CUN',
          subtitle: 'Operador Red Charter | vigencia 18 h',
          status: 'Cotizado',
          amount: '\$18,900 USD',
        ),
        StaticRecord(
          title: 'Learjet 45 | MTY -> SJD',
          subtitle: 'Incluye pernocta y gastos nacionales',
          status: 'Pendiente',
          amount: '\$21,400 USD',
        ),
        StaticRecord(
          title: 'Challenger 604 | GDL -> IAH',
          subtitle: 'Requiere validacion internacional',
          status: 'En revision',
          amount: '\$34,700 USD',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Detalle de propuesta',
          description: 'Aeronave, operador, costo, notas y vigencia.',
        ),
        MarketplaceModule(
          title: 'Estatus comercial',
          description: 'Pendiente, cotizada, aceptada, rechazada o vencida.',
        ),
        MarketplaceModule(
          title: 'Accion rapida',
          description: 'Aceptar, pedir ajuste o solicitar llamada ejecutiva.',
        ),
      ],
    );
  }
}

class _ClientTripsScreen extends StatelessWidget {
  const _ClientTripsScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Mis viajes',
      subtitle: 'Reservas confirmadas, seguimiento y viajes anteriores.',
      roleLabel: 'Cliente',
      heroTitle: 'Historial y seguimiento de vuelos',
      heroSubtitle:
          'El cliente ve vuelos solicitados, confirmados, finalizados y el estado operativo del servicio.',
      metrics: [
        MarketplaceMetric(
          label: 'Confirmados',
          value: '1',
          helper: 'Vuelo con aeronave asignada.',
        ),
        MarketplaceMetric(
          label: 'En seguimiento',
          value: '2',
          helper: 'Servicios con asistente y timeline.',
        ),
        MarketplaceMetric(
          label: 'Historial',
          value: '8',
          helper: 'Rutas anteriores listas para repetir.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.refresh_rounded,
          label: 'Repetir ruta',
          message: 'Ruta preparada para nueva cotizacion.',
        ),
        StaticAction(
          icon: Icons.route_rounded,
          label: 'Ver seguimiento',
          message: 'Seguimiento estatico abierto.',
        ),
        StaticAction(
          icon: Icons.receipt_long_rounded,
          label: 'Ver recibo',
          message: 'Recibo listo para conectar PDF.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'TLC -> CUN',
          subtitle: 'Confirmado | FBO Toluca | 09:30',
          status: 'Confirmado',
          amount: '\$18,900 USD',
        ),
        StaticRecord(
          title: 'CUN -> TLC',
          subtitle: 'Regreso sugerido | tripulacion validada',
          status: 'Pendiente',
          amount: '\$17,800 USD',
        ),
        StaticRecord(
          title: 'MTY -> TLC',
          subtitle: 'Finalizado | marzo 2026',
          status: 'Finalizado',
          amount: '\$12,600 USD',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Seguimiento operativo',
          description: 'FBO, tripulacion, horarios y estado de servicio.',
        ),
        MarketplaceModule(
          title: 'Historial de rutas',
          description: 'Repetir viajes frecuentes con menos friccion.',
        ),
        MarketplaceModule(
          title: 'Documentos',
          description: 'Recibos, cotizaciones, politicas y comprobantes.',
        ),
      ],
    );
  }
}

class _ProviderHomeScreen extends StatelessWidget {
  const _ProviderHomeScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Dashboard proveedor',
      subtitle: 'Operacion diaria de flota, solicitudes y disponibilidad.',
      roleLabel: 'Proveedor',
      heroTitle: 'Control operativo para vender disponibilidad real',
      heroSubtitle:
          'El proveedor ve aeronaves activas, solicitudes recibidas, vuelos asignados e ingresos estimados.',
      metrics: [
        MarketplaceMetric(
          label: 'Aeronaves activas',
          value: '7',
          helper: 'Unidades visibles para el marketplace.',
        ),
        MarketplaceMetric(
          label: 'Solicitudes',
          value: '14',
          helper: 'Rutas esperando aceptar, rechazar o contraofertar.',
        ),
        MarketplaceMetric(
          label: 'Ingresos estimados',
          value: '\$84k',
          helper: 'Pipeline comercial del mes.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.flight_rounded,
          label: 'Nueva aeronave',
          message: 'Formulario de alta preparado.',
        ),
        StaticAction(
          icon: Icons.calendar_month_rounded,
          label: 'Actualizar agenda',
          message: 'Disponibilidad lista para editar.',
        ),
        StaticAction(
          icon: Icons.request_quote_rounded,
          label: 'Responder solicitudes',
          message: 'Bandeja de solicitudes abierta.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'Citation XLS+',
          subtitle: 'Disponible hoy | base TLC',
          status: 'Activo',
          amount: '\$4,900/hr',
        ),
        StaticRecord(
          title: 'King Air 350',
          subtitle: 'Mantenimiento preventivo | 2 dias',
          status: 'Bloqueado',
          amount: '\$2,100/hr',
        ),
        StaticRecord(
          title: 'Challenger 604',
          subtitle: 'Solicitud GDL -> IAH',
          status: 'Pendiente',
          amount: '\$34,700 USD',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Flota activa',
          description:
              'Alta, edicion, fotos, documentos, tarifas y amenidades.',
        ),
        MarketplaceModule(
          title: 'Disponibilidad',
          description: 'Calendario por aeronave con bloqueos y mantenimiento.',
        ),
        MarketplaceModule(
          title: 'Solicitudes',
          description: 'Aceptar, rechazar o contraofertar rutas entrantes.',
        ),
      ],
    );
  }
}

class _ProviderAircraftScreen extends StatelessWidget {
  const _ProviderAircraftScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Aeronaves',
      subtitle: 'Alta, edicion y control comercial de flota.',
      roleLabel: 'Proveedor',
      heroTitle: 'Gestiona la flota que aparece en el marketplace',
      heroSubtitle:
          'Cada aeronave muestra matricula, capacidad, tarifa por hora, estado, fotos y servicios incluidos.',
      metrics: [
        MarketplaceMetric(
          label: 'Publicadas',
          value: '7',
          helper: 'Aeronaves visibles para clientes.',
        ),
        MarketplaceMetric(
          label: 'En revision',
          value: '2',
          helper: 'Pendientes de documentos o fotos.',
        ),
        MarketplaceMetric(
          label: 'Bloqueadas',
          value: '1',
          helper: 'Fuera de disponibilidad comercial.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.add_rounded,
          label: 'Alta aeronave',
          message: 'Alta estatica lista para conectar.',
        ),
        StaticAction(
          icon: Icons.photo_camera_rounded,
          label: 'Cargar fotos',
          message: 'Carga de imagenes preparada.',
        ),
        StaticAction(
          icon: Icons.price_change_rounded,
          label: 'Editar tarifa',
          message: 'Tarifas listas para guardar.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'XA-SKY | Citation CJ3',
          subtitle: '7 pasajeros | WiFi | base TLC',
          status: 'Activo',
          amount: '\$3,900/hr',
        ),
        StaticRecord(
          title: 'XB-LUX | Learjet 45',
          subtitle: '8 pasajeros | catering | base MTY',
          status: 'Activo',
          amount: '\$4,400/hr',
        ),
        StaticRecord(
          title: 'N604SG | Challenger 604',
          subtitle: '12 pasajeros | internacional',
          status: 'Revision',
          amount: '\$7,900/hr',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Ficha tecnica',
          description: 'Modelo, matricula, capacidad, autonomia y base.',
        ),
        MarketplaceModule(
          title: 'Comercial',
          description:
              'Tarifa por hora, minimos, gastos y servicios incluidos.',
        ),
        MarketplaceModule(
          title: 'Media y documentos',
          description: 'Fotos, seguros, permisos y vencimientos.',
        ),
      ],
    );
  }
}

class _ProviderRequestsScreen extends StatelessWidget {
  const _ProviderRequestsScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Solicitudes recibidas',
      subtitle: 'Rutas entrantes para aceptar, rechazar o contraofertar.',
      roleLabel: 'Proveedor',
      heroTitle: 'Responde solicitudes con rapidez operativa',
      heroSubtitle:
          'Cada solicitud incluye ruta, fecha, hora, pasajeros, precio sugerido y acciones comerciales.',
      metrics: [
        MarketplaceMetric(
          label: 'Nuevas',
          value: '5',
          helper: 'Requieren primera respuesta.',
        ),
        MarketplaceMetric(
          label: 'Contraofertas',
          value: '3',
          helper: 'En negociacion con cliente.',
        ),
        MarketplaceMetric(
          label: 'SLA',
          value: '12 min',
          helper: 'Tiempo promedio de respuesta.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.check_rounded,
          label: 'Aceptar',
          message: 'Solicitud aceptada de forma estatica.',
        ),
        StaticAction(
          icon: Icons.close_rounded,
          label: 'Rechazar',
          message: 'Solicitud rechazada de forma estatica.',
        ),
        StaticAction(
          icon: Icons.swap_horiz_rounded,
          label: 'Contraofertar',
          message: 'Contraoferta preparada.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'TLC -> CUN',
          subtitle: '6 pasajeros | manana 09:30 | Citation CJ3',
          status: 'Nueva',
          amount: '\$18,900 USD',
        ),
        StaticRecord(
          title: 'MTY -> SJD',
          subtitle: '4 pasajeros | salida viernes | Learjet 45',
          status: 'Pendiente',
          amount: '\$21,400 USD',
        ),
        StaticRecord(
          title: 'GDL -> IAH',
          subtitle: '12 pasajeros | internacional | Challenger 604',
          status: 'Revision',
          amount: '\$34,700 USD',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Aceptar',
          description: 'Confirma disponibilidad y envia oferta al cliente.',
        ),
        MarketplaceModule(
          title: 'Rechazar',
          description:
              'Registra motivo: mantenimiento, ocupada o ruta no viable.',
        ),
        MarketplaceModule(
          title: 'Contraofertar',
          description: 'Ajusta aeronave, horario, tarifa o condiciones.',
        ),
      ],
    );
  }
}

class _ProviderOperationsScreen extends StatelessWidget {
  const _ProviderOperationsScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Operacion',
      subtitle: 'Vuelos proximos, en curso, finalizados e historial operativo.',
      roleLabel: 'Proveedor',
      heroTitle: 'Controla vuelos asignados de punta a punta',
      heroSubtitle:
          'La vista operativa concentra agenda, tripulacion, estado de vuelo, FBO y notas internas.',
      metrics: [
        MarketplaceMetric(
          label: 'Proximos',
          value: '4',
          helper: 'Servicios confirmados por operar.',
        ),
        MarketplaceMetric(
          label: 'En curso',
          value: '1',
          helper: 'Vuelo activo con seguimiento.',
        ),
        MarketplaceMetric(
          label: 'Finalizados',
          value: '23',
          helper: 'Historial del mes.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.play_circle_rounded,
          label: 'Iniciar vuelo',
          message: 'Vuelo marcado como en curso.',
        ),
        StaticAction(
          icon: Icons.flag_rounded,
          label: 'Finalizar',
          message: 'Vuelo marcado como finalizado.',
        ),
        StaticAction(
          icon: Icons.note_add_rounded,
          label: 'Agregar nota',
          message: 'Nota operativa preparada.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'TLC -> CUN',
          subtitle: 'FBO Toluca | capitan asignado',
          status: 'Confirmado',
          amount: '09:30',
        ),
        StaticRecord(
          title: 'CUN -> TLC',
          subtitle: 'Regreso | tripulacion pendiente',
          status: 'Pendiente',
          amount: '18:10',
        ),
        StaticRecord(
          title: 'MTY -> TLC',
          subtitle: 'Finalizado sin incidencias',
          status: 'Finalizado',
          amount: 'Ayer',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Vuelos proximos',
          description: 'Agenda operativa y preparacion del servicio.',
        ),
        MarketplaceModule(
          title: 'Vuelos en curso',
          description: 'Estado, notas y actualizaciones para cliente/admin.',
        ),
        MarketplaceModule(
          title: 'Historial',
          description: 'Finalizados, cancelados e incidencias operativas.',
        ),
      ],
    );
  }
}

class _ProviderProfileScreen extends StatelessWidget {
  const _ProviderProfileScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Perfil proveedor',
      subtitle: 'Informacion empresarial, documentos, usuarios y plan activo.',
      roleLabel: 'Proveedor',
      heroTitle: 'Perfil comercial y operativo del proveedor',
      heroSubtitle:
          'Centraliza razon social, contactos, documentos, comisiones, plan y permisos internos.',
      metrics: [
        MarketplaceMetric(
          label: 'Plan',
          value: 'Pro activo',
          helper: 'Membresia operativa vigente.',
        ),
        MarketplaceMetric(
          label: 'Documentos',
          value: '92%',
          helper: 'Expediente casi completo.',
        ),
        MarketplaceMetric(
          label: 'Usuarios',
          value: '4',
          helper: 'Equipo con acceso al panel.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.edit_rounded,
          label: 'Editar perfil',
          message: 'Perfil listo para editar.',
        ),
        StaticAction(
          icon: Icons.upload_file_rounded,
          label: 'Subir documento',
          message: 'Carga documental preparada.',
        ),
        StaticAction(
          icon: Icons.group_add_rounded,
          label: 'Invitar usuario',
          message: 'Invitacion preparada.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'Sky Operator SA de CV',
          subtitle: 'Proveedor aprobado | Mexico',
          status: 'Activo',
          amount: 'Pro',
        ),
        StaticRecord(
          title: 'Seguro RC aeronaves',
          subtitle: 'Vence en 42 dias',
          status: 'Revision',
          amount: 'PDF',
        ),
        StaticRecord(
          title: 'Comision marketplace',
          subtitle: 'Tarifa vigente por vuelo confirmado',
          status: 'Activo',
          amount: '11%',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Empresa',
          description: 'Razon social, RFC, contacto comercial y operaciones.',
        ),
        MarketplaceModule(
          title: 'Documentos',
          description: 'Seguros, certificados, permisos y vencimientos.',
        ),
        MarketplaceModule(
          title: 'Plan y usuarios',
          description: 'Suscripcion, permisos y equipo interno.',
        ),
      ],
    );
  }
}

class _AdminHomeScreen extends StatelessWidget {
  const _AdminHomeScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Dashboard admin',
      subtitle: 'Vision general del negocio y operacion del marketplace.',
      roleLabel: 'Administrador',
      heroTitle: 'Control total de usuarios, vuelos y conversion comercial',
      heroSubtitle:
          'El admin ve solicitudes, vuelos confirmados, proveedores activos, aeronaves, ingresos, comisiones y alertas.',
      metrics: [
        MarketplaceMetric(
          label: 'Solicitudes',
          value: '128',
          helper: 'Rutas recibidas este mes.',
        ),
        MarketplaceMetric(
          label: 'Vuelos confirmados',
          value: '36',
          helper: 'Reservas con aeronave asignada.',
        ),
        MarketplaceMetric(
          label: 'Comision estimada',
          value: '\$42k',
          helper: 'Ingreso de marketplace proyectado.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.warning_rounded,
          label: 'Ver alertas',
          message: 'Alertas operativas listas.',
        ),
        StaticAction(
          icon: Icons.groups_rounded,
          label: 'Validar proveedor',
          message: 'Validacion de proveedor preparada.',
        ),
        StaticAction(
          icon: Icons.query_stats_rounded,
          label: 'Abrir reporte',
          message: 'Reporte ejecutivo listo.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'Proveedor pendiente',
          subtitle: 'Aero Norte requiere revision documental',
          status: 'Revision',
          amount: 'Hoy',
        ),
        StaticRecord(
          title: 'Solicitud critica',
          subtitle: 'GDL -> IAH | salida en 6 horas',
          status: 'Pendiente',
          amount: '\$34,700',
        ),
        StaticRecord(
          title: 'Pago recibido',
          subtitle: 'Cliente corporativo | plan Pro anual',
          status: 'Confirmado',
          amount: '\$2,490',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Monitoreo comercial',
          description: 'Cotizaciones, reservas, conversion y pagos.',
        ),
        MarketplaceModule(
          title: 'Control operativo',
          description: 'Proveedores, aeronaves, disponibilidad y alertas.',
        ),
        MarketplaceModule(
          title: 'Gobierno de plataforma',
          description: 'Usuarios, roles, demos, suscripciones y configuracion.',
        ),
      ],
    );
  }
}

class _AdminProvidersScreen extends StatelessWidget {
  const _AdminProvidersScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Proveedores',
      subtitle: 'Alta, validacion, documentos, performance y estado comercial.',
      roleLabel: 'Administrador',
      heroTitle: 'Gestiona proveedores certificados',
      heroSubtitle:
          'Controla aprobaciones, disponibilidad general, nivel de respuesta y expediente documental.',
      metrics: [
        MarketplaceMetric(
          label: 'Activos',
          value: '47',
          helper: 'Proveedores aprobados para operar.',
        ),
        MarketplaceMetric(
          label: 'Pendientes',
          value: '8',
          helper: 'Esperan validacion documental.',
        ),
        MarketplaceMetric(
          label: 'Respuesta',
          value: '14 min',
          helper: 'Promedio de la red.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.verified_rounded,
          label: 'Aprobar',
          message: 'Proveedor aprobado en modo estatico.',
        ),
        StaticAction(
          icon: Icons.block_rounded,
          label: 'Bloquear',
          message: 'Bloqueo preparado para backend.',
        ),
        StaticAction(
          icon: Icons.description_rounded,
          label: 'Ver documentos',
          message: 'Expediente documental abierto.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'Sky Operator',
          subtitle: '7 aeronaves | respuesta 9 min',
          status: 'Activo',
          amount: '92%',
        ),
        StaticRecord(
          title: 'Aero Norte',
          subtitle: 'Documentos incompletos',
          status: 'Revision',
          amount: '68%',
        ),
        StaticRecord(
          title: 'Executive Wings',
          subtitle: 'Performance alto | 12 vuelos',
          status: 'Activo',
          amount: '98%',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Validacion',
          description: 'Documentos, seguros, permisos y aprobacion comercial.',
        ),
        MarketplaceModule(
          title: 'Performance',
          description: 'Respuesta, aceptacion, cancelaciones e ingresos.',
        ),
        MarketplaceModule(
          title: 'Disponibilidad global',
          description: 'Vista consolidada de flota por proveedor.',
        ),
      ],
    );
  }
}

class _AdminAircraftScreen extends StatelessWidget {
  const _AdminAircraftScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Aeronaves',
      subtitle: 'Control administrativo de flota activa y en revision.',
      roleLabel: 'Administrador',
      heroTitle: 'Supervisa aeronaves antes de liberarlas al marketplace',
      heroSubtitle:
          'Revisa modelo, matricula, capacidad, documentos, fotos, disponibilidad y estado comercial.',
      metrics: [
        MarketplaceMetric(
          label: 'Activas',
          value: '126',
          helper: 'Aeronaves visibles en resultados.',
        ),
        MarketplaceMetric(
          label: 'En revision',
          value: '14',
          helper: 'Esperan aprobacion documental.',
        ),
        MarketplaceMetric(
          label: 'Bloqueadas',
          value: '6',
          helper: 'Fuera de inventario comercial.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.check_circle_rounded,
          label: 'Liberar',
          message: 'Aeronave liberada de forma estatica.',
        ),
        StaticAction(
          icon: Icons.lock_rounded,
          label: 'Bloquear',
          message: 'Aeronave bloqueada de forma estatica.',
        ),
        StaticAction(
          icon: Icons.visibility_rounded,
          label: 'Ver ficha',
          message: 'Ficha ejecutiva preparada.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'Citation CJ3 | XA-SKY',
          subtitle: '7 pasajeros | proveedor Sky Operator',
          status: 'Activo',
          amount: '\$3,900/hr',
        ),
        StaticRecord(
          title: 'Challenger 604 | N604SG',
          subtitle: 'Documentos internacionales por revisar',
          status: 'Revision',
          amount: '\$7,900/hr',
        ),
        StaticRecord(
          title: 'King Air 350 | XB-KNG',
          subtitle: 'Mantenimiento programado',
          status: 'Bloqueado',
          amount: '\$2,100/hr',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Ficha',
          description: 'Modelo, matricula, pasajeros, autonomia y base.',
        ),
        MarketplaceModule(
          title: 'Documentos',
          description: 'Seguros, certificados, permisos y fechas de vigencia.',
        ),
        MarketplaceModule(
          title: 'Liberacion comercial',
          description: 'Control para aparecer o no en resultados.',
        ),
      ],
    );
  }
}

class _AdminRequestsScreen extends StatelessWidget {
  const _AdminRequestsScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Solicitudes',
      subtitle: 'Todas las solicitudes del sistema con filtros operativos.',
      roleLabel: 'Administrador',
      heroTitle: 'Monitorea solicitudes de punta a punta',
      heroSubtitle:
          'Filtra por estatus, ruta, proveedor, cliente, fecha y prioridad comercial.',
      metrics: [
        MarketplaceMetric(
          label: 'Nuevas',
          value: '23',
          helper: 'Sin primera respuesta.',
        ),
        MarketplaceMetric(
          label: 'En cotizacion',
          value: '41',
          helper: 'Proveedores respondiendo.',
        ),
        MarketplaceMetric(
          label: 'Criticas',
          value: '5',
          helper: 'Salidas de ultima hora.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.filter_alt_rounded,
          label: 'Filtrar',
          message: 'Filtros avanzados preparados.',
        ),
        StaticAction(
          icon: Icons.person_search_rounded,
          label: 'Asignar proveedor',
          message: 'Asignacion preparada.',
        ),
        StaticAction(
          icon: Icons.flag_rounded,
          label: 'Marcar critica',
          message: 'Solicitud marcada como critica.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'TLC -> CUN',
          subtitle: 'Cliente corporativo | 6 pasajeros',
          status: 'En cotizacion',
          amount: '\$18,900',
        ),
        StaticRecord(
          title: 'GDL -> IAH',
          subtitle: 'Internacional | requiere permisos',
          status: 'Critica',
          amount: '\$34,700',
        ),
        StaticRecord(
          title: 'MTY -> SJD',
          subtitle: 'Proveedor sugerido: Executive Wings',
          status: 'Pendiente',
          amount: '\$21,400',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Filtros avanzados',
          description: 'Estatus, ruta, proveedor, cliente y fecha.',
        ),
        MarketplaceModule(
          title: 'Detalle completo',
          description: 'Historial, mensajes, ofertas y actividad.',
        ),
        MarketplaceModule(
          title: 'Intervencion admin',
          description: 'Asignar proveedor, escalar o cerrar caso.',
        ),
      ],
    );
  }
}

class _AdminQuotesScreen extends StatelessWidget {
  const _AdminQuotesScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Cotizaciones',
      subtitle: 'Seguimiento comercial de propuestas enviadas y aceptadas.',
      roleLabel: 'Administrador',
      heroTitle: 'Controla conversion de cotizacion a venta',
      heroSubtitle:
          'Visualiza cotizaciones enviadas, aceptadas, rechazadas, vencidas y en negociacion.',
      metrics: [
        MarketplaceMetric(
          label: 'Enviadas',
          value: '86',
          helper: 'Propuestas activas del mes.',
        ),
        MarketplaceMetric(
          label: 'Aceptadas',
          value: '31',
          helper: 'Conversion comercial actual.',
        ),
        MarketplaceMetric(
          label: 'Vencidas',
          value: '12',
          helper: 'Requieren seguimiento.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.send_rounded,
          label: 'Enviar recordatorio',
          message: 'Recordatorio preparado.',
        ),
        StaticAction(
          icon: Icons.edit_note_rounded,
          label: 'Editar',
          message: 'Edicion de cotizacion preparada.',
        ),
        StaticAction(
          icon: Icons.done_all_rounded,
          label: 'Marcar aceptada',
          message: 'Cotizacion aceptada de forma estatica.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'COT-1048 | TLC -> CUN',
          subtitle: 'Cliente Premium | Citation CJ3',
          status: 'Aceptada',
          amount: '\$18,900',
        ),
        StaticRecord(
          title: 'COT-1051 | MTY -> SJD',
          subtitle: 'Esperando respuesta del cliente',
          status: 'Pendiente',
          amount: '\$21,400',
        ),
        StaticRecord(
          title: 'COT-1054 | GDL -> IAH',
          subtitle: 'Vigencia vencida, requiere actualizar',
          status: 'Vencida',
          amount: '\$34,700',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Seguimiento',
          description: 'Recordatorios, vencimientos y actividad comercial.',
        ),
        MarketplaceModule(
          title: 'Conversion',
          description: 'Medicion de cotizacion a reserva confirmada.',
        ),
        MarketplaceModule(
          title: 'Auditoria',
          description: 'Cambios de tarifa, notas y aprobaciones.',
        ),
      ],
    );
  }
}

class _AdminReportsScreen extends StatelessWidget {
  const _AdminReportsScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Reportes',
      subtitle: 'Analitica de rutas, flota, proveedores y ventas.',
      roleLabel: 'Administrador',
      heroTitle: 'KPIs ejecutivos para tomar decisiones',
      heroSubtitle:
          'Reportes de rutas mas solicitadas, aeronaves usadas, horas voladas, proveedores activos y conversion.',
      metrics: [
        MarketplaceMetric(
          label: 'Ruta top',
          value: 'TLC-CUN',
          helper: 'Mayor demanda del mes.',
        ),
        MarketplaceMetric(
          label: 'Horas voladas',
          value: '412',
          helper: 'Horas estimadas confirmadas.',
        ),
        MarketplaceMetric(
          label: 'Conversion',
          value: '36%',
          helper: 'Cotizacion a venta.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.download_rounded,
          label: 'Exportar',
          message: 'Exportacion preparada.',
        ),
        StaticAction(
          icon: Icons.date_range_rounded,
          label: 'Cambiar periodo',
          message: 'Selector de periodo preparado.',
        ),
        StaticAction(
          icon: Icons.bar_chart_rounded,
          label: 'Ver grafica',
          message: 'Grafica ejecutiva preparada.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'Rutas mas solicitadas',
          subtitle: 'TLC-CUN, MTY-SJD, GDL-IAH',
          status: 'Activo',
          amount: '128',
        ),
        StaticRecord(
          title: 'Proveedor top',
          subtitle: 'Sky Operator | 18 vuelos confirmados',
          status: 'Activo',
          amount: '98%',
        ),
        StaticRecord(
          title: 'Ingresos marketplace',
          subtitle: 'Comisiones estimadas del mes',
          status: 'Confirmado',
          amount: '\$42k',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Demanda',
          description: 'Rutas, fechas, pasajeros y categorias mas buscadas.',
        ),
        MarketplaceModule(
          title: 'Oferta',
          description: 'Aeronaves usadas, disponibilidad y proveedores.',
        ),
        MarketplaceModule(
          title: 'Finanzas',
          description: 'Ingresos, comisiones, pagos, reembolsos y planes.',
        ),
      ],
    );
  }
}

class _AdminSettingsScreen extends StatelessWidget {
  const _AdminSettingsScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Configuracion',
      subtitle: 'Planes, demos, roles, permisos y mensajes del sistema.',
      roleLabel: 'Administrador',
      heroTitle: 'Configura reglas comerciales de la plataforma',
      heroSubtitle:
          'Administra demo de 15 dias, planes, precios, permisos, banners y mensajes de conversion.',
      metrics: [
        MarketplaceMetric(
          label: 'Demos activas',
          value: '42',
          helper: 'Cuentas en periodo gratuito.',
        ),
        MarketplaceMetric(
          label: 'Planes',
          value: '4',
          helper: 'Demo, Basico, Pro y Empresarial.',
        ),
        MarketplaceMetric(
          label: 'Roles',
          value: '3',
          helper: 'Cliente, proveedor y administrador.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.workspace_premium_rounded,
          label: 'Editar planes',
          message: 'Planes listos para editar.',
        ),
        StaticAction(
          icon: Icons.hourglass_top_rounded,
          label: 'Ver demos',
          message: 'Demos activas listas.',
        ),
        StaticAction(
          icon: Icons.campaign_rounded,
          label: 'Mensaje sistema',
          message: 'Mensaje del sistema preparado.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'Demo 15 dias',
          subtitle: 'Acceso limitado con conversion a plan',
          status: 'Activo',
          amount: '\$0',
        ),
        StaticRecord(
          title: 'Plan Pro',
          subtitle: 'Reservas, reportes y prioridad',
          status: 'Activo',
          amount: '\$249/mes',
        ),
        StaticRecord(
          title: 'Banner de upgrade',
          subtitle: 'Visible cuando faltan 3 dias',
          status: 'Activo',
          amount: '3 dias',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Planes',
          description: 'Precios, beneficios, permisos y CTA.',
        ),
        MarketplaceModule(
          title: 'Demos',
          description: 'Activacion, vencimiento, bloqueo y upgrade.',
        ),
        MarketplaceModule(
          title: 'Sistema',
          description:
              'Banners, mensajes, roles, permisos y parametros generales.',
        ),
      ],
    );
  }
}

class _ClientProfileScreen extends StatelessWidget {
  const _ClientProfileScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Perfil y configuracion',
      subtitle:
          'Preferencias de pasajero, datos fiscales, metodo de pago, seguridad y estado de membresia.',
      roleLabel: 'Cliente',
      heroTitle: 'Administra tu perfil premium',
      heroSubtitle:
          'Centraliza tus datos, preferencias de vuelo, metodos de pago, facturacion y estado de membresia.',
      metrics: [
        MarketplaceMetric(
          label: 'Membresia',
          value: 'Demo activa',
          helper: 'Estado visible para convertir a plan al final del periodo.',
        ),
        MarketplaceMetric(
          label: 'Preferencias',
          value: 'VIP',
          helper: 'Catering, transporte, WiFi, mascotas y seguridad.',
        ),
        MarketplaceMetric(
          label: 'Pagos',
          value: 'Pendiente',
          helper: 'Espacio listo para tarjetas, facturacion y pago.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.edit_rounded,
          label: 'Editar datos',
          message: 'Edicion de perfil preparada.',
        ),
        StaticAction(
          icon: Icons.credit_card_rounded,
          label: 'Metodo de pago',
          message: 'Metodo de pago listo para conectar.',
        ),
        StaticAction(
          icon: Icons.workspace_premium_rounded,
          label: 'Ver membresia',
          message: 'Estado de membresia demo activo.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'Datos personales',
          subtitle: 'Cliente premium | contacto principal',
          status: 'Activo',
          amount: 'Completo',
        ),
        StaticRecord(
          title: 'Facturacion',
          subtitle: 'Datos fiscales pendientes de validacion',
          status: 'Pendiente',
          amount: '80%',
        ),
        StaticRecord(
          title: 'Preferencias VIP',
          subtitle: 'WiFi, catering ligero, traslado FBO',
          status: 'Activo',
          amount: 'VIP',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Datos personales y empresa',
          description:
              'Informacion del cliente, contacto operativo y datos de facturacion.',
        ),
        MarketplaceModule(
          title: 'Preferencias de vuelo',
          description:
              'Pasajeros frecuentes, catering, equipaje, FBO y servicios especiales.',
        ),
        MarketplaceModule(
          title: 'Seguridad de cuenta',
          description:
              'Cambio de contrasena, notificaciones y preferencias de privacidad.',
        ),
      ],
    );
  }
}

class _ProviderCalendarScreen extends StatelessWidget {
  const _ProviderCalendarScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Calendario de disponibilidad',
      subtitle:
          'Bloqueo, liberacion y mantenimiento de aeronaves por fecha, hora y base operativa.',
      roleLabel: 'Proveedor',
      heroTitle: 'Controla disponibilidad por aeronave',
      heroSubtitle:
          'Bloquea horarios, libera inventario, marca mantenimiento y valida solicitudes antes de cotizar.',
      metrics: [
        MarketplaceMetric(
          label: 'Disponibles',
          value: '8',
          helper: 'Aeronaves listas para recibir solicitudes.',
        ),
        MarketplaceMetric(
          label: 'Bloqueadas',
          value: '3',
          helper: 'Mantenimiento, vuelos privados o ventanas no comerciales.',
        ),
        MarketplaceMetric(
          label: 'Respuesta',
          value: '12 min',
          helper: 'Tiempo estimado para confirmar disponibilidad.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.lock_clock_rounded,
          label: 'Bloquear horario',
          message: 'Horario bloqueado de forma estatica.',
        ),
        StaticAction(
          icon: Icons.event_available_rounded,
          label: 'Liberar avion',
          message: 'Aeronave liberada para solicitudes.',
        ),
        StaticAction(
          icon: Icons.build_rounded,
          label: 'Mantenimiento',
          message: 'Mantenimiento marcado en calendario.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'Citation CJ3',
          subtitle: 'Hoy 08:00 - 18:00 | Base TLC',
          status: 'Disponible',
          amount: '10 h',
        ),
        StaticRecord(
          title: 'Learjet 45',
          subtitle: 'Manana 09:00 - 13:00 | Vuelo privado',
          status: 'Bloqueado',
          amount: '4 h',
        ),
        StaticRecord(
          title: 'King Air 350',
          subtitle: 'Mantenimiento preventivo | 2 dias',
          status: 'Revision',
          amount: '48 h',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Vista calendario',
          description:
              'Agenda por aeronave, fecha, hora, aeropuerto base y estado operativo.',
        ),
        MarketplaceModule(
          title: 'Bloquear o liberar',
          description:
              'Acciones rapidas para pausar disponibilidad o abrir inventario al marketplace.',
        ),
        MarketplaceModule(
          title: 'Sincronizacion de solicitudes',
          description:
              'Las solicitudes recibidas deben validar disponibilidad antes de cotizar.',
        ),
      ],
    );
  }
}

class _AdminUsersScreen extends StatelessWidget {
  const _AdminUsersScreen();

  @override
  Widget build(BuildContext context) {
    return const StaticRoleScreen(
      title: 'Gestion de usuarios',
      subtitle:
          'Clientes, proveedores y administradores con permisos, estatus y actividad comercial.',
      roleLabel: 'Administrador',
      heroTitle: 'Gestiona usuarios, roles y accesos',
      heroSubtitle:
          'Controla clientes, proveedores, administradores, permisos, bloqueos, demos y actividad reciente.',
      metrics: [
        MarketplaceMetric(
          label: 'Clientes',
          value: '312',
          helper: 'Cuentas registradas en el marketplace.',
        ),
        MarketplaceMetric(
          label: 'Proveedores',
          value: '47',
          helper: 'Operadores con expediente y flota asociada.',
        ),
        MarketplaceMetric(
          label: 'Admins',
          value: '6',
          helper: 'Equipo interno con permisos de control.',
        ),
      ],
      actions: [
        StaticAction(
          icon: Icons.person_add_rounded,
          label: 'Crear usuario',
          message: 'Alta de usuario preparada.',
        ),
        StaticAction(
          icon: Icons.lock_open_rounded,
          label: 'Activar cuenta',
          message: 'Cuenta activada de forma estatica.',
        ),
        StaticAction(
          icon: Icons.block_rounded,
          label: 'Bloquear',
          message: 'Bloqueo de cuenta preparado.',
        ),
      ],
      records: [
        StaticRecord(
          title: 'Mariana Torres',
          subtitle: 'Cliente | demo activa | 12 dias restantes',
          status: 'Activo',
          amount: 'Cliente',
        ),
        StaticRecord(
          title: 'Sky Operator',
          subtitle: 'Proveedor | expediente aprobado',
          status: 'Aprobado',
          amount: 'Proveedor',
        ),
        StaticRecord(
          title: 'Admin Operaciones',
          subtitle: 'Permisos de soporte y vuelos',
          status: 'Activo',
          amount: 'Admin',
        ),
      ],
      modules: [
        MarketplaceModule(
          title: 'Gestion de clientes',
          description:
              'Alta, busqueda, bloqueo, membresia, historial y actividad reciente.',
        ),
        MarketplaceModule(
          title: 'Gestion de proveedores',
          description:
              'Aprobacion, perfil empresarial, documentos, comisiones y estado operativo.',
        ),
        MarketplaceModule(
          title: 'Permisos administrativos',
          description:
              'Roles internos para soporte, finanzas, operaciones y administracion general.',
        ),
      ],
    );
  }
}
