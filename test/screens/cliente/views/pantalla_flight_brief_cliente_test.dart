import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:red_sky/models/client_operation_tracking.dart';
import 'package:red_sky/models/flight_brief.dart';
import 'package:red_sky/screens/cliente/views/pantalla_flight_brief_cliente.dart';

FlightBrief _brief({
  required String id,
  bool visible = true,
  String departure = 'MMTO',
  bool crewConfirmed = false,
  String operationStatus = 'confirmed',
  bool ready = false,
  String? presentationLocation,
  String? presentationAddress,
  List<Map<String, dynamic>>? legs,
  Map<String, dynamic> overrides = const {},
}) => FlightBrief.fromJson({
  'flight_request_id': id,
  'visible': visible,
  'payment': {'confirmed': visible, 'status': visible ? 'paid' : 'pending'},
  'flight': {
    'departure_datetime': null,
    'arrival_datetime': null,
    'duration_hours': null,
  },
  'departure': {
    'code': departure,
    'airport_name': 'Aeropuerto de prueba',
    'city': 'Toluca',
  },
  'arrival': {
    'code': 'MMVR',
    'airport_name': 'Aeropuerto de llegada',
    'city': 'Veracruz',
  },
  'aircraft': {'model': 'Jet de prueba', 'image_url': ''},
  'provider': {'assigned': true, 'status': 'assigned'},
  'operation': {
    'id': 88,
    'status': operationStatus,
    'crew_status': 'pending_confirmation',
  },
  'crew': {
    'assigned': true,
    'confirmed': crewConfirmed,
    'status': crewConfirmed ? 'confirmed' : 'pending_confirmation',
    'visible_name': 'Sofía Herrera',
  },
  'checklist': {
    'exists': true,
    'completed': 3,
    'total': 10,
    'percentage': 30,
    'is_complete': false,
  },
  'readiness': {
    'ready': ready,
    'code': ready ? 'ready' : 'checklist_in_progress',
    'label': ready ? 'Listo para salida.' : 'Preparación en progreso.',
  },
  'presentation': {
    'airport_name': 'Aeropuerto de prueba',
    'airport_code': departure,
    'city': 'Toluca',
    'location_name': presentationLocation,
    'presentation_datetime': null,
    'address': presentationAddress,
    'maps_url': null,
    'instructions': null,
    'is_complete': false,
  },
  'support': {},
  'services': {},
  if (legs != null) 'legs': legs,
  ...overrides,
});

Widget _app({
  required String id,
  required FlightBriefLoader loader,
  Map<String, dynamic>? flightRequest,
  Future<ClientOperationTracking> Function(String operationId)? trackingLoader,
}) => MaterialApp(
  home: ClientFlightBriefScreen(
    flightRequestId: id,
    loader: loader,
    trackingLoader:
        trackingLoader ??
        (_) async => const ClientOperationTracking(
          operationId: '88',
          status: 'confirmed',
          timeline: [],
        ),
    flightRequest: flightRequest,
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));

  testWidgets(
    'renders actual operational phases without contradictory hero copy',
    (tester) async {
      final cases = [
        ('pending', false, 'Tu vuelo está pendiente'),
        ('confirmed', false, 'Tu vuelo está confirmado'),
        ('preparing', false, 'Estamos preparando tu viaje'),
        ('in_flight', false, 'Tu vuelo está en curso'),
        ('tracking_live', false, 'Tu operación está en curso'),
        ('completed', false, 'Tu vuelo ha finalizado'),
        ('cancelled', true, 'Tu vuelo fue cancelado'),
        (
          'unrecognized_state',
          false,
          'El estado operativo está por confirmar.',
        ),
        ('confirmed', true, 'Todo listo para tu vuelo'),
      ];
      for (var index = 0; index < cases.length; index++) {
        final entry = cases[index];
        await tester.pumpWidget(
          _app(
            id: 'phase-$index',
            loader:
                (_) async => _brief(
                  id: 'phase-$index',
                  operationStatus: entry.$1,
                  ready: entry.$2,
                  overrides: {'checklist': {}},
                ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(entry.$3), findsWidgets, reason: entry.$1);
        if (entry.$1 == 'cancelled' ||
            entry.$1 == 'completed' ||
            entry.$1 == 'in_flight') {
          expect(find.text('Estamos preparando tu viaje'), findsNothing);
          expect(find.text('LISTO PARA SALIDA'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('completed checks do not imply operational clearance', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        id: 'checks',
        loader:
            (_) async => _brief(
              id: 'checks',
              overrides: {
                'checklist': {
                  'exists': true,
                  'completed': 10,
                  'total': 10,
                  'percentage': 100,
                  'is_complete': true,
                },
              },
            ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Verificaciones completadas'), findsOneWidget);
    expect(find.text('Todo listo para tu vuelo'), findsNothing);
    expect(find.text('Estamos preparando tu viaje'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('ESTADO DE PREPARACIÓN'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Preparación completada'), findsOneWidget);
  });

  testWidgets(
    'keeps milestone confirmations independent and combines next step content',
    (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        _app(
          id: 'A',
          loader:
              (_) async => _brief(
                id: 'A',
                overrides: {
                  'payment': {'confirmed': false},
                  'aircraft': {},
                  'provider': {'assigned': false},
                  'crew': {'assigned': false, 'confirmed': false},
                  'checklist': {
                    'exists': true,
                    'completed': 1,
                    'total': 5,
                    'percentage': 20,
                    'is_complete': false,
                  },
                },
              ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ver hitos de preparación'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.bySemanticsLabel('Pago confirmado: pendiente'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Operador asignado: pendiente'),
        findsOneWidget,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -240));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver hitos de preparación'));
      await tester.pumpAndSettle();
      expect(find.text('Aeronave identificada · Pendiente'), findsOneWidget);
      expect(find.text('Preparación en curso · En proceso'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('PRÓXIMO PASO'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('¿NECESITAS HACER ALGO?'), findsNothing);
      expect(
        find.text('No necesitas realizar ninguna acción por el momento.'),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'shows four real legs and their presentation details without an invented return',
    (tester) async {
      final legs = [
        for (var index = 0; index < 4; index++)
          {
            'origin_icao': 'OR$index',
            'destination_icao': 'DE$index',
            'departure_datetime': '2026-10-${20 + index}T15:00:00',
            'presentation_location': 'Punto real $index',
            'presentation_time': '${10 + index}:00',
          },
      ];
      await tester.pumpWidget(
        _app(id: 'A', loader: (_) async => _brief(id: 'A', legs: legs)),
      );
      await tester.pumpAndSettle();
      expect(find.text('PRIMER TRAMO · 4 TRAMOS'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('04'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('OR3 → DE3'), findsOneWidget);
      expect(find.textContaining('Punto real 3'), findsOneWidget);
      expect(find.textContaining('13:00'), findsOneWidget);
      expect(find.text('05'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keeps partial flight data visible without inventing a route or presentation time',
    (tester) async {
      await tester.pumpWidget(
        _app(
          id: 'partial',
          loader: (_) async => FlightBrief.fromJson({'visible': true}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('OPERACIÓN #44'), findsNothing);
      expect(find.text('ESTADO POR CONFIRMAR'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Itinerario por confirmar'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('01'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('DÓNDE PRESENTARTE'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          'El punto de presentación será confirmado por nuestro equipo.',
        ),
        findsOneWidget,
      );
      expect(find.text('ICCS'), findsNothing);
      expect(find.text('Por confirmar'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fits mobile widths, safe insets and enlarged text on iOS and Android',
    (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());
      tester.view.devicePixelRatio = 1;
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
                home: ClientFlightBriefScreen(
                  flightRequestId: '$platform-$width-$scale',
                  loader:
                      (_) async => _brief(
                        id: 'responsive',
                        presentationLocation:
                            'Punto de presentación de la operación',
                        legs: [
                          {
                            'origin_icao': 'MMTO',
                            'destination_icao': 'MMSD',
                            'departure_datetime': '2026-10-20T15:00:00',
                          },
                          {
                            'origin_icao': 'MMSD',
                            'destination_icao': 'MMUN',
                            'departure_datetime': '2026-10-21T15:00:00',
                          },
                        ],
                      ),
                  trackingLoader:
                      (_) async => const ClientOperationTracking(
                        operationId: '88',
                        status: 'confirmed',
                        timeline: [],
                      ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$platform $width $scale hero',
            );
            for (var scroll = 0; scroll < 6; scroll++) {
              await tester.drag(
                find.byType(ListView).first,
                const Offset(0, -280),
              );
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '$platform $width $scale scroll=$scroll',
              );
            }
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    },
  );

  testWidgets(
    'shows the backend visibility gate instead of local flight data',
    (tester) async {
      await tester.pumpWidget(
        _app(id: 'A', loader: (_) async => _brief(id: 'A', visible: false)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Flight Brief disponible después de confirmar el pago.'),
        findsOneWidget,
      );
      expect(find.text('MMTO'), findsNothing);
    },
  );

  testWidgets(
    'renders practical presentation fallback and crew confirmation from the payload',
    (tester) async {
      await tester.pumpWidget(
        _app(
          id: 'A',
          loader: (_) async => _brief(id: 'A', crewConfirmed: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('DÓNDE PRESENTARTE'),
        120,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('DÓNDE PRESENTARTE'), findsOneWidget);
      expect(find.text('Por confirmar'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Sofía Herrera'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Sofía Herrera'), findsOneWidget);
      expect(find.text('Confirmada'), findsOneWidget);
      expect(find.text('3 de 10 completadas'), findsOneWidget);
    },
  );

  testWidgets('ignores a stale response after the client switches flights', (
    tester,
  ) async {
    final first = Completer<FlightBrief>();
    final second = Completer<FlightBrief>();
    Future<FlightBrief> loader(String id) =>
        id == 'A' ? first.future : second.future;

    await tester.pumpWidget(_app(id: 'A', loader: loader));
    await tester.pump();
    await tester.pumpWidget(_app(id: 'B', loader: loader));
    await tester.pump();

    second.complete(_brief(id: 'B', departure: 'MMVR'));
    await tester.pumpAndSettle();
    expect(find.text('MMVR', skipOffstage: false), findsWidgets);

    first.complete(_brief(id: 'A', departure: 'MMTO'));
    await tester.pumpAndSettle();
    expect(find.text('MMTO', skipOffstage: false), findsNothing);
    expect(find.text('MMVR', skipOffstage: false), findsWidgets);
  });

  testWidgets('keeps valid content after a refresh error', (tester) async {
    var call = 0;
    Future<FlightBrief> loader(String _) async {
      call++;
      if (call == 1) return _brief(id: 'A');
      throw StateError('network');
    }

    await tester.pumpWidget(_app(id: 'A', loader: loader));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(find.text('MMTO', skipOffstage: false), findsWidgets);
    expect(
      find.text('No fue posible actualizar la información del vuelo.'),
      findsOneWidget,
    );
  });

  testWidgets('refetches once when the app returns to the foreground', (
    tester,
  ) async {
    var calls = 0;
    Future<FlightBrief> loader(String _) async {
      calls++;
      return _brief(id: 'A');
    }

    await tester.pumpWidget(_app(id: 'A', loader: loader));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(calls, 2);
  });

  testWidgets('updates nullable presentation fields after a fresh payload', (
    tester,
  ) async {
    var hasLocation = false;
    Future<FlightBrief> loader(String _) async => _brief(
      id: 'A',
      presentationLocation: hasLocation ? 'FBO Norte' : null,
      presentationAddress: hasLocation ? 'Acceso norte 100' : null,
    );

    await tester.pumpWidget(_app(id: 'A', loader: loader));
    await tester.pumpAndSettle();
    hasLocation = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('DÓNDE PRESENTARTE'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('FBO Norte'), findsOneWidget);
    expect(find.text('Acceso norte 100'), findsOneWidget);

    hasLocation = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('FBO Norte', skipOffstage: false), findsNothing);
    expect(find.text('Acceso norte 100', skipOffstage: false), findsNothing);
  });

  testWidgets(
    'does not render the removed tracking CTA for a cancelled flight',
    (tester) async {
      await tester.pumpWidget(
        _app(
          id: 'A',
          loader:
              (_) async =>
                  _brief(id: 'A', operationStatus: 'cancelled', ready: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ver resumen'), findsNothing);
    },
  );

  testWidgets('renders every real leg in the compact itinerary', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        id: 'A',
        loader:
            (_) async => _brief(
              id: 'A',
              legs: [
                {
                  'origin_icao': 'MMTO',
                  'destination_icao': 'MMVR',
                  'departure_datetime': '2026-09-23T09:00:00Z',
                },
                {
                  'origin_icao': 'MMVR',
                  'destination_icao': 'MMUN',
                  'departure_datetime': '2026-09-24T10:30:00Z',
                },
              ],
            ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Estamos preparando tu viaje'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('ITINERARIO'),
      280,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('ITINERARIO'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    expect(find.text('MMVR → MMUN'), findsOneWidget);
  });

  testWidgets('uses the existing flight row legs when the brief omits them', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        id: 'A',
        loader: (_) async => _brief(id: 'A'),
        flightRequest: {
          'routes': [
            {'origin_icao': 'MMTO', 'destination_icao': 'MMVR'},
            {'origin_icao': 'MMVR', 'destination_icao': 'MMUN'},
          ],
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('ITINERARIO'),
      280,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
  });

  testWidgets('opens and closes the right-side flight actions drawer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(id: 'A', loader: (_) async => _brief(id: 'A')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Acciones del vuelo'));
    await tester.pumpAndSettle();
    expect(find.text('ACCIONES DEL VUELO'), findsOneWidget);
    expect(find.text('Ver seguimiento'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar acciones'));
    await tester.pumpAndSettle();
    expect(find.text('ACCIONES DEL VUELO'), findsNothing);
  });

  testWidgets('shows tracking history as soon as the actions drawer opens', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        id: 'A',
        loader: (_) async => _brief(id: 'A'),
        trackingLoader:
            (_) async => ClientOperationTracking(
              operationId: '88',
              status: 'in_flight',
              timeline: [
                ClientOperationTimelineEvent(
                  status: 'completed',
                  title: 'Salida confirmada',
                  description: 'La aeronave salió de la base.',
                  createdAt: DateTime.utc(2026, 9, 23, 14),
                ),
              ],
            ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Acciones del vuelo'));
    await tester.pumpAndSettle();

    expect(find.text('HISTORIAL DE SEGUIMIENTO'), findsOneWidget);
    expect(find.text('Tu vuelo está en curso'), findsOneWidget);
    expect(find.text('Salida confirmada'), findsOneWidget);
    expect(find.text('Información de tu vuelo'), findsOneWidget);
  });
}
