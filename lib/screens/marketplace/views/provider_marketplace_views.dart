// Nota: este archivo agrupa las vistas del marketplace para proveedores y
// mantiene el flujo por rol desacoplado del coordinador principal.
import 'package:flutter/material.dart';

import '../../../models/marketplace_models.dart';
import '../../shared/static_role_screen.dart';

class ProviderHomeScreen extends StatelessWidget {
  const ProviderHomeScreen({super.key});

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

class ProviderAircraftScreen extends StatelessWidget {
  const ProviderAircraftScreen({super.key});

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

class ProviderRequestsScreen extends StatelessWidget {
  const ProviderRequestsScreen({super.key});

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

class ProviderOperationsScreen extends StatelessWidget {
  const ProviderOperationsScreen({super.key});

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

class ProviderProfileScreen extends StatelessWidget {
  const ProviderProfileScreen({super.key});

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

class ProviderCalendarScreen extends StatelessWidget {
  const ProviderCalendarScreen({super.key});

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
