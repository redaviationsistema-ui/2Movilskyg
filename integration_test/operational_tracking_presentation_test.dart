import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:red_sky/models/client_operation_tracking.dart';
import 'package:red_sky/screens/cliente/views/pantalla_seguimiento_cliente.dart';

import '../test/fixtures/operational_tracking.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('es_MX'));

  testWidgets(
    'native tracking preserves release meaning, selected route and enlarged text',
    (tester) async {
      for (final scale in [1.0, 2.0]) {
        var calls = 0;
        final requestedIds = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
            home: ClientTrackingScreen(
              operationId: '42',
              flightRequest: operationalTrackingRequestFixture(),
              aircraftName: 'LEARJET 31A',
              loader: (id) async {
                requestedIds.add(id);
                calls++;
                return ClientOperationTracking.fromJson(
                  operationalTrackingFixture(),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (
          var attempt = 0;
          attempt < 20 && find.text('OPERACIÓN #42').evaluate().isEmpty;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(
          find.text('OPERACIÓN #42'),
          findsOneWidget,
          reason:
              'scale=$scale calls=$calls texts=${tester.allWidgets.whereType<Text>().map((widget) => widget.data).join('|')}',
        );
        expect(find.text('Listo para operar'), findsOneWidget);
        expect(find.text('Tu vuelo está en curso'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Ver itinerario completo'),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('Ver itinerario completo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver itinerario completo'));
        await tester.pumpAndSettle();
        expect(find.textContaining('MMVR → MMUN'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('PRÓXIMO PASO'),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text(
            'Nuestro equipo compartirá la próxima actualización cuando esté disponible.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('operational_ready'), findsNothing);
        expect(find.textContaining('tracking_live'), findsNothing);
        expect(tester.takeException(), isNull);
        expect(calls, greaterThanOrEqualTo(1));
        expect(requestedIds.every((id) => id == '42'), isTrue);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );
}
