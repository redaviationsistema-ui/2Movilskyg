import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:red_sky/models/client_operation_tracking.dart';
import 'package:red_sky/core/cliente_api.dart';
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

  testWidgets(
    'uses only the selected operation context and preserves back navigation',
    (tester) async {
      final requestedIds = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ClientTrackingScreen(
                                  operationId: '42',
                                  flightRequest: {
                                    'operation_id': 42,
                                    'origin': 'MMTO',
                                    'destination': 'MMVR',
                                    'passengers': 3,
                                    'departure_datetime': '2026-10-14T15:00:00',
                                  },
                                  aircraftName: 'Aeronave seleccionada',
                                  loader: (id) async {
                                    requestedIds.add(id);
                                    return _tracking(status: 'tracking_live');
                                  },
                                ),
                          ),
                        ),
                    child: const Text('Ver seguimiento'),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Ver seguimiento'));
      await tester.pumpAndSettle();
      expect(requestedIds, ['42']);
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).iconTheme?.color,
        Colors.white,
      );
      expect(find.text('OPERACIÓN #42'), findsOneWidget);
      expect(find.text('MMTO'), findsOneWidget);
      expect(find.text('MMVR'), findsOneWidget);
      expect(find.text('3 pax'), findsOneWidget);
      expect(find.text('Tu vuelo está en curso'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Ver seguimiento'), findsOneWidget);
    },
  );

  testWidgets(
    'rejects response and context belonging to a different operation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ClientTrackingScreen(
            operationId: '42',
            flightRequest: {'operation_id': 99, 'origin': 'PRIVATE'},
            loader: (_) async => _tracking(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PRIVATE'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      for (final responseOperationId in ['99', '']) {
        await tester.pumpWidget(
          _app(
            (_) async => ClientOperationTracking(
              operationId: responseOperationId,
              status: 'in_flight',
              timeline: const [],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('OPERACIÓN #99'), findsNothing);
        expect(find.text('OPERACIÓN #42'), findsNothing);
        expect(
          find.text('No pudimos cargar el seguimiento de tu vuelo.'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'refreshes without overlapping queries and restarts polling on operation change',
    (tester) async {
      final pending = Completer<ClientOperationTracking>();
      var calls = 0;
      await tester.pumpWidget(
        _app((_) {
          calls++;
          return pending.future;
        }),
      );
      await tester.pump(const Duration(seconds: 20));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, 1);
      pending.complete(_tracking(status: 'completed'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 20));
      expect(calls, 1);
      await tester.pumpWidget(
        MaterialApp(
          home: ClientTrackingScreen(
            operationId: '43',
            loader: (_) async {
              calls++;
              return const ClientOperationTracking(
                operationId: '43',
                status: 'tracking_live',
                timeline: [],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(find.text('OPERACIÓN #43'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 3);
    },
  );

  testWidgets('discards a stale operation response', (tester) async {
    final first = Completer<ClientOperationTracking>();
    await tester.pumpWidget(_app((_) => first.future));
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: ClientTrackingScreen(
          operationId: '43',
          loader:
              (_) async => const ClientOperationTracking(
                operationId: '43',
                status: 'confirmed',
                timeline: [],
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    first.complete(_tracking(status: 'in_flight'));
    await tester.pumpAndSettle();
    expect(find.text('OPERACIÓN #43'), findsOneWidget);
    expect(find.text('Tu vuelo está en curso'), findsNothing);
  });

  testWidgets(
    'renders long histories lazily across mobile widths and enlarged text',
    (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());
      tester.view.devicePixelRatio = 1;
      final history = [
        for (var index = 0; index < 100; index++)
          ClientOperationTimelineEvent(
            id: '$index',
            status: index.isEven ? 'confirmed' : 'future_state',
            title: 'Actualización operativa $index con un título largo',
            description:
                'Información real disponible para la operación seleccionada.',
            createdAt: DateTime.utc(2026, 10, 14, 15, index),
          ),
      ];
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        for (final width in [320.0, 360.0, 375.0, 390.0, 430.0]) {
          for (final scale in [1.0, 2.0]) {
            tester.view.physicalSize = Size(width, 900);
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                builder:
                    (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        padding: const EdgeInsets.only(top: 59, bottom: 34),
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: child!,
                    ),
                home: ClientTrackingScreen(
                  operationId: '42',
                  loader:
                      (_) async => _tracking(
                        status: 'operational_ready',
                        timeline: history,
                      ),
                  flightRequest: {
                    'operation_id': 42,
                    'passengers': 4,
                    'legs': [
                      {
                        'origin_icao': 'MMTO',
                        'destination_icao': 'MMVR',
                        'departure_datetime': '2026-10-14T15:00:00',
                      },
                      {
                        'origin_icao': 'MMVR',
                        'destination_icao': 'MMUN',
                        'departure_datetime': '2026-10-15T15:00:00',
                      },
                    ],
                  },
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$platform $width $scale',
            );
            expect(
              find.textContaining('Actualización operativa').evaluate().length,
              lessThan(100),
            );
            for (var scroll = 0; scroll < 6; scroll++) {
              await tester.drag(find.byType(ListView), const Offset(0, -350));
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '$platform $width $scale scroll $scroll',
              );
            }
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    },
  );

  testWidgets('does not retain operational content after access is denied', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _app((_) async {
        calls++;
        if (calls == 1) return _tracking(status: 'operational_ready');
        throw const ApiException('Forbidden', statusCode: 403);
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Listo para operar'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Listo para operar'), findsNothing);
    expect(find.text('OPERACIÓN #42'), findsNothing);
    expect(
      find.textContaining('Esta operación no está disponible.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'does not query an arbitrary fallback operation when no flight is selected',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ClientTrackingScreen(
            loader: (_) async {
              calls++;
              return _tracking();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(
        find.text(
          'Selecciona un vuelo desde Reservas para consultar su seguimiento.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'does not show an outdated aircraft photo when release data identifies a different aircraft',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ClientTrackingScreen(
            operationId: '42',
            flightRequest: {'operation_id': 42},
            aircraftName: 'Previous aircraft',
            aircraftImageUrl: 'https://example.test/previous.jpg',
            loader:
                (_) async => _tracking(
                  status: 'en_vuelo',
                  timeline: [
                    const ClientOperationTimelineEvent(
                      status: 'en_vuelo',
                      title: 'Liberacion operativa del proveedor',
                      description:
                          'Estado: operational_ready | Aeronave: Current aircraft | Workflow: tracking_live',
                    ),
                  ],
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Current aircraft'), findsOneWidget);
      expect(find.text('Listo para operar'), findsOneWidget);
    },
  );

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
      await tester.scrollUntilVisible(
        find.text('ACTUALIZACIONES DEL VUELO'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Todavía no hay actualizaciones operativas disponibles.'),
        findsOneWidget,
      );
      expect(find.text('Listo para operar'), findsNothing);
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

    expect(find.text('Listo para operar'), findsOneWidget);
    expect(find.text('No pudimos actualizar el seguimiento.'), findsOneWidget);
  });
}
