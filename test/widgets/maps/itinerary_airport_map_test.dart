import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/models/aeropuerto.dart';
import 'package:red_sky/models/modelo_ruta.dart';
import 'package:red_sky/widgets/maps/itinerary_airport_map.dart';
import 'package:red_sky/widgets/maps/itinerary_map_models.dart';

void main() {
  group('ItineraryMapData', () {
    test('one way creates one leg and two airports', () {
      final data = buildItineraryMapDataForTest([_route(_tlc(), _pvr())]);

      expect(data.legs, hasLength(1));
      expect(data.airports, hasLength(2));
    });

    test('round trip preserves two opposite legs', () {
      final data = buildItineraryMapDataForTest([
        _route(_tlc(), _pvr()),
        _route(_pvr(), _tlc()),
      ]);

      expect(data.legs, hasLength(2));
      expect(data.legs.last.isReverseDuplicate, isTrue);
      expect(data.legs.first.points[1], isNot(data.legs.last.points[1]));
      expect(data.airports, hasLength(2));
    });

    test('multi destination preserves ordered legs', () {
      final data = buildItineraryMapDataForTest([
        _route(_tlc(), _pvr()),
        _route(_pvr(), _mlm()),
        _route(_mlm(), _cun()),
      ]);

      expect(data.legs.map((leg) => leg.origin.code), ['TLC', 'PVR', 'MLM']);
      expect(data.legs.map((leg) => leg.destination.code), [
        'PVR',
        'MLM',
        'CUN',
      ]);
    });

    test('four requested legs remain four separate polylines', () {
      final data = buildItineraryMapDataForTest([
        _route(_tlc(), _pvr()),
        _route(_pvr(), _tlc()),
        _route(_tlc(), _mlm()),
        _route(_mlm(), _tlc()),
      ]);

      expect(data.legs, hasLength(4));
    });

    test('projects TLC, CUN, MLM and return as three requested legs', () {
      final catalog = [_tlc(), _cun(), _mlm()];
      final incompleteRoutes = [
        _route(_withoutCoordinates(_tlc()), _withoutCoordinates(_cun())),
        _route(_withoutCoordinates(_cun()), _withoutCoordinates(_mlm())),
        _route(_withoutCoordinates(_mlm()), _withoutCoordinates(_tlc())),
      ];

      final data = buildItineraryMapDataForTest(
        incompleteRoutes,
        airportCatalog: catalog,
      );

      expect(data.invalidLegCount, 0);
      expect(data.legs, hasLength(3));
      expect(data.airports.map((airport) => airport.code), [
        'TLC',
        'CUN',
        'MLM',
      ]);
      expect(
        data.legs.map((leg) => '${leg.origin.code}>${leg.destination.code}'),
        ['TLC>CUN', 'CUN>MLM', 'MLM>TLC'],
      );
    });

    test(
      'retains five or more requested legs and deduplicates markers only',
      () {
        final data = buildItineraryMapDataForTest([
          _route(_tlc(), _pvr()),
          _route(_pvr(), _mlm()),
          _route(_mlm(), _cun()),
          _route(_cun(), _tlc()),
          _route(_tlc(), _pvr()),
        ]);

        expect(data.legs, hasLength(5));
        expect(data.airports, hasLength(4));
      },
    );

    test('uses ID before codes when resolving missing route coordinates', () {
      final routeAirport = Airport(
        id: 2,
        name: 'Selected',
        city: 'Selected',
        iata: 'CUN',
        icao: 'MMUN',
        lat: 0,
        lng: 0,
      );
      final catalogAirport = Airport(
        id: 2,
        name: 'Catalog Toluca',
        city: 'Toluca',
        iata: 'TLC',
        icao: 'MMTO',
        lat: 19.3371,
        lng: -99.566,
      );

      final data = buildItineraryMapDataForTest(
        [_route(routeAirport, _pvr())],
        airportCatalog: [catalogAirport],
      );

      expect(data.invalidLegCount, 0);
      expect(data.legs.first.origin.code, 'TLC');
      expect(data.legs.first.origin.position.latitude, 19.3371);
    });

    test('matches ICAO only to ICAO and does not use a conflicting IATA', () {
      final selected = Airport(
        name: 'Selected',
        city: 'Selected',
        iata: 'ABQ',
        icao: 'MMUN',
        lat: 0,
        lng: 0,
      );
      final wrongIata = Airport(
        id: 80,
        name: 'Wrong airport',
        city: 'Wrong',
        iata: 'MMUN',
        icao: 'KMMU',
        lat: 40,
        lng: -100,
      );
      final rightIcao = Airport(
        id: 81,
        name: 'Cancun',
        city: 'Cancun',
        iata: 'CUN',
        icao: 'MMUN',
        lat: 21.0365,
        lng: -86.8771,
      );

      final data = buildItineraryMapDataForTest(
        [_route(selected, _tlc())],
        airportCatalog: [wrongIata, rightIcao],
      );

      expect(data.invalidLegCount, 0);
      expect(data.legs.first.origin.code, 'CUN');
      expect(data.legs.first.origin.position.latitude, 21.0365);
    });

    test('does not resolve an ambiguous IATA match', () {
      final selected = Airport(
        name: 'Unknown airport',
        city: 'Unknown',
        iata: 'CUN',
        lat: 0,
        lng: 0,
      );
      final catalog = [
        _cun(),
        Airport(
          id: 90,
          name: 'Different airport',
          city: 'Different',
          iata: 'CUN',
          icao: 'KXYZ',
          lat: 20,
          lng: -80,
        ),
      ];

      final data = buildItineraryMapDataForTest([
        _route(selected, _tlc()),
      ], airportCatalog: catalog);

      expect(data.invalidLegCount, 1);
      expect(data.legs, isEmpty);
    });

    test('uses a unique IATA only when ICAO cannot identify the airport', () {
      final selected = Airport(
        name: 'Unknown airport',
        city: 'Unknown',
        iata: 'CUN',
        icao: r'\N',
        lat: 0,
        lng: 0,
      );

      final data = buildItineraryMapDataForTest(
        [_route(selected, _tlc())],
        airportCatalog: [_cun()],
      );

      expect(data.invalidLegCount, 0);
      expect(data.legs.first.origin.code, 'CUN');
    });

    test('repeated airport is deduplicated by identity', () {
      final data = buildItineraryMapDataForTest([
        _route(_tlc(), _pvr()),
        _route(_tlc(), _mlm()),
      ]);

      expect(
        data.airports.where((airport) => airport.code == 'TLC'),
        hasLength(1),
      );
    });

    test(r'IATA \N falls back to ICAO', () {
      final data = buildItineraryMapDataForTest([
        _route(_privateNoIata(), _tlc()),
      ]);

      expect(data.airports.first.code, 'MMPR');
    });

    test('invalid coordinates omit only invalid leg', () {
      final data = buildItineraryMapDataForTest([
        _route(_invalid(), _tlc()),
        _route(_tlc(), _pvr()),
      ]);

      expect(data.invalidLegCount, 1);
      expect(data.legs, hasLength(1));
    });

    test('destination edit changes projection', () {
      final original = buildItineraryMapDataForTest([_route(_tlc(), _pvr())]);
      final edited = buildItineraryMapDataForTest([_route(_tlc(), _mlm())]);

      expect(original.legs.first.destination.code, 'PVR');
      expect(edited.legs.first.destination.code, 'MLM');
    });

    test('deleted leg is removed from projection', () {
      final data = buildItineraryMapDataForTest([_route(_tlc(), _pvr())]);

      expect(data.legs, hasLength(1));
    });

    test('opposite lines are detected for direction handling', () {
      final data = buildItineraryMapDataForTest([
        _route(_tlc(), _pvr()),
        _route(_pvr(), _tlc()),
      ]);

      expect(data.legs.last.isReverseDuplicate, isTrue);
    });
  });

  testWidgets('renders markers and directional arrows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItineraryAirportMap(
            routes: [_route(_tlc(), _pvr()), _route(_pvr(), _tlc())],
            enableVectorProvider: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('TLC'), findsOneWidget);
    expect(find.text('PVR'), findsOneWidget);
    expect(find.byKey(const ValueKey('direction-marker-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('direction-marker-1')), findsOneWidget);
  });

  testWidgets(
    'renders three resolved legs without a missing-coordinate warning',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryAirportMap(
              routes: [
                _route(
                  _withoutCoordinates(_tlc()),
                  _withoutCoordinates(_cun()),
                ),
                _route(
                  _withoutCoordinates(_cun()),
                  _withoutCoordinates(_mlm()),
                ),
                _route(
                  _withoutCoordinates(_mlm()),
                  _withoutCoordinates(_tlc()),
                ),
              ],
              airportCatalog: [_tlc(), _cun(), _mlm()],
              enableVectorProvider: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('TLC'), findsOneWidget);
      expect(find.text('CUN'), findsOneWidget);
      expect(find.text('MLM'), findsOneWidget);
      expect(find.byKey(const ValueKey('direction-marker-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('direction-marker-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('direction-marker-2')), findsOneWidget);
      expect(find.textContaining('sin coordenadas'), findsNothing);
      expect(
        find.text('Selecciona tus aeropuertos para visualizar el recorrido.'),
        findsNothing,
      );
    },
  );

  testWidgets('updates widget when destination changes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItineraryAirportMap(
            routes: [_route(_tlc(), _pvr())],
            enableVectorProvider: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('PVR'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItineraryAirportMap(
            routes: [_route(_tlc(), _mlm())],
            enableVectorProvider: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('PVR'), findsNothing);
    expect(find.text('MLM'), findsOneWidget);
  });

  testWidgets('allows panning the itinerary map', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItineraryAirportMap(
            routes: [_route(_tlc(), _pvr())],
            enableVectorProvider: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mapFinder = find.byType(FlutterMap);
    final map = tester.widget<FlutterMap>(mapFinder);
    final initialCenter = map.mapController!.camera.center;
    await tester.drag(mapFinder, const Offset(80, 40));
    await tester.pumpAndSettle();

    expect(map.mapController!.camera.center, isNot(initialCenter));
  });

  testWidgets('keeps pinch-to-zoom gestures active', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItineraryAirportMap(
            routes: [_route(_tlc(), _pvr())],
            enableVectorProvider: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mapFinder = find.byType(FlutterMap);
    final mapRect = tester.getRect(mapFinder);
    final controller = tester.widget<FlutterMap>(mapFinder).mapController!;
    final initialZoom = controller.camera.zoom;
    final center = mapRect.center;
    final firstFinger = await tester.startGesture(
      center.translate(-35, 0),
      pointer: 1,
    );
    final secondFinger = await tester.startGesture(
      center.translate(35, 0),
      pointer: 2,
    );
    await firstFinger.moveTo(center.translate(-65, 0));
    await secondFinger.moveTo(center.translate(65, 0));
    await tester.pumpAndSettle();
    await firstFinger.up();
    await secondFinger.up();
    await tester.pumpAndSettle();

    expect(controller.camera.zoom, greaterThan(initialZoom));
  });

  testWidgets('map controls zoom in, zoom out, and recenter the route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItineraryAirportMap(
            routes: [_route(_tlc(), _pvr())],
            enableVectorProvider: false,
            showControls: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mapFinder = find.byType(FlutterMap);
    final controller = tester.widget<FlutterMap>(mapFinder).mapController!;
    final initialZoom = controller.camera.zoom;
    final initialCenter = controller.camera.center;

    final zoomInButton = find.descendant(
      of: find.byKey(const ValueKey('map-zoom-in')),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(zoomInButton).onPressed, isNotNull);
    await tester.tap(zoomInButton);
    await tester.pumpAndSettle();
    expect(controller.camera.zoom, greaterThan(initialZoom));

    await tester.tap(find.byKey(const ValueKey('map-zoom-out')));
    await tester.pumpAndSettle();
    expect(controller.camera.zoom, closeTo(initialZoom, .05));

    await tester.drag(mapFinder, const Offset(80, 40));
    await tester.pumpAndSettle();
    expect(controller.camera.center, isNot(initialCenter));

    await tester.tap(find.byKey(const ValueKey('map-center-route')));
    await tester.pumpAndSettle();
    expect(
      controller.camera.center.latitude,
      closeTo(initialCenter.latitude, .1),
    );
    expect(
      controller.camera.center.longitude,
      closeTo(initialCenter.longitude, .1),
    );
    expect(controller.camera.zoom, closeTo(initialZoom, .1));
    expect(find.byTooltip('Acercar mapa'), findsOneWidget);
    expect(find.byTooltip('Alejar mapa'), findsOneWidget);
    expect(find.byTooltip('Centrar recorrido'), findsOneWidget);

    final zoomOutButton = find.descendant(
      of: find.byKey(const ValueKey('map-zoom-out')),
      matching: find.byType(IconButton),
    );
    for (var attempt = 0; attempt < 24; attempt++) {
      if (tester.widget<IconButton>(zoomInButton).onPressed == null) break;
      await tester.tap(zoomInButton);
      await tester.pumpAndSettle();
    }
    expect(tester.widget<IconButton>(zoomInButton).onPressed, isNull);

    for (var attempt = 0; attempt < 24; attempt++) {
      if (tester.widget<IconButton>(zoomOutButton).onPressed == null) break;
      await tester.tap(zoomOutButton);
      await tester.pumpAndSettle();
    }
    expect(tester.widget<IconButton>(zoomOutButton).onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shows invalid coordinate warning without blocking valid markers',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryAirportMap(
              routes: [_route(_invalid(), _tlc()), _route(_tlc(), _pvr())],
              enableVectorProvider: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('1 tramo sin coordenadas'), findsOneWidget);
      expect(find.text('TLC'), findsOneWidget);
      expect(find.text('PVR'), findsOneWidget);
    },
  );

  testWidgets('shows compact guidance for an empty itinerary', (tester) async {
    final data = buildItineraryMapDataForTest([RouteModel()]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItineraryAirportMap(
            routes: [RouteModel()],
            enableVectorProvider: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Selecciona tus aeropuertos para visualizar el recorrido.'),
      findsOneWidget,
    );
    expect(data.invalidLegCount, 0);
  });
}

RouteModel _route(Airport from, Airport to) => RouteModel(
  fromAirport: from,
  toAirport: to,
  startDate: DateTime(2026, 10, 13, 9),
);

Airport _airport({
  required int id,
  required String city,
  required String iata,
  required String icao,
  required double lat,
  required double lng,
}) => Airport(
  id: id,
  name: '$city Airport',
  city: city,
  iata: iata,
  icao: icao,
  country: 'Mexico',
  lat: lat,
  lng: lng,
);

Airport _tlc() => _airport(
  id: 1,
  city: 'Toluca',
  iata: 'TLC',
  icao: 'MMTO',
  lat: 19.3371,
  lng: -99.566,
);

Airport _pvr() => _airport(
  id: 2,
  city: 'Puerto Vallarta',
  iata: 'PVR',
  icao: 'MMPR',
  lat: 20.6801,
  lng: -105.254,
);

Airport _mlm() => _airport(
  id: 3,
  city: 'Morelia',
  iata: 'MLM',
  icao: 'MMMM',
  lat: 19.8499,
  lng: -101.025,
);

Airport _cun() => _airport(
  id: 4,
  city: 'Cancun',
  iata: 'CUN',
  icao: 'MMUN',
  lat: 21.0365,
  lng: -86.8771,
);

Airport _privateNoIata() => _airport(
  id: 5,
  city: 'Private',
  iata: r'\N',
  icao: 'MMPR',
  lat: 20.68,
  lng: -105.25,
);

Airport _invalid() =>
    _airport(id: 6, city: 'Invalid', iata: 'BAD', icao: 'MMBD', lat: 0, lng: 0);

Airport _withoutCoordinates(Airport airport) => Airport(
  id: airport.id,
  name: airport.name,
  city: airport.city,
  state: airport.state,
  iata: airport.iata,
  icao: airport.icao,
  country: airport.country,
  hasCoordinateValues: false,
  lat: 0,
  lng: 0,
);
