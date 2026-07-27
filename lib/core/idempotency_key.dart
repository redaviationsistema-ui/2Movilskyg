class IdempotencyKey {
  const IdempotencyKey._();

  static String forOperation(String operation, String entityId) {
    final normalizedOperation = _normalize(operation);
    final normalizedEntity = entityId.trim().toLowerCase();
    if (normalizedOperation.isEmpty || normalizedEntity.isEmpty) {
      throw ArgumentError('operation y entityId son obligatorios.');
    }

    // FNV-1a de 64 bits: estable entre procesos y plataformas. La clave no
    // contiene datos personales ni depende de hashCode de Dart.
    var hash = 0xcbf29ce484222325;
    for (final byte in '$normalizedOperation:$normalizedEntity'.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return 'mobile-$normalizedOperation-${hash.toRadixString(16).padLeft(16, '0')}';
  }

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
