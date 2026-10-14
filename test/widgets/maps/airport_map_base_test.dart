import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/core/config/map_config.dart';
import 'package:red_sky/widgets/maps/airport_map_base.dart';

void main() {
  testWidgets('shows loading state while vector style is loading', (
    tester,
  ) async {
    final completer = Completer<vt.Style>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AirportMapBase(styleLoader: () => completer.future),
        ),
      ),
    );

    expect(find.text(MapConfig.loadingMessage), findsOneWidget);
  });

  testWidgets('shows fallback state when vector provider fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AirportMapBase(
            styleLoader: () => Future<Never>.error(Exception('offline')),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(MapConfig.unavailableMessage), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
  });

  testWidgets('renders base map shell when vector provider is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AirportMapBase(enableVectorProvider: false)),
      ),
    );
    await tester.pump();

    expect(find.byType(AirportMapBase), findsOneWidget);
    expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
  });

  testWidgets('does not dispose an unloaded failed style', (tester) async {
    var disposed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AirportMapBase(
            styleLoader:
                () => Future<Never>.error(Exception('no-style-fixture')),
            onStyleDisposed: () => disposed = true,
          ),
        ),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    expect(disposed, isFalse);
  });
}
