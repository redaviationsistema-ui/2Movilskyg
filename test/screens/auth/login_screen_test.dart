import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:red_sky/providers/proveedor_autenticacion.dart';
import 'package:red_sky/screens/auth/pantalla_inicio_sesion.dart';

void main() {
  testWidgets('renders premium login hero and form copy', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Bienvenido a'), findsOneWidget);
    expect(find.text('Red Sky Group'), findsOneWidget);
    expect(find.text('Tu vuelo comienza aquí.'), findsOneWidget);
    expect(find.text('Acceder'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
