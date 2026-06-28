import 'cliente_api.dart';

String resolveMediaUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty || raw.toLowerCase() == 'null') return '';

  final lower = raw.toLowerCase();
  if (lower.startsWith('data:')) return raw;
  if (lower.startsWith('blob:')) return '';
  if (raw.startsWith('//')) return _normalizeNetworkUrl('https:$raw');
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return _normalizeNetworkUrl(raw);
  }

  final origin = ApiClient.instance.backendOrigin;
  if (origin.isEmpty) return raw.startsWith('/') ? raw : '/$raw';

  final cleanPath =
      raw.startsWith('/') ? raw : '/${raw.replaceFirst(RegExp(r'^\./'), '')}';
  return _normalizeNetworkUrl('$origin$cleanPath');
}

String _normalizeNetworkUrl(String value) {
  final parsed = Uri.tryParse(value.trim());
  if (parsed == null || parsed.scheme.isEmpty || parsed.host.isEmpty) {
    return value.trim();
  }
  return parsed.replace(pathSegments: parsed.pathSegments).toString();
}
