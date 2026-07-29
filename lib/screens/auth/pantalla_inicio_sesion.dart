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
  static const navy = Color(0xFF0F2342);
  static const gold = Color(0xFFD9B25F);
  static const paleGold = Color(0xFFF2D99A);
  static const muted = Color(0xFFB7BDC8);

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
      _showAlert('Revisa correo y contraseña para entrar.');
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
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          backgroundColor: const Color(0xFF111820),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: gold.withValues(alpha: .35)),
          ),
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: gold),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
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
      resizeToAvoidBottomInset: true,
      backgroundColor: navy,
      body: LayoutBuilder(
        builder: (context, viewport) {
          final compact = viewport.maxHeight < 760;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/login/image_portrait.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => const ColoredBox(color: navy),
              ),
              const _PremiumOverlay(),
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, compact ? 10 : 18, 24, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          viewport.maxHeight -
                          MediaQuery.paddingOf(context).vertical -
                          40,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeroBlock(compact: compact),
                          SizedBox(height: compact ? 24 : 36),
                          Align(
                            child: FractionallySizedBox(
                              widthFactor: .88,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 440,
                                ),
                                child: _LoginCard(
                                  formKey: _formKey,
                                  emailController: _emailController,
                                  passwordController: _passwordController,
                                  obscurePassword: _obscurePassword,
                                  isBusy: isBusy,
                                  errorMessage: auth.errorMessage,
                                  onTogglePassword:
                                      () => setState(
                                        () =>
                                            _obscurePassword =
                                                !_obscurePassword,
                                      ),
                                  onForgotPassword:
                                      isBusy
                                          ? null
                                          : () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => PasswordRecoveryScreen(
                                                    email:
                                                        _emailController.text
                                                            .trim(),
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
                                      return 'Ingresa un correo válido.';
                                    }
                                    return null;
                                  },
                                  passwordValidator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Ingresa tu contraseña.';
                                    }
                                    if (value.length < 6) {
                                      return 'Usa al menos 6 caracteres.';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          SizedBox(height: compact ? 22 : 34),
                          const _FooterShield(),
                        ],
                      ),
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

class _PremiumOverlay extends StatelessWidget {
  const _PremiumOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, .45, 1],
          colors: [
            const Color(0xFF07111F).withValues(alpha: .93),
            const Color(0xFF080D15).withValues(alpha: .70),
            Colors.black.withValues(alpha: .78),
          ],
        ),
      ),
    );
  }
}

class _HeroBlock extends StatelessWidget {
  const _HeroBlock({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          'assets/LOGOINTERNO.png',
          width: compact ? 54 : 66,
          height: compact ? 54 : 66,
          fit: BoxFit.contain,
          color: Colors.white,
          colorBlendMode: BlendMode.srcIn,
          filterQuality: FilterQuality.high,
        ),
        SizedBox(height: compact ? 13 : 18),
        Text(
          'Bienvenido a',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .88),
            fontSize: compact ? 21 : 24,
            fontWeight: FontWeight.w400,
            letterSpacing: -.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Red Sky Group',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 38 : 46,
            height: 1,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
          ),
        ),
        SizedBox(height: compact ? 15 : 19),
        Container(
          width: 50,
          height: 2,
          decoration: BoxDecoration(
            color: _LoginScreenState.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(height: compact ? 14 : 17),
        Text(
          'Tu vuelo comienza aquí.',
          style: TextStyle(
            color: _LoginScreenState.muted.withValues(alpha: .94),
            fontSize: compact ? 16 : 18,
            fontWeight: FontWeight.w400,
            letterSpacing: .1,
          ),
        ),
      ],
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - value)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 30 * value,
                  sigmaY: 30 * value,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: .10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .35),
              blurRadius: 38,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: _LoginScreenState.gold.withValues(alpha: .04),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _LoginScreenState.navy.withValues(alpha: .92),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: _LoginScreenState.gold,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Acceder',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(height: 11),
              Container(
                width: 38,
                height: 2,
                decoration: BoxDecoration(
                  color: _LoginScreenState.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _LuxuryInput(
                controller: emailController,
                hint: 'Correo electrónico',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                validator: emailValidator,
              ),
              const SizedBox(height: 12),
              _LuxuryInput(
                controller: passwordController,
                hint: 'Contraseña',
                icon: Icons.lock_outline_rounded,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: passwordValidator,
                onFieldSubmitted: (_) {
                  if (!isBusy && onSubmit != null) onSubmit!();
                },
                suffix: IconButton(
                  onPressed: onTogglePassword,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _LoginScreenState.gold,
                    size: 22,
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
                          padding: const EdgeInsets.only(top: 9),
                          child: Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFA8A8),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onForgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: _LoginScreenState.gold,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 13),
              _PremiumLoginButton(isBusy: isBusy, onPressed: onSubmit),
            ],
          ),
        ),
      ),
    );
  }
}

class _LuxuryInput extends StatefulWidget {
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
  State<_LuxuryInput> createState() => _LuxuryInputState();
}

class _LuxuryInputState extends State<_LuxuryInput> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor =
        _focusNode.hasFocus
            ? _LoginScreenState.gold
            : Colors.white.withValues(alpha: .10);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF252830).withValues(alpha: .72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: _focusNode.hasFocus ? 1.35 : 1,
        ),
        boxShadow:
            _focusNode.hasFocus
                ? [
                  BoxShadow(
                    color: _LoginScreenState.gold.withValues(alpha: .12),
                    blurRadius: 14,
                  ),
                ]
                : null,
      ),
      child: TextFormField(
        focusNode: _focusNode,
        controller: widget.controller,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        validator: widget.validator,
        onFieldSubmitted: widget.onFieldSubmitted,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: _LoginScreenState.muted.withValues(alpha: .9),
            fontSize: 16,
          ),
          prefixIcon: Icon(
            widget.icon,
            color: _LoginScreenState.gold,
            size: 22,
          ),
          suffixIcon: widget.suffix,
          filled: false,
          border: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 17,
          ),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
      ),
    );
  }
}

class _PremiumLoginButton extends StatefulWidget {
  const _PremiumLoginButton({required this.isBusy, required this.onPressed});

  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  State<_PremiumLoginButton> createState() => _PremiumLoginButtonState();
}

class _PremiumLoginButtonState extends State<_PremiumLoginButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:
          widget.onPressed == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown:
            widget.onPressed == null
                ? null
                : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 1.02 : 1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 58,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors:
                    _hovered
                        ? const [Color(0xFFFFE8AD), Color(0xFFE1B75A)]
                        : const [
                          _LoginScreenState.paleGold,
                          _LoginScreenState.gold,
                        ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _LoginScreenState.gold.withValues(
                    alpha: _hovered ? .32 : .20,
                  ),
                  blurRadius: _hovered ? 24 : 18,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(18),
                child: Center(
                  child:
                      widget.isBusy
                          ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: Color(0xFF111820),
                            ),
                          )
                          : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.flight_takeoff_rounded,
                                color: Color(0xFF111820),
                                size: 23,
                              ),
                              SizedBox(width: 11),
                              Text(
                                'Entrar',
                                style: TextStyle(
                                  color: Color(0xFF111820),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .2,
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
    );
  }
}

class _FooterShield extends StatelessWidget {
  const _FooterShield();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shield_outlined,
            color: _LoginScreenState.gold,
            size: 21,
          ),
          const SizedBox(width: 9),
          Text(
            'Tus datos están protegidos.',
            style: TextStyle(
              color: _LoginScreenState.muted.withValues(alpha: .95),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
