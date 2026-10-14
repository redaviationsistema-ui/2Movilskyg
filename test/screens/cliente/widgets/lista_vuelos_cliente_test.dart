import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:red_sky/providers/proveedor_reservaciones.dart';
import 'package:red_sky/screens/cliente/views/pantalla_seguimiento_cliente.dart';
import 'package:red_sky/screens/cliente/widgets/lista_vuelos_cliente.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));
  testWidgets(
    'Reservations tracking passes the selected row instead of the featured next flight',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'client_flights_guide_completed_v1': true,
      });
      final provider = _TrackingNavigationProvider();
      addTearDown(provider.dispose);
      provider.flightRequests = [
        {
          'id': 'featured',
          'flight_request_id': 'featured',
          'operation_id': 'featured-operation',
          'flight_status': 'en vuelo',
          'origin': 'MMTO',
          'destination': 'MMSD',
          'departure_datetime': '2026-10-20T15:00:00',
          'aircraft': 'Featured aircraft',
          'passengers': 1,
        },
        {
          'id': 'selected',
          'flight_request_id': 'selected',
          'operation_id': 'selected-operation',
          'flight_status': 'en vuelo',
          'origin': 'MMVR',
          'destination': 'MMUN',
          'departure_datetime': '2026-10-21T15:00:00',
          'aircraft': 'Selected aircraft',
          'passengers': 4,
        },
      ];
      await tester.pumpWidget(
        ChangeNotifierProvider<ReservationProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: ClientFlightsList(
              heading: 'Reservas',
              description: 'Próximos',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ver seguimiento'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Ver seguimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver seguimiento'));
      await tester.pumpAndSettle();
      final screen = tester.widget<ClientTrackingScreen>(
        find.byType(ClientTrackingScreen),
      );
      expect(screen.operationId, 'selected-operation');
      expect(screen.flightRequest?['origin'], 'MMVR');
      expect(screen.flightRequest?['destination'], 'MMUN');
      expect(screen.aircraftName, 'Selected aircraft');
      expect(screen.flightRequest?['passengers'], 4);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ClientFlightsList), findsOneWidget);
      expect(find.byType(ClientTrackingScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'flight tabs show only their status group and keep the featured operation unique',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'client_flights_guide_completed_v1': true,
      });
      final provider = _TrackingNavigationProvider();
      addTearDown(provider.dispose);
      final now = DateTime.now();
      final activePastDate = now.subtract(const Duration(days: 1));
      final upcomingDate = now.add(const Duration(days: 60));
      provider.flightRequests = [
        {
          'id': 'active',
          'flight_request_id': 'active',
          'operation_id': 'operation-active',
          'workflow_status': 'tracking_live',
          'origin': 'MMTO',
          'destination': 'MMVR',
          'departure_datetime': activePastDate.toIso8601String(),
          'passengers': 2,
        },
        {
          'id': 'active-copy',
          'flight_request_id': 'active-copy',
          'operation_id': 'operation-active',
          'workflow_status': 'tracking_live',
          'origin': 'MMTO',
          'destination': 'MMVR',
          'departure_datetime': activePastDate.toIso8601String(),
          'passengers': 2,
        },
        {
          'id': 'upcoming',
          'flight_request_id': 'upcoming',
          'operation_id': 'operation-upcoming',
          'workflow_status': 'flight_confirmed',
          'origin': 'MMVR',
          'destination': 'MMUN',
          'departure_datetime': upcomingDate.toIso8601String(),
          'passengers': 4,
        },
        {
          'id': 'completed',
          'flight_request_id': 'completed',
          'operation_id': 'operation-completed',
          'workflow_status': 'completed',
          'origin': 'MMTO',
          'destination': 'MMUN',
          'departure_datetime': activePastDate.toIso8601String(),
        },
        {
          'id': 'cancelled',
          'flight_request_id': 'cancelled',
          'operation_id': 'operation-cancelled',
          'workflow_status': 'cancelled',
          'origin': 'MMTO',
          'destination': 'MMGL',
          'departure_datetime': upcomingDate.toIso8601String(),
          'reservation': {'cancellation_reason': 'Cambio de itinerario'},
        },
        {
          'id': 'rejected',
          'flight_request_id': 'rejected',
          'operation_id': 'operation-rejected',
          'workflow_status': 'rejected',
          'origin': 'MMTO',
          'destination': 'MMQT',
          'departure_datetime': upcomingDate.toIso8601String(),
        },
      ];

      await tester.pumpWidget(
        ChangeNotifierProvider<ReservationProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: ClientFlightsList(
              heading: 'Tus vuelos',
              description: 'Consulta y gestiona tus reservaciones.',
              showBackButton: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('6 vuelos'), findsOneWidget);
      expect(find.text('PRÓXIMO VUELO'), findsOneWidget);
      expect(find.text('Toluca → MMVR'), findsOneWidget);
      expect(
        find.text('Fecha programada pasada · estado aún activo'),
        findsOneWidget,
      );
      expect(
        find.text('Seguimiento operativo activo'.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text('MMVR → MMUN'), findsOneWidget);
      expect(find.text('Toluca → MMGL'), findsNothing);

      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(find.text('PRÓXIMO VUELO'), findsNothing);
      expect(find.text('Toluca → MMUN'), findsOneWidget);
      expect(find.text('Toluca → MMVR'), findsNothing);
      expect(find.text('Vuelos completados'), findsNothing);

      await tester.tap(find.text('Cancelados'));
      await tester.pumpAndSettle();
      expect(find.text('PRÓXIMO VUELO'), findsNothing);
      expect(find.text('Toluca → Guadalajara'), findsOneWidget);
      expect(
        find.text('Motivo de cancelación: Cambio de itinerario'),
        findsOneWidget,
      );
      expect(find.text('VUELO RECHAZADO'), findsOneWidget);
      expect(find.text('Toluca → MMQT'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('history and cancelled empty states are compact and direct', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'client_flights_guide_completed_v1': true,
    });
    final provider = _TrackingNavigationProvider();
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ReservationProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: ClientFlightsList(
            heading: 'Tus vuelos',
            description: 'Consulta y gestiona tus reservaciones.',
            showBackButton: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay vuelos completados'), findsOneWidget);
    expect(find.text('Vuelos completados'), findsNothing);
    await tester.tap(find.text('Cancelados'));
    await tester.pumpAndSettle();
    expect(find.text('No tienes vuelos cancelados'), findsOneWidget);
    expect(find.text('Vuelos cancelados'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  group('Client flight primary action', () {
    test('confirmed flight opens Flight Brief', () {
      final action = resolveClientFlightPrimaryAction({
        'flight_request_id': 'req-confirmed',
        'flight_status': 'confirmed',
      });

      expect(action.type, ClientFlightPrimaryActionType.flightBrief);
      expect(action.label, 'Ver Flight Brief');
    });

    test('preparing flight opens Flight Brief', () {
      final action = resolveClientFlightPrimaryAction({
        'flight_request_id': 'req-preparing',
        'flight_status': 'en preparación',
      });

      expect(action.type, ClientFlightPrimaryActionType.flightBrief);
    });

    test('ready flight opens Flight Brief', () {
      final action = resolveClientFlightPrimaryAction({
        'flight_request_id': 'req-ready',
        'flight_status': 'ready',
      });

      expect(action.type, ClientFlightPrimaryActionType.flightBrief);
    });

    test('operational status opens Flight Brief for the current flight', () {
      for (final status in [
        'EN_OPERACION',
        'EN OPERACIÓN',
        'in_operation',
        'operating',
      ]) {
        final request = {
          'flight_request_id': 'req-toluca-queretaro',
          'origin': 'Toluca',
          'destination': 'Querétaro',
          'flight_status': status,
        };

        final action = resolveClientFlightPrimaryAction(request);

        expect(action.type, ClientFlightPrimaryActionType.flightBrief);
        expect(action.label, 'Ver Flight Brief');
        expect(action.icon, Icons.assignment_outlined);
        expect(resolveClientFlightRequestId(request), 'req-toluca-queretaro');
      }
    });

    test('operational CTA does not use the new-flight label', () {
      final action = resolveClientFlightPrimaryAction({
        'flight_request_id': 'req-live',
        'status': 'EN_OPERACION',
      });

      expect(action.label, isNot('Nuevo vuelo'));
      expect(action.label, 'Ver Flight Brief');
    });

    test('operational status takes priority over tracking availability', () {
      final action = resolveClientFlightPrimaryAction({
        'flight_request_id': 'req-toluca-queretaro',
        'operation_id': 'operation-live',
        'flight_status': 'EN_OPERACION',
        'tracking_available': true,
      });

      expect(action.type, ClientFlightPrimaryActionType.flightBrief);
      expect(action.icon, Icons.assignment_outlined);
    });

    test('next flight never resolves tracking when tracking is available', () {
      final action = resolveClientFlightPrimaryAction({
        'flight_request_id': 'req-next',
        'operation_id': 'operation-live',
        'flight_status': 'en vuelo',
        'tracking_live': true,
      }, allowTracking: false);

      expect(action.type, ClientFlightPrimaryActionType.flightBrief);
      expect(action.label, 'Ver Flight Brief');
      expect(action.icon, Icons.assignment_outlined);
    });

    test('in-flight operation opens tracking when it is available', () {
      final action = resolveClientFlightPrimaryAction({
        'flight_request_id': 'req-live',
        'operation_id': 'operation-live',
        'flight_status': 'en vuelo',
      });

      expect(action.type, ClientFlightPrimaryActionType.tracking);
      expect(action.label, 'Ver seguimiento');
    });

    test('completed flight opens its summary', () {
      final action = resolveClientFlightPrimaryAction({
        'flight_request_id': 'req-completed',
        'flight_status': 'finalizado',
      });

      expect(action.type, ClientFlightPrimaryActionType.summary);
      expect(action.label, 'Ver resumen');
    });

    test('cancelled flight has no operational CTA', () {
      final action = resolveClientFlightPrimaryAction({
        'flight_request_id': 'req-cancelled',
        'workflow_status': 'cancelled',
      });

      expect(action.type, ClientFlightPrimaryActionType.none);
      expect(action.isOperational, isFalse);
    });

    test('operation id alone does not make tracking available', () {
      expect(
        hasClientTrackingAvailable({
          'operation_id': 'operation-not-live',
          'flight_status': 'confirmed',
        }),
        isFalse,
      );
    });

    test('other workflow states keep their existing action', () {
      final action = resolveClientFlightPrimaryAction({
        'flight_request_id': 'req-completed',
        'flight_status': 'finalizado',
      });

      expect(action.type, ClientFlightPrimaryActionType.summary);
      expect(action.label, 'Ver resumen');
    });
  });

  group('ClientFlightsList passenger formatting', () {
    test('passengers = 4 -> 4 pax', () {
      expect(resolveClientPassengerCount({'passengers': 4}), 4);
      expect(formatClientPassengerCompactLabel({'passengers': 4}), '4 pax');
    });

    test('passengers = 1 -> 1 pax', () {
      expect(resolveClientPassengerCount({'passengers': 1}), 1);
      expect(formatClientPassengerCompactLabel({'passengers': 1}), '1 pax');
    });

    test('missing passengers does not render 1 pax', () {
      expect(resolveClientPassengerCount({}), isNull);
      expect(formatClientPassengerCompactLabel({}), 'Pax -');
    });

    test('null passengers does not render 1 pax', () {
      expect(resolveClientPassengerCount({'passengers': null}), isNull);
      expect(formatClientPassengerCompactLabel({'passengers': null}), 'Pax -');
    });

    test('alternative passenger field is honored', () {
      expect(resolveClientPassengerCount({'num_passengers': 3}), 3);
      expect(formatClientPassengerCompactLabel({'num_passengers': 3}), '3 pax');
    });
  });
}

class _TrackingNavigationProvider extends ReservationProvider {
  @override
  Future<void> loadClientWorkspaceData({bool force = false}) async {}
}
