import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../providers/proveedor_autenticacion.dart';
import 'pantalla_seleccion_registro.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  static final RegExp _emailRegex = RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );

  late final AnimationController _routeController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _routeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void dispose() {
    _routeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _showAlert('Revisa correo y contrasena para entrar.');
      return;
    }

    await context.read<AuthProvider>().signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  void _showAlert(String message) {
    final colors = context.appColors;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          backgroundColor: colors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: colors.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isDark = context.isDarkMode;
    final isBusy = auth.isLoading;

    final backgroundGradient =
        isDark
            ? [
              colors.background,
              Color.lerp(colors.background, colors.primary, 0.55) ??
                  colors.primary,
              Color.lerp(colors.primary, const Color(0xFF1A4662), 0.42) ??
                  colors.primary,
            ]
            : [
              Color.lerp(colors.background, Colors.white, 0.30) ??
                  colors.background,
              Color.lerp(colors.background, const Color(0xFFE5EDF4), 0.84) ??
                  colors.background,
              Color.lerp(colors.primary, Colors.white, 0.86) ?? colors.primary,
            ];
    final panelColor =
        Color.lerp(
          colors.surfaceCard,
          colors.background,
          isDark ? 0.08 : 0.22,
        ) ??
        colors.surfaceCard;
    final logoGradient =
        isDark
            ? [
              Color.lerp(colors.surfaceCard, Colors.white, 0.04) ??
                  colors.surfaceCard,
              Color.lerp(colors.primary, colors.surfaceCard, 0.35) ??
                  colors.primary,
            ]
            : [
              Colors.white,
              Color.lerp(colors.surfaceCard, colors.background, 0.55) ??
                  colors.surfaceCard,
            ];

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: backgroundGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _routeController,
                builder:
                    (context, _) => CustomPaint(
                      painter: _LoginRoutePainter(
                        progress: _routeController.value,
                        primary: colors.primary,
                        accent: colors.secondary,
                        isDark: isDark,
                      ),
                    ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LoginHeroIntro(
                          colors: colors,
                          logoGradient: logoGradient,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _LoginSignalLine(colors: colors, isBusy: isBusy),
                        const SizedBox(height: 20),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                          decoration: BoxDecoration(
                            color: panelColor.withValues(
                              alpha: isDark ? 0.94 : 0.98,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color:
                                  isDark
                                      ? colors.border
                                      : colors.primary.withValues(alpha: 0.10),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.32 : 0.12,
                                ),
                                blurRadius: 34,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Entrar a mi cabina',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Tu busqueda, reservas y perfil operativo en un solo lugar.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _SecureAccessNotice(colors: colors),
                                const SizedBox(height: 22),
                                const _FieldLabel(text: 'Correo electronico'),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.username],
                                  decoration: _inputDecoration(
                                    hint: 'nombre@empresa.com',
                                    icon: Icons.alternate_email_rounded,
                                  ),
                                  validator: (value) {
                                    final text = value?.trim() ?? '';
                                    if (text.isEmpty) {
                                      return 'Ingresa tu correo.';
                                    }
                                    if (!_emailRegex.hasMatch(text)) {
                                      return 'Ingresa un correo valido.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                const _FieldLabel(text: 'Contrasena'),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  onFieldSubmitted: (_) {
                                    if (!isBusy) unawaitedSubmit();
                                  },
                                  decoration: _inputDecoration(
                                    hint: 'Ingresa tu contrasena',
                                    icon: Icons.lock_outline_rounded,
                                    suffix: IconButton(
                                      onPressed:
                                          () => setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          }),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Ingresa tu contrasena.';
                                    }
                                    if (value.length < 6) {
                                      return 'Usa al menos 6 caracteres.';
                                    }
                                    return null;
                                  },
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child:
                                      auth.errorMessage == null
                                          ? const SizedBox(height: 16)
                                          : Padding(
                                            key: ValueKey(auth.errorMessage),
                                            padding: const EdgeInsets.only(
                                              top: 16,
                                            ),
                                            child: _LoginAlert(
                                              message: auth.errorMessage!,
                                            ),
                                          ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: isBusy ? null : _submit,
                                    icon:
                                        isBusy
                                            ? SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color:
                                                    theme.colorScheme.onPrimary,
                                              ),
                                            )
                                            : const Icon(
                                              Icons.flight_takeoff_rounded,
                                              size: 19,
                                            ),
                                    label: Text(
                                      isBusy
                                          ? 'Abriendo cabina...'
                                          : 'Entrar ahora',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colors.primary,
                                      disabledBackgroundColor:
                                          Color.lerp(
                                            colors.surfaceCard,
                                            colors.primary,
                                            0.4,
                                          ) ??
                                          colors.surfaceCard,
                                      foregroundColor:
                                          theme.colorScheme.onPrimary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 17,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Center(
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 4,
                                    children: [
                                      Text(
                                        'No tienes cuenta?',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: colors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      TextButton(
                                        onPressed:
                                            isBusy
                                                ? null
                                                : () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder:
                                                          (_) =>
                                                              const RegisterRoleSelectionScreen(),
                                                    ),
                                                  );
                                                },
                                        child: Text(
                                          'Crear cuenta',
                                          style: TextStyle(
                                            color: colors.secondary,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void unawaitedSubmit() {
    _submit();
  }

  InputDecoration _inputDecoration({
    required IconData icon,
    String? hint,
    Widget? suffix,
  }) {
    final colors = context.appColors;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
      suffixIcon: suffix,
      prefixIcon: Icon(icon, color: colors.textSecondary),
    );
  }
}

class _LoginHeroIntro extends StatelessWidget {
  const _LoginHeroIntro({
    required this.colors,
    required this.logoGradient,
    required this.isDark,
  });

  final AppColorRoles colors;
  final List<Color> logoGradient;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      builder:
          (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - value)),
              child: child,
            ),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: logoGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: colors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Image.asset(
                'assets/LOGOINTERNO.png',
                filterQuality: FilterQuality.high,
                color: isDark ? Colors.white : null,
                colorBlendMode: isDark ? BlendMode.srcIn : null,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Red Sky',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 42,
              height: 0.96,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reserva aviacion privada con una experiencia clara, rapida y segura.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginSignalLine extends StatelessWidget {
  const _LoginSignalLine({required this.colors, required this.isBusy});

  final AppColorRoles colors;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        icon: isBusy ? Icons.sync_rounded : Icons.lock_outline_rounded,
        label: isBusy ? 'Abriendo cabina' : 'Sesion segura',
      ),
      (icon: Icons.speed_rounded, label: 'Carga optimizada'),
      (icon: Icons.support_agent_rounded, label: 'Concierge'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 10,
          children:
              items.map((item) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, size: 18, color: colors.secondary),
                    const SizedBox(width: 7),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                );
              }).toList(),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: isBusy ? null : 0.82,
            minHeight: 5,
            backgroundColor: colors.border.withValues(alpha: 0.34),
            color: colors.secondary,
          ),
        ),
      ],
    );
  }
}

class LoginValueStripLegacy extends StatelessWidget {
  const LoginValueStripLegacy({
    super.key,
    required this.colors,
    required this.isDark,
  });

  final AppColorRoles colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final items = const [
      (icon: Icons.flash_on_rounded, label: 'Cotiza rapido'),
      (icon: Icons.verified_user_rounded, label: 'Flujo seguro'),
      (icon: Icons.support_agent_rounded, label: 'Concierge'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          items.map((item) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: colors.surfaceCard.withValues(
                  alpha: isDark ? 0.76 : 0.90,
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 16, color: colors.secondary),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }
}

class CabinAccessPanelLegacy extends StatelessWidget {
  const CabinAccessPanelLegacy({
    super.key,
    required this.colors,
    required this.isBusy,
    required this.progress,
  });

  final AppColorRoles colors;
  final bool isBusy;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder:
          (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 14 * (1 - value)),
              child: child,
            ),
          ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceCard.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    isBusy
                        ? Icons.sync_rounded
                        : Icons.airline_seat_recline_extra_rounded,
                    color: colors.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBusy
                            ? 'Abriendo cabina segura'
                            : 'Cabina privada lista',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Acceso protegido para vuelos, contratos, pagos y concierge.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSecondary,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: isBusy ? null : (0.35 + progress * 0.55).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: colors.border.withValues(alpha: 0.35),
                color: colors.secondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CabinChip(
                  colors: colors,
                  icon: Icons.lock_outline_rounded,
                  label: 'Sesion segura',
                ),
                _CabinChip(
                  colors: colors,
                  icon: Icons.speed_rounded,
                  label: 'Carga optimizada',
                ),
                _CabinChip(
                  colors: colors,
                  icon: Icons.verified_rounded,
                  label: 'Datos protegidos',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CabinChip extends StatelessWidget {
  const _CabinChip({
    required this.colors,
    required this.icon,
    required this.label,
  });

  final AppColorRoles colors;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.secondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecureAccessNotice extends StatelessWidget {
  const _SecureAccessNotice({required this.colors});

  final AppColorRoles colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: colors.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tus reservas, documentos y pagos se abren dentro de una cabina protegida.',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginAlert extends StatelessWidget {
  const _LoginAlert({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.error),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: context.appColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LoginRoutePainter extends CustomPainter {
  const _LoginRoutePainter({
    required this.progress,
    required this.primary,
    required this.accent,
    required this.isDark,
  });

  final double progress;
  final Color primary;
  final Color accent;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint =
        Paint()
          ..color = primary.withValues(alpha: isDark ? 0.18 : 0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
    final accentPaint =
        Paint()
          ..color = accent.withValues(alpha: isDark ? 0.42 : 0.26)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.18 + i * 0.16);
      final path =
          Path()
            ..moveTo(-40, y)
            ..cubicTo(
              size.width * 0.24,
              y - 54,
              size.width * 0.58,
              y + 42,
              size.width + 40,
              y - 18,
            );
      canvas.drawPath(path, linePaint);
    }

    final route =
        Path()
          ..moveTo(size.width * 0.08, size.height * 0.30)
          ..cubicTo(
            size.width * 0.30,
            size.height * 0.16,
            size.width * 0.62,
            size.height * 0.42,
            size.width * 0.88,
            size.height * 0.24,
          );
    final metrics = route.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final animatedLength = metric.length * progress;
    canvas.drawPath(metric.extractPath(0, animatedLength), accentPaint);

    final tangent = metric.getTangentForOffset(animatedLength);
    if (tangent == null) return;
    canvas.save();
    canvas.translate(tangent.position.dx, tangent.position.dy);
    canvas.rotate(tangent.angle);
    final planePaint = Paint()..color = accent;
    final plane =
        Path()
          ..moveTo(12, 0)
          ..lineTo(-9, -6)
          ..lineTo(-4, 0)
          ..lineTo(-9, 6)
          ..close();
    canvas.drawPath(plane, planePaint);
    canvas.restore();

    final pulsePaint =
        Paint()
          ..color = accent.withValues(
            alpha: 0.12 + math.sin(progress * math.pi) * 0.08,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.24),
      18 + 8 * math.sin(progress * math.pi),
      pulsePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LoginRoutePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primary != primary ||
        oldDelegate.accent != accent ||
        oldDelegate.isDark != isDark;
  }
}
