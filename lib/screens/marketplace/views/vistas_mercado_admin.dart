// Nota: este archivo agrupa las vistas estaticas del marketplace para
// administracion y evita concentrar multiples secciones en una sola pantalla.
import 'package:flutter/material.dart';

import '../../../models/modelos_mercado.dart';
import '../../shared/pantalla_rol_estatico.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

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

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

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

class AdminProvidersScreen extends StatelessWidget {
  const AdminProvidersScreen({super.key});

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

class AdminAircraftScreen extends StatelessWidget {
  const AdminAircraftScreen({super.key});

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

class AdminRequestsScreen extends StatelessWidget {
  const AdminRequestsScreen({super.key});

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

class AdminQuotesScreen extends StatelessWidget {
  const AdminQuotesScreen({super.key});

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

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

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

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

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
