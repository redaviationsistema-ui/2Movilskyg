import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/cliente_api.dart';
import '../../providers/proveedor_autenticacion.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  int _cooldown = 0;
  Timer? _timer;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      final message =
          await context.read<AuthProvider>().resendEmailVerification();
      if (!mounted) return;
      setState(() {
        _message = message;
        _cooldown = 60;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _cooldown <= 1) {
          timer.cancel();
          if (mounted) setState(() => _cooldown = 0);
        } else {
          setState(() => _cooldown--);
        }
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    await context.read<AuthProvider>().loadUserRole();
    if (!mounted) return;
    if (context.read<AuthProvider>().hasVerifiedEmail) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _message = 'El correo todavía aparece pendiente de verificación.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Verificar correo')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_unread_outlined, size: 64),
              const SizedBox(height: 20),
              Text(
                auth.user?.email ?? '',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Abre el enlace enviado a tu correo y después vuelve para actualizar el estado.',
                textAlign: TextAlign.center,
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(_message!, textAlign: TextAlign.center),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _refresh,
                child: const Text('Ya verifiqué'),
              ),
              TextButton(
                onPressed: _busy || _cooldown > 0 ? null : _resend,
                child: Text(
                  _cooldown > 0
                      ? 'Reenviar en ${_cooldown}s'
                      : 'Reenviar correo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
