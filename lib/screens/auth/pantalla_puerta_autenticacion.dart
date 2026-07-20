import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/proveedor_autenticacion.dart';
import '../marketplace/pantalla_inicio_mercado.dart';
import 'pantalla_inicio_sesion.dart';
import 'pantalla_verificar_correo.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().bootstrapSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isBootstrapping) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (auth.bootstrapState == SessionBootstrapState.offline) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    auth.errorMessage ?? 'No fue posible validar la sesión.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => auth.bootstrapSession(force: true),
                    child: const Text('Reintentar'),
                  ),
                  TextButton(
                    onPressed: auth.signOut,
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (auth.bootstrapState == SessionBootstrapState.denied) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    auth.errorMessage ??
                        'No tienes permiso para acceder a esta aplicación.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: auth.signOut,
                    child: const Text('Volver al acceso'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    final portal = MarketplaceHomeScreen(role: auth.role);
    if (auth.hasVerifiedEmail) return portal;
    return Stack(
      children: [
        portal,
        Positioned(
          left: 12,
          right: 12,
          top: MediaQuery.paddingOf(context).top + 8,
          child: Material(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(14),
            child: ListTile(
              leading: const Icon(Icons.mark_email_unread_outlined),
              title: const Text('Correo pendiente de verificación'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const VerifyEmailScreen(),
                    ),
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
