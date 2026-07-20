typedef SessionCleanup = Future<void> Function();

class SessionCleanupRegistry {
  SessionCleanupRegistry._();

  static final Set<SessionCleanup> _callbacks = {};

  static void register(SessionCleanup callback) => _callbacks.add(callback);
  static void unregister(SessionCleanup callback) =>
      _callbacks.remove(callback);

  static Future<void> clearAll() async {
    for (final callback in List<SessionCleanup>.from(_callbacks)) {
      await callback();
    }
  }
}
