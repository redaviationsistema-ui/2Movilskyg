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

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: '');
  final _passwordController = TextEditingController(text: '');

  static final RegExp _emailRegex = RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await context.read<AuthProvider>().signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isDark = context.isDarkMode;
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
              Color.lerp(colors.background, Colors.white, 0.28) ??
                  colors.background,
              Color.lerp(colors.background, const Color(0xFFE5EDF4), 0.82) ??
                  colors.background,
              Color.lerp(colors.primary, Colors.white, 0.84) ?? colors.primary,
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
    final isBusy = auth.isLoading;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: backgroundGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: _GlowOrb(
                size: 280,
                colors: [
                  colors.secondary.withValues(alpha: isDark ? 0.28 : 0.18),
                  colors.secondary.withValues(alpha: 0),
                ],
              ),
            ),
            Positioned(
              left: -110,
              bottom: 90,
              child: _GlowOrb(
                size: 260,
                colors: [
                  colors.primary.withValues(alpha: isDark ? 0.26 : 0.14),
                  colors.primary.withValues(alpha: 0),
                ],
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                      decoration: BoxDecoration(
                        color: panelColor.withValues(
                          alpha: isDark ? 0.94 : 0.98,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color:
                              isDark
                                  ? colors.border
                                  : colors.primary.withValues(alpha: 0.10),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.34 : 0.12,
                            ),
                            blurRadius: 44,
                            offset: Offset(0, 24),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 86,
                                    height: 86,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(26),
                                      gradient: LinearGradient(
                                        colors: logoGradient,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: isDark ? 0.18 : 0.08,
                                          ),
                                          blurRadius: 18,
                                          offset: Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Image.asset(
                                        'assets/LOGOINTERNO.png',
                                        filterQuality: FilterQuality.high,
                                        color: isDark ? Colors.white : null,
                                        colorBlendMode:
                                            isDark ? BlendMode.srcIn : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Inicio de sesión',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: colors.textPrimary,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Bienvenidos a Red Sky',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 26),
                            const _FieldLabel(text: 'Correo electronico'),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              style: const TextStyle(fontSize: 15),
                              decoration: _inputDecoration(
                                hint: 'Ingresa tu correo.',
                                icon: Icons.alternate_email_rounded,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Ingresa tu correo.';
                                }
                                if (!_emailRegex.hasMatch(value.trim())) {
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
                              style: const TextStyle(fontSize: 15),
                              onFieldSubmitted: (_) {
                                if (!isBusy) _submit();
                              },
                              decoration: _inputDecoration(
                                hint: 'Ingresa tu contrasena',
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
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
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            if (auth.errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                                child: Text(
                                  auth.errorMessage!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: isBusy ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  disabledBackgroundColor:
                                      Color.lerp(
                                        colors.surfaceCard,
                                        colors.primary,
                                        0.4,
                                      ) ??
                                      colors.surfaceCard,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 17,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child:
                                    isBusy
                                        ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color:
                                                    theme.colorScheme.onPrimary,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              'Iniciando sesion...',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        )
                                        : const Text(
                                          'Iniciar sesion',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Center(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  Text(
                                    'No tienes cuenta?',
                                    style: theme.textTheme.bodyMedium?.copyWith(
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
                                    style: TextButton.styleFrom(
                                      foregroundColor: colors.secondary,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Crear cuenta',
                                      style: TextStyle(
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}
