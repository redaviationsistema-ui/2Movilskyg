class ReplayGuard {
  String _lastKey = '';

  bool accept(String key) {
    final normalized = key.trim();
    if (normalized.isEmpty || normalized == _lastKey) return false;
    _lastKey = normalized;
    return true;
  }
}
