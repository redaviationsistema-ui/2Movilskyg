// Nota: este archivo contiene las vistas del marketplace orientadas al cliente
// para distribuir la experiencia por rol y reducir el tamano del coordinador.
import 'package:flutter/material.dart';

import '../../../models/modelos_mercado.dart';
import '../../shared/pantalla_rol_estatico.dart';

class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

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

class ClientQuotesScreen extends StatelessWidget {
  const ClientQuotesScreen({super.key});

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

class ClientTripsScreen extends StatelessWidget {
  const ClientTripsScreen({super.key});

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

class ClientProfileScreen extends StatelessWidget {
  const ClientProfileScreen({super.key});

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
