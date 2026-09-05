import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:red_sky/models/client_operation_tracking.dart';
import 'package:red_sky/screens/cliente/views/pantalla_seguimiento_cliente.dart';

ClientOperationTracking _tracking({
  String status = 'preparation',
  List<ClientOperationTimelineEvent> timeline = const [],
}) => ClientOperationTracking(
  operationId: '42',
  status: status,
  timeline: timeline,
);

Widget _app(OperationTrackingLoader loader) =>
    MaterialApp(home: ClientTrackingScreen(operationId: '42', loader: loader));

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));

  testWidgets('renders real status and backend timeline only', (tester) async {
    await tester.pumpWidget(
      _app(
        (_) async => _tracking(
          status: 'in_flight',
          timeline: [
            ClientOperationTimelineEvent(
              status: 'in_flight',
              title: 'Salida confirmada',
              description: 'El vuelo se encuentra en curso.',
              createdAt: DateTime.utc(2026, 9, 23, 15),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tu vuelo está en curso'), findsOneWidget);
    expect(find.text('Salida confirmada'), findsOneWidget);
    expect(find.text('Demostracion sin datos operativos'), findsNothing);
  });

  testWidgets(
    'renders empty timeline and cancellation without positive state',
    (tester) async {
      await tester.pumpWidget(
        _app((_) async => _tracking(status: 'cancelled')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vuelo cancelado'), findsOneWidget);
      expect(
        find.text('Todavía no hay actualizaciones operacionales disponibles.'),
        findsOneWidget,
      );
      expect(find.text('Tu vuelo está listo'), findsNothing);
    },
  );

  testWidgets('shows retry instead of demo data after an initial error', (
    tester,
  ) async {
    await tester.pumpWidget(_app((_) async => throw StateError('network')));
    await tester.pumpAndSettle();

    expect(
      find.text('No pudimos cargar el seguimiento de tu vuelo.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('keeps valid tracking after a refresh error', (tester) async {
    var calls = 0;
    Future<ClientOperationTracking> loader(String _) async {
      calls++;
      if (calls == 1) return _tracking(status: 'ready');
      throw StateError('network');
    }

    await tester.pumpWidget(_app(loader));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 280));
    await tester.pumpAndSettle();

    expect(find.text('Tu vuelo está listo'), findsOneWidget);
    expect(find.text('No pudimos actualizar el seguimiento.'), findsOneWidget);
  });
}
