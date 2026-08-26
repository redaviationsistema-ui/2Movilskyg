// ignore_for_file: unused_element

part of 'pantalla_espacio_sobrecargo.dart';

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.item});

  final CrewAssignment item;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;

    return _AnimatedEntry(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(compact ? 14 : 16),
        decoration: _panelDecoration().copyWith(
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFF8FBFD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 38 : 42,
                  height: compact ? 38 : 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.flight_takeoff_rounded,
                    color: Color(0xFF0E2338),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 16 : 18,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0E2338),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.showTime,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF5F6975),
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(item.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.route,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF15293A),
                fontSize: compact ? 15 : 16,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${item.provider} | ${item.aircraft}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF5F6975),
                height: 1.3,
                fontSize: compact ? 13 : 14,
              ),
            ),
            if (item.rejectReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Motivo: ${item.rejectReason}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF8D1F1A),
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: metrics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.45,
            ),
            itemBuilder:
                (context, index) =>
                    _MetricGridCard(item: metrics[index], delay: index * 70),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: constraints.maxWidth < 430 ? 200 : 220,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: constraints.maxWidth < 430 ? 1.0 : 1.45,
          ),
          itemBuilder:
              (context, index) =>
                  _MetricGridCard(item: metrics[index], delay: index * 70),
        );
      },
    );
  }
}

class _MetricGridCard extends StatelessWidget {
  const _MetricGridCard({required this.item, required this.delay});

  final _Metric item;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;

    return _AnimatedEntry(
      delay: delay,
      child: Container(
        padding: EdgeInsets.all(compact ? 10 : 14),
        decoration: _panelDecoration().copyWith(
          gradient: const LinearGradient(
            colors: [CrewColors.navy, CrewColors.navySecondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0x40E9BB58)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, color: CrewColors.gold),
            SizedBox(height: compact ? 10 : 18),
            Text(
              item.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 15 : 22,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFC9D7E2),
                fontSize: compact ? 11 : 14,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.button,
    required this.onPressed,
    this.titleColor = const Color(0xFF0E2338),
    this.titleFontSize,
    this.titleFontWeight = FontWeight.w900,
    this.subtitleStyle,
    this.buttonHeight = 52,
    this.buttonRadius = 12,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String button;
  final VoidCallback? onPressed;
  final Color titleColor;
  final double? titleFontSize;
  final FontWeight titleFontWeight;
  final TextStyle? subtitleStyle;
  final double buttonHeight;
  final double buttonRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return _AnimatedEntry(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final buttonWidget = FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: CrewColors.navy,
              foregroundColor: Colors.white,
              minimumSize: Size.fromHeight(buttonHeight),
              maximumSize: const Size(double.infinity, double.infinity),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(buttonRadius),
              ),
            ),
            child: Text(
              button,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          );

          return Container(
            padding: padding,
            decoration: _panelDecoration(),
            child:
                compact
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7DF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(icon, color: CrewColors.warning),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize:
                                          titleFontSize ?? (compact ? 18 : 20),
                                      fontWeight: titleFontWeight,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    maxLines: compact ? 3 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        subtitleStyle ??
                                        TextStyle(
                                          color: CrewColors.textSecondary,
                                          fontSize: compact ? 13 : 14,
                                          height: 1.3,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(width: double.infinity, child: buttonWidget),
                      ],
                    )
                    : Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7DF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: CrewColors.warning),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: titleFontSize ?? 18,
                                  fontWeight: titleFontWeight,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    subtitleStyle ??
                                    const TextStyle(
                                      color: CrewColors.textSecondary,
                                      fontSize: 14,
                                      height: 1.3,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        buttonWidget,
                      ],
                    ),
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.titleColor,
    this.subtitleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final Color? titleColor;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;

    return _AnimatedEntry(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(compact ? 14 : 16),
        decoration: _panelDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: compact ? 36 : 40,
              height: compact ? 36 : 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7DF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: CrewColors.gold),
            ),
            SizedBox(width: compact ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor ?? const Color(0xFFFF3B30),
                      fontSize: compact ? 14 : 17,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: compact ? 4 : 6),
                  Text(
                    subtitle,
                    maxLines: compact ? 4 : 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subtitleColor ?? const Color(0xFF5F6975),
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  if (action != null) ...[const SizedBox(height: 12), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.isLoading});

  final String message;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 430;
    final normalized = message.toLowerCase();
    final isError =
        normalized.contains('no se pudo') ||
        normalized.contains('completa') ||
        normalized.contains('selecciona') ||
        normalized.contains('agrega');
    final isSuccess =
        normalized.contains('sincronizado') ||
        normalized.contains('actualizada') ||
        normalized.contains('enviado') ||
        normalized.contains('guardado');
    final background =
        isError
            ? const [Color(0xFFFFF1F0), Colors.white]
            : isSuccess
            ? const [Color(0xFFEAF6F0), Colors.white]
            : const [Color(0xFFFFF8E7), Colors.white];
    final border =
        isError
            ? const Color(0xFFF0A29D)
            : isSuccess
            ? const Color(0xFF82C9A3)
            : const Color(0xFFEBD39B);
    final foreground =
        isError
            ? const Color(0xFF8D1F1A)
            : isSuccess
            ? const Color(0xFF0F5C38)
            : const Color(0xFF7A5A18);
    final icon =
        isError
            ? Icons.error_outline_rounded
            : isSuccess
            ? Icons.check_circle_rounded
            : Icons.radar_rounded;

    return _AnimatedEntry(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical: compact ? 12 : 13,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: background,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(compact ? 16 : 18),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child:
                  isLoading
                      ? SizedBox(
                        key: const ValueKey('loading'),
                        width: compact ? 16 : 18,
                        height: compact ? 16 : 18,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Icon(
                        icon,
                        key: const ValueKey('ready'),
                        color: foreground,
                        size: compact ? 18 : 20,
                      ),
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: Text(
                message.trim().replaceAll(RegExp(r'\.+$'), ''),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.text, {this.textColor});

  final String text;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor ?? colors.$2,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  (Color, Color) _statusColors(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('rechaz')) {
      return (const Color(0xFFFFF1F0), const Color(0xFF8D1F1A));
    }
    if (normalized.contains('pend')) {
      return (const Color(0xFFFFF8E7), const Color(0xFF7A5A18));
    }
    if (normalized.contains('final')) {
      return (const Color(0xFFEAF2F8), const Color(0xFF173B55));
    }
    return (const Color(0xFFEAF6F0), const Color(0xFF0F5C38));
  }
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.label,
    required this.initial,
  });

  final String title;
  final String label;
  final String initial;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String label,
    required String initial,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(title: title, label: label, initial: initial),
    );
  }

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: CrewColors.card,
    borderRadius: CrewUi.cardRadius,
    border: Border.all(color: CrewColors.line),
    boxShadow: CrewUi.cardShadow,
  );
}

class _AnimatedEntry extends StatelessWidget {
  const _AnimatedEntry({required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
