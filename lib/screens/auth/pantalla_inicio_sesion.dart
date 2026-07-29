import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/proveedor_autenticacion.dart';
import 'pantalla_recuperar_contrasena.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _navy = Color(0xFF071F3B);
  static const _gold = Color(0xFFD9A441);
  static const _ink = Color(0xFF16233A);
  static const _muted = Color(0xFF7D889A);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: _gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
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
    final isBusy = auth.isLoading;

    return Scaffold(
      backgroundColor: _navy,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/login/image.png',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0.42, 0.02),
                  filterQuality: FilterQuality.high,
                  errorBuilder:
                      (context, error, stackTrace) => Container(color: _navy),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: const [0, 0.38, 0.72, 1],
                      colors: [
                        _navy.withValues(alpha: 0.96),
                        _navy.withValues(alpha: 0.78),
                        _navy.withValues(alpha: 0.26),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.58, 1],
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        _navy.withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 2, 22, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 42,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeroBlock(),
                        Transform.translate(
                          offset: const Offset(0, -96),
                          child: _LoginCard(
                            formKey: _formKey,
                            emailController: _emailController,
                            passwordController: _passwordController,
                            obscurePassword: _obscurePassword,
                            isBusy: isBusy,
                            errorMessage: auth.errorMessage,
                            onTogglePassword: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            onForgotPassword:
                                isBusy
                                    ? null
                                    : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder:
                                            (_) => PasswordRecoveryScreen(
                                              email:
                                                  _emailController.text.trim(),
                                            ),
                                      ),
                                    ),
                            onSubmit: isBusy ? null : _submit,
                            emailValidator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return 'Ingresa tu correo.';
                              }
                              if (!_emailRegex.hasMatch(text)) {
                                return 'Ingresa un correo valido.';
                              }
                              return null;
                            },
                            passwordValidator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Ingresa tu contrasena.';
                              }
                              if (value.length < 6) {
                                return 'Usa al menos 6 caracteres.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        const _FooterShield(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 380;

    return SizedBox(
      height: compact ? 252 : 296,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/LOGOINTERNO.png',
            height: compact ? 54 : 70,
            fit: BoxFit.contain,
            color: Colors.white,
            colorBlendMode: BlendMode.srcIn,
            filterQuality: FilterQuality.high,
          ),
          SizedBox(height: compact ? 4 : 5),
          Text(
            'Bienvenido a',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: compact ? 22 : 24,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: compact ? 300 : 360,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Red Sky Group',
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 44 : 52,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.1,
                  height: 0.94,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isBusy,
    required this.errorMessage,
    required this.onTogglePassword,
    required this.onForgotPassword,
    required this.onSubmit,
    required this.emailValidator,
    required this.passwordValidator,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isBusy;
  final String? errorMessage;
  final VoidCallback onTogglePassword;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onSubmit;
  final String? Function(String?) emailValidator;
  final String? Function(String?) passwordValidator;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 380;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder:
          (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - value)),
              child: child,
            ),
          ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              compact ? 18 : 20,
              compact ? 16 : 18,
              compact ? 18 : 20,
              compact ? 18 : 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(7, 31, 59, 0.10),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFBF6EC),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: _LoginScreenState._gold,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Acceder',
                    style: TextStyle(
                      color: _LoginScreenState._ink,
                      fontSize: compact ? 23 : 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _LuxuryInput(
                    controller: emailController,
                    hint: 'Correo electrónico',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    validator: emailValidator,
                  ),
                  const SizedBox(height: 10),
                  _LuxuryInput(
                    controller: passwordController,
                    hint: 'Contraseña',
                    icon: Icons.lock_outline_rounded,
                    obscureText: obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    validator: passwordValidator,
                    onFieldSubmitted: (_) {
                      if (!isBusy && onSubmit != null) {
                        onSubmit!();
                      }
                    },
                    suffix: IconButton(
                      onPressed: onTogglePassword,
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: _LoginScreenState._muted,
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child:
                        errorMessage == null
                            ? const SizedBox(height: 8)
                            : Padding(
                              key: ValueKey(errorMessage),
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFB43B3B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onForgotPassword,
                      style: TextButton.styleFrom(
                        foregroundColor: _LoginScreenState._gold,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: _ScaleButton(
                      child: _GradientLoginButton(
                        isBusy: isBusy,
                        onPressed: onSubmit,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LuxuryInput extends StatelessWidget {
  const _LuxuryInput({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.validator,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? Function(String?) validator;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        validator: validator,
        onFieldSubmitted: onFieldSubmitted,
        style: const TextStyle(
          color: _LoginScreenState._ink,
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: _LoginScreenState._muted,
            fontSize: 17,
            fontWeight: FontWeight.w400,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.72),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 10, right: 8),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _LoginScreenState._muted, size: 23),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          suffixIcon: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.36),
              width: 1.1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.36),
              width: 1.1,
            ),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            borderSide: BorderSide(color: _LoginScreenState._gold, width: 1.3),
          ),
          errorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            borderSide: BorderSide(color: Color(0xFFB43B3B), width: 1.1),
          ),
          focusedErrorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            borderSide: BorderSide(color: Color(0xFFB43B3B), width: 1.3),
          ),
        ),
      ),
    );
  }
}

class _GradientLoginButton extends StatelessWidget {
  const _GradientLoginButton({required this.isBusy, required this.onPressed});

  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF143A66), _LoginScreenState._navy],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(7, 31, 59, 0.18),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon:
            isBusy
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
                : const Icon(
                  Icons.flight_takeoff_rounded,
                  color: _LoginScreenState._gold,
                  size: 22,
                ),
        label: const Text(
          'Entrar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _FooterShield extends StatelessWidget {
  const _FooterShield();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.22),
          ),
        ),
        const SizedBox(width: 18),
        const Icon(
          Icons.shield_outlined,
          color: _LoginScreenState._gold,
          size: 38,
        ),
        const SizedBox(width: 14),
        Text(
          'Tus datos están protegidos.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.22),
          ),
        ),
      ],
    );
  }
}

class _ScaleButton extends StatefulWidget {
  const _ScaleButton({required this.child});

  final Widget child;

  @override
  State<_ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<_ScaleButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.985),
      onTapCancel: () => setState(() => _scale = 1),
      onTapUp: (_) => setState(() => _scale = 1),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
