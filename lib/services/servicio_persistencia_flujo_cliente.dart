import 'dart:convert';

import 'servicio_memoria_local.dart';

class ClientFlowPersistenceService {
  ClientFlowPersistenceService({LocalCacheService? cache})
    : _cache = cache ?? LocalCacheService();

  static const _contextKey = 'client_flow_context_v1';
  final LocalCacheService _cache;

  Future<void> save(Map<String, dynamic> context) =>
      _cache.setMetadata(_contextKey, jsonEncode(context));

  Future<Map<String, dynamic>> load() async {
    final raw = await _cache.getMetadata(_contextKey);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> clear() => _cache.deleteMetadata(_contextKey);
}
