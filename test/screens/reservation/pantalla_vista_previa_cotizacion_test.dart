import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:red_sky/providers/proveedor_reservaciones.dart';
import 'package:red_sky/screens/reservation/pantalla_vista_previa_cotizacion.dart';
import 'package:red_sky/models/modelo_ruta.dart';
import 'package:red_sky/models/aeropuerto.dart';

void main() {
  testWidgets(
    'renders dynamic itinerary summary and delegates edit to the correct leg',
    (tester) async {
      final reservation =
          ReservationProvider()
            ..passengers = 3
            ..bookingTripLabel = 'Multidestino'
            ..routes = [
              _route(
                _airport('Toluca', 'MMTO', 'TLC'),
                _airport('Puerto Vallarta', 'MMPR', 'PVR'),
              ),
              _route(
                _airport('Puerto Vallarta', 'MMPR', 'PVR'),
                _airport('Morelia', 'MMMM', 'MLM'),
              ),
              _route(
                _airport('Morelia', 'MMMM', 'MLM'),
                _airport('Toluca', 'MMTO', 'TLC'),
              ),
            ];
      addTearDown(reservation.dispose);
      var requestedQuotes = 0;
      var editedLeg = -1;

      await tester.pumpWidget(
        ChangeNotifierProvider<ReservationProvider>.value(
          value: reservation,
          child: MaterialApp(
            home: ItinerarySummaryScreen(
              tripType: 'Multidestino',
              enableMapVectorProvider: false,
              onRequestQuote: () => requestedQuotes++,
              onEditLeg: (index) => editedLeg = index,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Resumen de itinerario'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('itinerary-summary-jet-image')),
        findsOneWidget,
      );
      expect(
        find.text('Revisa tu recorrido antes de cotizar.'),
        findsOneWidget,
      );
      expect(find.text('Multidestino'), findsOneWidget);
      expect(find.text('RECORRIDO'), findsOneWidget);
      expect(find.text('MODALIDAD'), findsOneWidget);
      expect(find.text('FECHA'), findsOneWidget);
      expect(find.text('TRAMOS'), findsOneWidget);
      expect(find.text('3 tramos'), findsOneWidget);
      expect(find.text('3 pasajeros'), findsOneWidget);
      expect(find.text('13 oct 2026'), findsOneWidget);
      expect(find.text('RECORRIDO'), findsOneWidget);
      expect(
        find.text('DETALLE DE TRAMOS', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('map-zoom-in')), findsOneWidget);
      expect(find.byKey(const ValueKey('map-zoom-out')), findsOneWidget);
      expect(find.byKey(const ValueKey('map-center-route')), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      expect(
        find.text('Ruta ilustrativa · No válida para navegación aérea.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('13 oct · 09:00', skipOffstage: false),
        findsWidgets,
      );
      expect(find.text('TLC  →  PVR', skipOffstage: false), findsOneWidget);
      expect(find.text('PVR  →  MLM', skipOffstage: false), findsOneWidget);
      expect(find.text('MLM  →  TLC', skipOffstage: false), findsOneWidget);
      expect(find.byKey(const ValueKey('direction-marker-2')), findsOneWidget);

      final editThirdLeg = find.byKey(
        const ValueKey('edit-itinerary-leg-2'),
        skipOffstage: false,
      );
      await tester.scrollUntilVisible(
        editThirdLeg,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(editThirdLeg);
      expect(editedLeg, 2);

      await tester.tap(find.byKey(const ValueKey('request-itinerary-quote')));
      expect(requestedQuotes, 1);
    },
  );

  testWidgets('summary navigation controls do not pop a root route', (
    tester,
  ) async {
    final reservation = ReservationProvider();
    addTearDown(reservation.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ReservationProvider>.value(
        value: reservation,
        child: const MaterialApp(
          home: ItinerarySummaryScreen(
            tripType: 'Solo ida',
            enableMapVectorProvider: false,
            onRequestQuote: _noop,
            onEditLeg: _noopIndex,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Regresar al formulario'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    expect(find.text('Editar'), findsNothing);
  });

  testWidgets('round-trip summary shows both explicit legs', (tester) async {
    final reservation =
        ReservationProvider()
          ..passengers = 2
          ..bookingTripLabel = 'Ida y vuelta'
          ..routes = [
            _route(
              _airport('Toluca', 'MMTO', 'TLC'),
              _airport('Puerto Vallarta', 'MMPR', 'PVR'),
            ),
            _route(
              _airport('Puerto Vallarta', 'MMPR', 'PVR'),
              _airport('Toluca', 'MMTO', 'TLC'),
            )..startDate = DateTime(2026, 10, 14, 17),
          ];
    addTearDown(reservation.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ReservationProvider>.value(
        value: reservation,
        child: const MaterialApp(
          home: ItinerarySummaryScreen(
            tripType: 'Ida y vuelta',
            enableMapVectorProvider: false,
            onRequestQuote: _noop,
            onEditLeg: _noopIndex,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ida y vuelta'), findsOneWidget);
    expect(find.text('2 tramos'), findsOneWidget);
    expect(find.text('TLC  →  PVR', skipOffstage: false), findsOneWidget);
    expect(find.text('PVR  →  TLC', skipOffstage: false), findsOneWidget);
    expect(
      find.textContaining('14 oct · 17:00', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets(
    'uses backend pricing total_amount in quote preview instead of stale final_price',
    (tester) async {
      final reservation = ReservationProvider();
      addTearDown(reservation.dispose);

      reservation.selectedQuoteMatch = {
        'id': 'match-preview',
        'match_id': 'match-preview',
        'aircraft_name': 'GULFSTREAM G450',
        'final_price': 'USD 13,535',
        'pricing': {'total_amount': 42960},
        'pricing_breakdown': {'final_billable_hours': 4.0},
      };

      await tester.pumpWidget(
        ChangeNotifierProvider<ReservationProvider>.value(
          value: reservation,
          child: const MaterialApp(
            home: QuotePreviewScreen(enableMapVectorProvider: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('USD42,960'), findsOneWidget);
      expect(find.text('USD 13,535'), findsNothing);
    },
  );

  testWidgets(
    'renders Learjet 45 preview with the same backend normalized time as the web example',
    (tester) async {
      final reservation = ReservationProvider();
      addTearDown(reservation.dispose);

      reservation.selectedQuoteMatch = {
        'id': 'match-preview-learjet-45',
        'match_id': 'match-preview-learjet-45',
        'aircraft_name': 'LEARJET 45',
        'time': '4 h 50 min',
        'trip_time': '4 h 50 min',
        'card_time': '4 h 50 min',
        'pricing': {'total_amount': 18874},
        'pricing_breakdown': {'final_billable_hours': 4.83},
      };

      await tester.pumpWidget(
        ChangeNotifierProvider<ReservationProvider>.value(
          value: reservation,
          child: const MaterialApp(
            home: QuotePreviewScreen(enableMapVectorProvider: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('4 h 50 min'), findsOneWidget);
      expect(find.text('Horas cobrables backend: 4 h 50 min'), findsOneWidget);
      expect(find.text('1 h 00 min'), findsNothing);
      expect(find.text('USD18,874'), findsOneWidget);
    },
  );

  testWidgets(
    'reuses the official display route hours when legacy trip labels are stale',
    (tester) async {
      final reservation = ReservationProvider();
      addTearDown(reservation.dispose);

      reservation.selectedQuoteMatch = {
        'id': 'match-preview-display-route-hours',
        'match_id': 'match-preview-display-route-hours',
        'aircraft_name': 'LEARJET 45',
        'time': '1 h 50 min',
        'trip_time': '4 h 50 min',
        'card_time': '4 h 50 min',
        'pricing': {'total_amount': 18874, 'display_route_hours': 1.83},
        'pricing_breakdown': {
          'display_route_hours': 1.83,
          'final_billable_hours': 4.83,
        },
      };

      await tester.pumpWidget(
        ChangeNotifierProvider<ReservationProvider>.value(
          value: reservation,
          child: const MaterialApp(
            home: QuotePreviewScreen(enableMapVectorProvider: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('1 h 50 min'), findsWidgets);
      expect(find.text('4 h 50 min'), findsNothing);
    },
  );

  testWidgets(
    'prevents confirmation when selected quote is no longer available',
    (tester) async {
      final reservation = ReservationProvider();
      addTearDown(reservation.dispose);

      reservation.selectedQuoteMatch = {
        'id': 'match-unavailable',
        'match_id': 'match-unavailable',
        'aircraft_name': 'LEARJET 45',
        'aircraft_id': 'aircraft-1',
        'is_available': false,
        'availability_reason': 'Esta aeronave ya no esta disponible.',
      };
      reservation.quoteMatches = [
        Map<String, dynamic>.from(reservation.selectedQuoteMatch!),
      ];
      reservation.routes = [
        RouteModel(
          fromAirport: Airport(
            name: 'Toluca',
            city: 'Toluca',
            icao: 'MMTO',
            iata: 'TLC',
            lat: 19.3371,
            lng: -99.5660,
          ),
          toAirport: Airport(
            name: 'Queretaro',
            city: 'Queretaro',
            icao: 'MMQT',
            iata: 'QRO',
            lat: 20.6173,
            lng: -100.1857,
          ),
          startDate: DateTime.utc(2026, 8, 20, 10),
        ),
      ];
      reservation.startDate = DateTime.utc(2026, 8, 20, 10);

      await tester.pumpWidget(
        ChangeNotifierProvider<ReservationProvider>.value(
          value: reservation,
          child: const MaterialApp(
            home: QuotePreviewScreen(enableMapVectorProvider: false),
          ),
        ),
      );
      await tester.pump();

      await const QuotePreviewScreen(
        enableMapVectorProvider: false,
      ).confirm(tester.element(find.byType(QuotePreviewScreen)));
      await tester.pump();

      expect(reservation.selectedQuoteMatch, isNull);
      expect(reservation.quoteMatches, isEmpty);
      expect(find.text('Esta aeronave ya no esta disponible.'), findsOneWidget);
    },
  );

  testWidgets('renders one way itinerary map from provider routes', (
    tester,
  ) async {
    final reservation = _reservationWithQuote();
    addTearDown(reservation.dispose);
    reservation.routes = [
      _route(
        _airport('Toluca', 'MMTO', 'TLC'),
        _airport('Puerto Vallarta', 'MMPR', 'PVR'),
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<ReservationProvider>.value(
        value: reservation,
        child: const MaterialApp(
          home: QuotePreviewScreen(enableMapVectorProvider: false),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Mapa de tu recorrido'), findsOneWidget);
    expect(find.text('TLC'), findsOneWidget);
    expect(find.text('PVR'), findsOneWidget);
    expect(find.byKey(const ValueKey('direction-marker-0')), findsOneWidget);
    expect(
      find.text(
        'Recorrido ilustrativo. No representa una ruta aérea autorizada.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders round trip and multidestination itinerary segments', (
    tester,
  ) async {
    final reservation = _reservationWithQuote();
    addTearDown(reservation.dispose);
    reservation.bookingTripLabel = 'Multidestino';
    reservation.routes = [
      _route(
        _airport('Toluca', 'MMTO', 'TLC'),
        _airport('Puerto Vallarta', 'MMPR', 'PVR'),
      ),
      _route(
        _airport('Puerto Vallarta', 'MMPR', 'PVR'),
        _airport('Toluca', 'MMTO', 'TLC'),
      ),
      _route(
        _airport('Toluca', 'MMTO', 'TLC'),
        _airport('Morelia', 'MMMM', 'MLM'),
      ),
      _route(
        _airport('Morelia', 'MMMM', 'MLM'),
        _airport('Toluca', 'MMTO', 'TLC'),
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<ReservationProvider>.value(
        value: reservation,
        child: const MaterialApp(
          home: QuotePreviewScreen(enableMapVectorProvider: false),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('TLC'), findsOneWidget);
    expect(find.text('PVR'), findsOneWidget);
    expect(find.text('MLM'), findsOneWidget);
    for (var index = 0; index < 4; index++) {
      expect(find.byKey(ValueKey('direction-marker-$index')), findsOneWidget);
    }
  });

  testWidgets('updates map when provider adds, edits, and removes a route', (
    tester,
  ) async {
    final reservation = _reservationWithQuote();
    addTearDown(reservation.dispose);
    final quote = reservation.selectedQuoteMatch!;
    reservation.routes = [
      _route(
        _airport('Toluca', 'MMTO', 'TLC'),
        _airport('Puerto Vallarta', 'MMPR', 'PVR'),
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<ReservationProvider>.value(
        value: reservation,
        child: const MaterialApp(
          home: QuotePreviewScreen(enableMapVectorProvider: false),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('direction-marker-0')), findsOneWidget);

    reservation.addRoute();
    reservation.setToAirport(1, _airport('Morelia', 'MMMM', 'MLM'));
    reservation.selectedQuoteMatch = quote;
    reservation.notifyListeners();
    await tester.pump();

    expect(find.text('MLM'), findsOneWidget);
    expect(find.byKey(const ValueKey('direction-marker-1')), findsOneWidget);

    reservation.setToAirport(1, _airport('Cancun', 'MMUN', 'CUN'));
    reservation.selectedQuoteMatch = quote;
    reservation.notifyListeners();
    await tester.pump();

    expect(find.text('MLM'), findsNothing);
    expect(find.text('CUN'), findsOneWidget);

    reservation.removeRoute(1);
    reservation.selectedQuoteMatch = quote;
    reservation.notifyListeners();
    await tester.pump();

    expect(find.text('CUN'), findsNothing);
    expect(find.byKey(const ValueKey('direction-marker-1')), findsNothing);
    expect(find.byKey(const ValueKey('direction-marker-0')), findsOneWidget);
  });

  testWidgets('summary layout fits narrow and wide logical widths', (
    tester,
  ) async {
    final reservation =
        ReservationProvider()
          ..passengers = 3
          ..bookingTripLabel = 'Ida y vuelta'
          ..routes = [
            _route(
              _airport('Toluca', 'MMTO', 'TLC'),
              _airport('Puerto Vallarta', 'MMPR', 'PVR'),
            ),
          ];
    addTearDown(reservation.dispose);

    for (final width in [320.0, 360.0, 375.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        ChangeNotifierProvider<ReservationProvider>.value(
          value: reservation,
          child: const MaterialApp(
            home: ItinerarySummaryScreen(
              tripType: 'Ida y vuelta',
              enableMapVectorProvider: false,
              onRequestQuote: _noop,
              onEditLeg: _noopIndex,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('TLC  →  PVR', skipOffstage: false), findsOneWidget);
      expect(
        find.byKey(const ValueKey('request-itinerary-quote')),
        findsOneWidget,
      );
      final header = tester.getSize(
        find.byKey(const ValueKey('itinerary-summary-header')),
      );
      expect(header.height, lessThanOrEqualTo(165));
      expect(header.width, width);
      expect(
        tester
            .widget<ListView>(
              find.byKey(const ValueKey('itinerary-summary-content')),
            )
            .padding,
        const EdgeInsets.fromLTRB(18, 8, 18, 20),
      );
      final metricTops =
          ['mode', 'legs', 'date', 'passengers'].map((name) {
            return tester
                .getTopLeft(
                  find.byKey(
                    ValueKey('summary-metric-$name'),
                    skipOffstage: false,
                  ),
                )
                .dy;
          }).toList();
      expect(
        metricTops.reduce(math.min),
        closeTo(metricTops.reduce(math.max), 1),
      );
      expect(
        find.byKey(const ValueKey('summary-metrics-scroll')),
        findsNothing,
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('summary follows provider route, date and passenger changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reservation =
        ReservationProvider()
          ..passengers = 2
          ..routes = [
            _route(
              _airport('Toluca', 'MMTO', 'TLC'),
              _airport('Puerto Vallarta', 'MMPR', 'PVR'),
            ),
          ];
    addTearDown(reservation.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ReservationProvider>.value(
        value: reservation,
        child: const MaterialApp(
          home: ItinerarySummaryScreen(
            tripType: 'Solo ida',
            enableMapVectorProvider: false,
            onRequestQuote: _noop,
            onEditLeg: _noopIndex,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2 pax'), findsOneWidget);
    expect(find.text('13 oct 26'), findsOneWidget);
    expect(find.text('TLC  →  PVR', skipOffstage: false), findsOneWidget);

    reservation.setToAirport(
      0,
      _airport('Cancun', 'MMUN', 'CUN', lat: 21.0365, lng: -86.8771),
    );
    reservation.setStartDate(0, DateTime(2026, 10, 18, 15));
    reservation.setGlobalPassengers(5);
    await tester.pump();

    expect(find.text('5 pax'), findsOneWidget);
    expect(find.text('18 oct 26'), findsOneWidget);
    expect(find.text('TLC  →  CUN', skipOffstage: false), findsOneWidget);
    expect(find.text('TLC  →  PVR', skipOffstage: false), findsNothing);
    reservation.setBookingTripLabel('Multidestino');
    await tester.pump();
    expect(find.text('Multi'), findsOneWidget);
    expect(tester.takeException(), isNull);

    reservation.routes = [
      _route(
        _airport('Cancun', 'MMUN', 'CUN', lat: 21.0365, lng: -86.8771),
        _airport('Toluca', 'MMTO', 'TLC'),
      ),
      _route(
        _airport('Toluca', 'MMTO', 'TLC'),
        _airport('Puerto Vallarta', 'MMPR', 'PVR'),
      ),
    ];
    reservation.notifyListeners();
    await tester.pump();

    final firstLegY =
        tester.getTopLeft(find.text('CUN  →  TLC', skipOffstage: false)).dy;
    final secondLegY =
        tester.getTopLeft(find.text('TLC  →  PVR', skipOffstage: false)).dy;
    expect(firstLegY, lessThan(secondLegY));
    expect(tester.takeException(), isNull);
  });

  testWidgets('metric band stays one row and scrolls for large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reservation =
        ReservationProvider()
          ..bookingTripLabel = 'Multidestino'
          ..routes = [
            _route(
              _airport('Toluca', 'MMTO', 'TLC'),
              _airport('Puerto Vallarta', 'MMPR', 'PVR'),
            ),
          ];
    addTearDown(reservation.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ReservationProvider>.value(
        value: reservation,
        child: MaterialApp(
          home: Builder(
            builder:
                (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(1.5)),
                  child: const ItinerarySummaryScreen(
                    tripType: 'Multidestino',
                    enableMapVectorProvider: false,
                    onRequestQuote: _noop,
                    onEditLeg: _noopIndex,
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('summary-metrics-scroll')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('summary-metric-mode')), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-metric-legs')), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-metric-date')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('summary-metric-passengers')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows compact map state for missing coordinates', (
    tester,
  ) async {
    final reservation = _reservationWithQuote();
    addTearDown(reservation.dispose);
    reservation.routes = [
      _route(
        _airport('Sin coordenadas', 'MMNA', r'\N', lat: 0, lng: 0),
        _airport('Toluca', 'MMTO', 'TLC'),
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<ReservationProvider>.value(
        value: reservation,
        child: const MaterialApp(
          home: QuotePreviewScreen(enableMapVectorProvider: false),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('1 tramo sin coordenadas'), findsOneWidget);
    expect(find.text('TLC'), findsNothing);
  });

  testWidgets('map rendering keeps backend legs payload intact', (
    tester,
  ) async {
    final reservation = _reservationWithQuote();
    addTearDown(reservation.dispose);
    reservation.routes = [
      _route(
        _airport('Toluca', 'MMTO', 'TLC'),
        _airport('Puerto Vallarta', 'MMPR', 'PVR'),
      ),
    ];
    final before = reservation.buildLegsPayload();

    await tester.pumpWidget(
      ChangeNotifierProvider<ReservationProvider>.value(
        value: reservation,
        child: const MaterialApp(
          home: QuotePreviewScreen(enableMapVectorProvider: false),
        ),
      ),
    );
    await tester.pump();

    expect(reservation.buildLegsPayload(), before);
  });
}

void _noop() {}

void _noopIndex(int _) {}

ReservationProvider _reservationWithQuote() {
  final reservation = ReservationProvider();
  reservation.selectedQuoteMatch = {
    'id': 'match-preview-map',
    'match_id': 'match-preview-map',
    'aircraft_name': 'LEARJET 45',
    'time': '1 h 20 min',
    'pricing': {'total_amount': 12000},
    'pricing_breakdown': {'final_billable_hours': 1.33},
  };
  return reservation;
}

RouteModel _route(Airport from, Airport to) => RouteModel(
  fromAirport: from,
  toAirport: to,
  startDate: DateTime(2026, 10, 13, 9),
);

Airport _airport(
  String city,
  String icao,
  String iata, {
  double lat = 19.3371,
  double lng = -99.566,
}) => Airport(
  id: city.hashCode,
  name: '$city Airport',
  city: city,
  icao: icao,
  iata: iata,
  country: 'Mexico',
  lat: lat,
  lng: lng,
);
