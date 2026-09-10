import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/core/cliente_api.dart';
import 'package:red_sky/screens/sobrecargo/crew_evidence.dart';

// Run with the isolated backend fixture and media server described in the report.
const fixturePath = String.fromEnvironment('POSTFLIGHT_FIXTURE');

void main() {
  testWidgets(
    'backend uploads render all slots, viewer and reopen with real image bytes',
    (tester) async {
      final fixture =
          jsonDecode(File(fixturePath).readAsStringSync())
              as Map<String, dynamic>;
      final snapshots = fixture['snapshots'] as List;
      HttpOverrides.global = null;
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var workflow = Map<String, dynamic>.from(snapshots[0]['mobile']);
      final api = ApiClient.forTesting(
        baseUrl: 'https://example.test/api/v1',
        httpClient: http.Client(),
      );
      Future<void> settleImages() async {
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(
            () async => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
        }
      }

      Future<void> mount() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CrewEvidencePanel(
                  workflow: workflow,
                  operationId: '${workflow['operation_id']}',
                  api: api,
                  reload: () async => workflow,
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await settleImages();
      }

      for (var count = 0; count <= 3; count++) {
        workflow = Map<String, dynamic>.from(snapshots[count]['mobile']);
        await mount();
        expect(find.text('$count/3'), findsOneWidget);
        expect(crewEvidenceCount(workflow), count);
        for (final slot in crewEvidenceSlots(
          workflow,
        ).where((s) => s.persisted)) {
          final card = find.byKey(ValueKey('evidence-card-${slot.code}'));
          await tester.ensureVisible(card);
          await settleImages();
          expect(
            find.descendant(of: card, matching: find.text('Completado')),
            findsOneWidget,
          );
          final button = find.descendant(
            of: card,
            matching: find.text('Ver evidencia'),
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.runAsync(
            () async => Future<void>.delayed(const Duration(milliseconds: 300)),
          );
          await settleImages();
          expect(find.byType(Dialog), findsOneWidget);
          final image = tester.widget<RawImage>(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(RawImage),
                )
                .first,
          );
          expect(image.image, isNotNull);
          expect(image.image!.width, greaterThan(0));
          await tester.tap(find.text('Cerrar'));
          await settleImages();
          expect(find.byType(Dialog), findsNothing);
        }
      }
      await tester.pumpWidget(const SizedBox());
      await mount();
      expect(find.text('3/3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    skip: fixturePath.isEmpty,
  );
}
