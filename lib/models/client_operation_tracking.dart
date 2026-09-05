import 'package:flutter/material.dart';

class ClientOperationTracking {
  const ClientOperationTracking({
    required this.operationId,
    required this.status,
    required this.timeline,
  });

  final String operationId;
  final String status;
  final List<ClientOperationTimelineEvent> timeline;

  factory ClientOperationTracking.fromJson(Map<String, dynamic> json) {
    final operation = _map(json['operation']);
    final timeline =
        operation['timeline'] is List
            ? (operation['timeline'] as List)
                .whereType<Map>()
                .map(
                  (item) => ClientOperationTimelineEvent.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
            : const <ClientOperationTimelineEvent>[];

    return ClientOperationTracking(
      operationId: _text(operation['id']),
      status: _text(operation['status']),
      timeline: List.unmodifiable(timeline),
    );
  }
}

class ClientOperationTimelineEvent {
  const ClientOperationTimelineEvent({
    required this.status,
    required this.title,
    required this.description,
    this.createdAt,
  });

  final String status;
  final String title;
  final String description;
  final DateTime? createdAt;

  factory ClientOperationTimelineEvent.fromJson(Map<String, dynamic> json) =>
      ClientOperationTimelineEvent(
        status: _text(json['status']),
        title: _text(json['title']),
        description: _text(json['description']),
        createdAt: DateTime.tryParse(_text(json['created_at'])),
      );
}

class ClientTrackingEventState {
  const ClientTrackingEventState(this.label, this.color, this.background);

  final String label;
  final Color color;
  final Color background;

  factory ClientTrackingEventState.fromValue(String value) {
    final status = value.toLowerCase();
    if (_hasStatus(status, const [
      'completed',
      'complete',
      'finaliz',
      'landed',
      'done',
    ])) {
      return const ClientTrackingEventState(
        'Completado',
        Color(0xFF42E0B5),
        Color(0x1F2BD4A5),
      );
    }
    if (_hasStatus(status, const [
      'active',
      'progress',
      'ready',
      'operational_ready',
      'in_flight',
      'tracking_live',
    ])) {
      return const ClientTrackingEventState(
        'En proceso',
        Color(0xFFFFD56A),
        Color(0x1FE2B653),
      );
    }
    return const ClientTrackingEventState(
      'Pendiente',
      Color(0xFFA9C0CF),
      Color(0x1F66889D),
    );
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

String _text(Object? value) => value?.toString().trim() ?? '';

bool _hasStatus(String value, List<String> candidates) =>
    candidates.any(value.contains);
