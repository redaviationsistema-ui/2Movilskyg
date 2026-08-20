part of 'pantalla_espacio_sobrecargo.dart';

class CrewNotificationsView extends StatefulWidget {
  const CrewNotificationsView({super.key, this.api});

  final ApiClient? api;

  @override
  State<CrewNotificationsView> createState() => _CrewNotificationsViewState();
}

class _CrewNotificationsViewState extends State<CrewNotificationsView> {
  ApiClient get _api => widget.api ?? ApiClient.instance;
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String _error = '';
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final response = await _api.get(
        '/notifications',
        authenticated: true,
        query: const {'per_page': '50'},
      );
      final source =
          response['data'] is Map
              ? Map<String, dynamic>.from(response['data'])
              : response;
      final page = source['notifications'];
      final raw = page is Map ? page['data'] : page;
      final items =
          raw is List
              ? raw
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
              : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _items = items;
        _unread =
            int.tryParse('${source['unread_count'] ?? 0}') ??
            items.where((item) => item['read_at'] == null).length;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['read_at'] != null) return;
    try {
      final response = await _api.patch(
        '/notifications/${item['id']}/read',
        authenticated: true,
      );
      final notification =
          response['notification'] is Map
              ? Map<String, dynamic>.from(response['notification'])
              : const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        item['read_at'] =
            notification['read_at'] ?? DateTime.now().toIso8601String();
        _unread = (_unread - 1).clamp(0, 1 << 30);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _markAll() async {
    try {
      await _api.patch('/notifications/read-all', authenticated: true);
      if (!mounted) return;
      final now = DateTime.now().toIso8601String();
      setState(() {
        for (final item in _items) {
          item['read_at'] ??= now;
        }
        _unread = 0;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _openNotification(Map<String, dynamic> item) async {
    await _markRead(item);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('${item['title'] ?? 'Notificación'}'),
            content: Text('${item['message'] ?? ''}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error.isNotEmpty) {
      return Column(
        children: [
          _InfoTile(
            icon: Icons.cloud_off_rounded,
            title: 'No se pudieron cargar las notificaciones',
            subtitle: _error,
          ),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$_unread sin leer',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            TextButton(
              onPressed: _unread == 0 ? null : _markAll,
              child: const Text('Marcar todas'),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              tooltip: 'Refrescar',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          const _InfoTile(
            icon: Icons.notifications_none_rounded,
            title: 'Sin notificaciones',
            subtitle: 'Los avisos operativos aparecerán aquí.',
          )
        else
          ..._items.map((item) {
            final payload =
                item['payload'] is Map
                    ? Map<String, dynamic>.from(item['payload'])
                    : const <String, dynamic>{};
            final unread = item['read_at'] == null;
            return Card(
              color: unread ? const Color(0xFFFFF8E8) : Colors.white,
              child: ListTile(
                onTap: () => _openNotification(item),
                leading: Icon(
                  unread
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: unread ? const Color(0xFFB7791F) : Colors.grey,
                ),
                title: Text(
                  '${item['title'] ?? 'Notificación'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${item['message'] ?? ''}${payload['level'] == null ? '' : '\nNivel: ${payload['level']}'}',
                ),
                trailing:
                    unread
                        ? const Icon(
                          Icons.circle,
                          size: 10,
                          color: Color(0xFFEF4444),
                        )
                        : null,
              ),
            );
          }),
      ],
    );
  }
}
