import '../../../models/client_operation_tracking.dart';

// Presentation only: internal operation/event values are never rewritten.
String trackingStateLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'operational_ready':
    case 'ready':
    case 'lista':
    case 'listo':
      return 'Listo para operar';
    case 'tracking_live':
    case 'tracking en vivo':
      return 'Seguimiento operativo activo';
    case 'in_flight':
    case 'airborne':
      return 'En vuelo';
    case 'en_vuelo':
    case 'en vuelo':
      return 'Estado de vuelo reportado';
    case 'confirmed':
    case 'confirmada':
    case 'confirmado':
    case 'flight_confirmed':
      return 'Confirmado';
    case 'aircraft_confirmed':
      return 'Aeronave confirmada';
    case 'crew_confirmed':
      return 'Tripulación confirmada';
    case 'preparation':
    case 'preparacion':
    case 'en_preparacion':
    case 'preparing':
      return 'En preparación';
    case 'completed':
    case 'complete':
    case 'done':
    case 'finalizada':
    case 'finalizado':
    case 'landed':
      return 'Finalizado';
    case 'cancelled':
    case 'canceled':
    case 'cancelada':
    case 'cancelado':
    case 'rejected':
      return 'Cancelado';
    case 'pending':
    case 'pendiente':
    case 'pending_confirmation':
      return 'Pendiente';
    case 'active':
    case 'in_progress':
      return 'En proceso';
    case 'incidencia':
      return 'Incidencia reportada';
    default:
      return 'Estado por confirmar';
  }
}

bool isProviderRelease(ClientOperationTimelineEvent event) =>
    event.title.toLowerCase().contains('liberacion operativa') ||
    event.title.toLowerCase().contains('liberación operativa');

String? _descriptionField(ClientOperationTimelineEvent event, String field) {
  for (final part in event.description.split('|')) {
    final colon = part.indexOf(':');
    if (colon >= 0 && part.substring(0, colon).trim().toLowerCase() == field) {
      return part.substring(colon + 1).trim().toLowerCase();
    }
  }
  return null;
}

String trackingEventLabel(ClientOperationTimelineEvent event) {
  // Provider release writes normalize tracking_live to en_vuelo. This event
  // records release/workflow activity, not independent evidence of takeoff.
  if (isProviderRelease(event)) {
    final release = _descriptionField(event, 'estado');
    if (release != null) return trackingStateLabel(release);
  }
  if (const [
    'completed',
    'complete',
    'done',
  ].contains(event.status.trim().toLowerCase())) {
    return 'Completado';
  }
  return trackingStateLabel(event.status);
}

String trackingEventDescription(ClientOperationTimelineEvent event) {
  final description = event.description.trim();
  if (description == event.title.trim()) return '';
  return description
      .split('|')
      .map((part) {
        final text = part.trim();
        final colon = text.indexOf(':');
        if (colon < 0) return _translateTokens(text);
        final label = text.substring(0, colon).trim();
        final value = text.substring(colon + 1).trim();
        if (label.toLowerCase() == 'estado') {
          return 'Estado de la actualización: ${trackingStateLabel(value)}';
        }
        if (label.toLowerCase() == 'workflow') {
          return 'Seguimiento: ${trackingStateLabel(value)}';
        }
        return '$label: ${_translateTokens(value)}';
      })
      .where((part) => part.isNotEmpty)
      .join(' · ');
}

String _translateTokens(String text) => text.replaceAllMapped(
  RegExp(r'\b[a-z]+(?:_[a-z]+)+\b'),
  (match) => trackingStateLabel(match[0]!),
);

List<ClientOperationTimelineEvent> trackingVisibleEvents(
  ClientOperationTracking tracking,
) {
  final seen = <(String, String)>{};
  final indexed = <(int, ClientOperationTimelineEvent)>[];
  for (var index = 0; index < tracking.timeline.length; index++) {
    final event = tracking.timeline[index];
    if (event.operationId.isNotEmpty &&
        event.operationId != tracking.operationId) {
      continue;
    }
    // Without a stable ID, equal display text is insufficient to deduplicate.
    if (event.id.isNotEmpty) {
      final signature =
          event.sourceSignature ??
          '${event.operationId}\u0000${event.status}\u0000${event.title}\u0000${event.description}\u0000${event.createdAt?.toIso8601String()}';
      if (!seen.add((event.id, signature))) continue;
    }
    indexed.add((index, event));
  }
  indexed.sort((a, b) {
    final first = a.$2.createdAt;
    final second = b.$2.createdAt;
    if (first == null || second == null) {
      if (first == null && second != null) return 1;
      if (first != null && second == null) return -1;
      return a.$1.compareTo(b.$1);
    }
    final comparison = second.compareTo(first);
    return comparison == 0 ? a.$1.compareTo(b.$1) : comparison;
  });
  return List.unmodifiable(indexed.map((item) => item.$2));
}

class TrackingStatusPresentation {
  const TrackingStatusPresentation(
    this.title,
    this.description, {
    this.terminal = false,
  });
  final String title;
  final String description;
  final bool terminal;

  factory TrackingStatusPresentation.fromValue(String value) {
    final label = trackingStateLabel(value);
    switch (label) {
      case 'Cancelado':
        return const TrackingStatusPresentation(
          'Vuelo cancelado',
          'La operación fue cancelada. Nuestro equipo está disponible si necesitas ayuda.',
          terminal: true,
        );
      case 'Finalizado':
        return const TrackingStatusPresentation(
          'Vuelo finalizado',
          'El servicio ha finalizado.',
          terminal: true,
        );
      case 'En vuelo':
        return const TrackingStatusPresentation(
          'Tu vuelo está en curso',
          'El sistema reporta un vuelo en curso. Este seguimiento muestra eventos operativos.',
        );
      case 'Estado de vuelo reportado':
      case 'Seguimiento operativo activo':
        return const TrackingStatusPresentation(
          'Seguimiento operativo activo',
          'Consulta las actualizaciones de tu operación. Este estado no confirma un despegue.',
        );
      case 'Listo para operar':
        return const TrackingStatusPresentation(
          'Listo para operar',
          'La operación registra un estado de preparación para operar; la salida aún no está confirmada.',
        );
      case 'Confirmado':
        return const TrackingStatusPresentation(
          'Operación confirmada',
          'La operación cuenta con una confirmación registrada.',
        );
      case 'En preparación':
        return const TrackingStatusPresentation(
          'Estamos preparando tu vuelo',
          'El equipo continúa con la preparación operacional.',
        );
      case 'Pendiente':
        return const TrackingStatusPresentation(
          'Operación pendiente',
          'La confirmación de la operación está pendiente.',
        );
      default:
        return const TrackingStatusPresentation(
          'Estado operativo por confirmar',
          'Mostramos la información disponible de esta operación.',
        );
    }
  }

  factory TrackingStatusPresentation.fromTracking(
    ClientOperationTracking tracking, {
    List<ClientOperationTimelineEvent>? visibleEvents,
  }) {
    final base = TrackingStatusPresentation.fromValue(tracking.status);
    if (base.terminal || trackingStateLabel(tracking.status) == 'En vuelo') {
      return base;
    }
    final events = visibleEvents ?? trackingVisibleEvents(tracking);
    if (const [
          'Estado de vuelo reportado',
          'Seguimiento operativo activo',
          'Confirmado',
          'Listo para operar',
        ].contains(trackingStateLabel(tracking.status)) &&
        events.isNotEmpty &&
        isProviderRelease(events.first) &&
        _descriptionField(events.first, 'estado') == 'operational_ready') {
      return const TrackingStatusPresentation(
        'Listo para operar',
        'La aeronave cuenta con una liberación operativa confirmada. Esta liberación no confirma el despegue.',
      );
    }
    // en_vuelo can also be produced by the release workflow. Only an
    // independent flight event can corroborate that ambiguous operation value.
    if (trackingStateLabel(tracking.status) == 'Estado de vuelo reportado' &&
        events.isNotEmpty &&
        !isProviderRelease(events.first) &&
        const [
          'in_flight',
          'en_vuelo',
          'airborne',
        ].contains(events.first.status.toLowerCase())) {
      return TrackingStatusPresentation.fromValue('in_flight');
    }
    return base;
  }

  String get nextDescription =>
      terminal
          ? title == 'Vuelo cancelado'
              ? 'La operación está cancelada. Contacta a nuestro equipo si necesitas asistencia.'
              : 'La operación finalizó. Puedes consultar las actualizaciones registradas.'
          : 'Nuestro equipo compartirá la próxima actualización cuando esté disponible.';
}

String trackingEventTitle(ClientOperationTimelineEvent event) =>
    event.title.trim().isEmpty
        ? 'Actualización operativa'
        : _translateTokens(event.title.trim());

String trackingReleaseAircraftLabel(List<ClientOperationTimelineEvent> events) {
  for (final event in events) {
    if (!isProviderRelease(event)) continue;
    for (final part in event.description.split('|')) {
      final colon = part.indexOf(':');
      if (colon >= 0 &&
          part.substring(0, colon).trim().toLowerCase() == 'aeronave') {
        final label = part.substring(colon + 1).trim();
        if (label.isNotEmpty) return label;
      }
    }
  }
  return '';
}
