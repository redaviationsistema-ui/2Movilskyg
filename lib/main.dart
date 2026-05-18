import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/reservation_provider.dart';
import 'providers/workflow_provider.dart';
import 'screens/auth/auth_gate_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es_MX';
  await initializeDateFormatting('es_MX');
  await initializeDateFormatting('es');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ReservationProvider()),
        ChangeNotifierProvider(create: (_) => WorkflowProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Red Sky',
        locale: const Locale('es', 'MX'),
        supportedLocales: const [
          Locale('es', 'MX'),
          Locale('es'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE2BD79),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF3F6F8),
          useMaterial3: true,
          fontFamily: 'Roboto',
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF3F6F8),
            foregroundColor: Color(0xFF0E2238),
            elevation: 0,
            centerTitle: false,
          ),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        home: const AuthGateScreen(),
      ),
    );
  }
}
