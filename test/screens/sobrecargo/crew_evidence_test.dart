import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:red_sky/core/cliente_api.dart';
import 'package:red_sky/screens/sobrecargo/crew_evidence.dart';
import 'package:red_sky/screens/sobrecargo/crew_operation_flow.dart';

Map<String, dynamic> payload(
  int count, {
  bool editable = true,
  String path = 'old.jpg',
}) => {
  'current_step': 'closure',
  'status': 'report_pending',
  'editable_evidence': editable ? crewEvidenceLabels.keys.toList() : [],
  'editable_checklists': [],
  'checklists': [
    for (var i = 0; i < 3; i++)
      {
        'type': i < 2 ? 'preflight' : 'postflight',
        'items': [
          {
            'id': 41 + i * 7,
            'code': crewEvidenceLabels.keys.elementAt(i),
            'evidence_files':
                i < count
                    ? [
                      {
                        'storage_disk': 's3',
                        'file_path': path,
                        'file_url': 'https://example.test/$path',
                        'size': 100,
                      },
                    ]
                    : null,
          },
        ],
      },
  ],
};

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('crew-evidence-test');
    file = File('${directory.path}/photo.jpg');
    await file.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
      ),
    );
  });
  tearDown(() async => directory.delete(recursive: true));

  test('preserves Laravel null, empty lists and metadata', () {
    final workflow = payload(1);
    expect(crewEvidenceSlots(workflow).first.files.single['size'], 100);
    expect(crewEvidenceSlots(workflow).last.files, isEmpty);
    (workflow['checklists'] as List)[0]['items'][0]['evidence_files'] = [];
    expect(crewEvidenceCount(workflow), 0);
  });
  for (var count = 0; count <= 3; count++) {
    test('counts $count/3 from backend files only', () {
      expect(crewEvidenceCount(payload(count)), count);
    });
  }
  test(
    'report_pending obeys evidence permission without reopening answers',
    () {
      final workflow = payload(0);
      expect(
        crewEvidenceEditable(workflow, crewEvidenceSlots(workflow).first),
        isTrue,
      );
      workflow['editable_evidence'] = [];
      expect(
        crewEvidenceEditable(workflow, crewEvidenceSlots(workflow).first),
        isFalse,
      );
      expect(workflow['editable_checklists'], isEmpty);
    },
  );

  Future<void> mount(
    WidgetTester tester, {
    required Map<String, dynamic> workflow,
    required ApiClient api,
    required Future<Map<String, dynamic>> Function() reload,
    Key? panelKey,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CrewEvidencePanel(
              key: panelKey,
              workflow: workflow,
              operationId: '907',
              api: api,
              reload: reload,
              pickImage: (_) async => XFile(file.path),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('evidence grid switches columns at responsive breakpoints', (
    tester,
  ) async {
    final sizes = <Size, int>{
      const Size(1440, 900): 2,
      const Size(1024, 900): 1,
      const Size(390, 844): 1,
    };
    for (final entry in sizes.entries) {
      tester.view.physicalSize = entry.key;
      tester.view.devicePixelRatio = 1;
      await mount(
        tester,
        workflow: payload(0),
        api: ApiClient.forTesting(
          baseUrl: 'https://example.test/api/v1',
          httpClient: MockClient((_) async => http.Response('{}', 201)),
        ),
        reload: () async => payload(0),
      );
      final grid = tester.widget<GridView>(
        find.byKey(const ValueKey('evidence-grid')),
      );
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, entry.value);
      expect(tester.takeException(), isNull);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets(
    'local preview stays 0/3; 201 triggers refresh; reopen uses backend',
    (tester) async {
      var workflow = payload(0);
      final events = <String>[];
      final api = ApiClient.forTesting(
        baseUrl: 'https://example.test/api/v1',
        httpClient: MockClient((request) async {
          events.add(request.method);
          if (request.method == 'POST') {
            expect(
              request.url.path,
              '/api/v1/sobrecargo/operations/907/checklists/preflight/items/41/evidence',
            );
            expect(request.headers['authorization'], 'Bearer test-token');
            expect(request.headers['accept'], 'application/json');
            expect(
              request.headers['content-type'],
              startsWith('multipart/form-data; boundary='),
            );
            final body = latin1.decode(request.bodyBytes);
            expect(body, contains('name="file"'));
            expect(body, contains('filename="photo.png"'));
            expect(body, contains('image/png'));
            expect(body, contains(latin1.decode(file.readAsBytesSync())));
            return http.Response('{}', 201);
          }
          return http.Response(jsonEncode({'data': payload(1)}), 200);
        }),
      );
      api.setToken('test-token');
      Future<Map<String, dynamic>> reload() async {
        final response = await api.getCrewOperationWorkflow('907');
        workflow = Map<String, dynamic>.from(response['data']);
        return workflow;
      }

      await mount(tester, workflow: workflow, api: api, reload: reload);
      await tester.tap(find.text('Galería').first);
      await tester.pumpAndSettle();
      expect(find.text('Pendiente de subir'), findsOneWidget);
      expect(find.byKey(const ValueKey('pending-41')), findsOneWidget);
      expect(find.text('Evidencias para el cierre'), findsOneWidget);
      expect(find.text('0/3'), findsOneWidget);
      expect(events, isEmpty);
      await tester.runAsync(() async {
        await tester.tap(find.text('Subir evidencia'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(events, ['POST', 'GET']);
      await mount(tester, workflow: workflow, api: api, reload: reload);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.byKey(const ValueKey('pending-41')), findsNothing);
      expect(find.byKey(const ValueKey('saved-41-old.jpg')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await mount(tester, workflow: payload(1), api: api, reload: reload);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.byKey(const ValueKey('saved-41-old.jpg')), findsOneWidget);
    },
  );

  testWidgets(
    'replacement keeps saved photo until upload and refresh complete',
    (tester) async {
      final refreshed = Completer<Map<String, dynamic>>();
      final api = ApiClient.forTesting(
        baseUrl: 'https://example.test/api/v1',
        httpClient: MockClient((_) async => http.Response('{}', 201)),
      );
      await mount(
        tester,
        workflow: payload(1),
        api: api,
        reload: () => refreshed.future,
      );
      await tester.tap(find.text('Galería').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Subir evidencia'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Subir evidencia'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(find.byKey(const ValueKey('saved-41-old.jpg')), findsOneWidget);
      expect(find.byKey(const ValueKey('pending-41')), findsOneWidget);
      refreshed.complete(payload(1, path: 'new.jpg'));
      await tester.pumpAndSettle();
      await mount(
        tester,
        workflow: payload(1, path: 'new.jpg'),
        api: api,
        reload: () async => payload(1),
      );
      expect(find.byKey(const ValueKey('saved-41-new.jpg')), findsOneWidget);
      expect(find.byKey(const ValueKey('pending-41')), findsNothing);
    },
  );

  testWidgets('201 plus failed refresh does not announce success', (
    tester,
  ) async {
    final api = ApiClient.forTesting(
      baseUrl: 'https://example.test/api/v1',
      httpClient: MockClient((_) async => http.Response('{}', 201)),
    );
    await mount(
      tester,
      workflow: payload(0),
      api: api,
      reload: () async => throw Exception('Sin conexión'),
    );
    await tester.tap(find.text('Galería').first);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Subir evidencia'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('no se pudo confirmar'), findsOneWidget);
    expect(find.text('Evidencia registrada'), findsNothing);
    expect(find.text('0/3'), findsOneWidget);
    expect(find.text('Pendiente de subir'), findsOneWidget);
  });

  for (final status in [400, 401, 403, 409, 422, 500]) {
    testWidgets(
      '$status preserves pending photo and never displays internal backend details',
      (tester) async {
        var reloads = 0;
        final api = ApiClient.forTesting(
          baseUrl: 'https://example.test/api/v1',
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'message':
                    'SQLSTATE postgres SQL: Host: Database: /private/backend $status',
              }),
              status,
            ),
          ),
        );
        await mount(
          tester,
          workflow: payload(2),
          api: api,
          reload: () async {
            reloads++;
            return payload(3);
          },
        );
        await tester.tap(find.text('Galería').first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Subir evidencia'));
        await tester.runAsync(() async {
          await tester.tap(find.text('Subir evidencia'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();
        expect(
          find.text('No fue posible subir la evidencia. Intenta nuevamente.'),
          findsOneWidget,
        );
        expect(find.textContaining('SQLSTATE'), findsNothing);
        expect(find.byKey(const ValueKey('pending-41')), findsOneWidget);
        expect(find.text('2/3'), findsOneWidget);
        expect(reloads, 0);
      },
    );
  }

  test('2/3 cannot close postflight when backend returns 409', () async {
    final workflow = payload(2)..addAll({
      'current_step': 'postflight',
      'workflow_inconsistent': true,
      'blocking_reason': 'Debes subir las 3 evidencias',
      'next_action': null,
      'allowed_actions': [],
    });
    final flow = CrewOperationFlowSnapshot.fromPayload(
      workflow: workflow,
      canRespondToAssignment: false,
    );
    expect(flow.primaryAction.kind, 'blocked');
    expect(flow.blockingReason, 'Debes subir las 3 evidencias');
    final api = ApiClient.forTesting(
      baseUrl: 'https://example.test/api/v1',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Debes subir las 3 evidencias'}),
          409,
        ),
      ),
    );
    await expectLater(
      api.updateCrewChecklistItem(
        operationId: '907',
        checklistType: 'postflight',
        itemId: '55',
        status: 'completed',
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', 409)
            .having(
              (e) => e.message,
              'message',
              'Debes subir las 3 evidencias',
            ),
      ),
    );
    expect(crewEvidenceCount(workflow), 2);
  });

  testWidgets('preflight only permits backend-authorized evidence slots', (
    tester,
  ) async {
    final workflow = payload(0)
      ..['editable_evidence'] = ['catering_received', 'baggage_secured'];
    final api = ApiClient.forTesting(
      baseUrl: 'https://example.test/api/v1',
      httpClient: MockClient((_) async => http.Response('{}', 201)),
    );
    await mount(
      tester,
      workflow: workflow,
      api: api,
      reload: () async => workflow,
    );
    final buttons =
        tester.widgetList<OutlinedButton>(find.byType(OutlinedButton)).toList();
    expect(buttons.take(4).every((button) => button.onPressed != null), isTrue);
    expect(buttons.skip(4).every((button) => button.onPressed == null), isTrue);
  });

  testWidgets('replacement rejects stale workflow after 201', (tester) async {
    final api = ApiClient.forTesting(
      baseUrl: 'https://example.test/api/v1',
      httpClient: MockClient((_) async => http.Response('{}', 201)),
    );
    await mount(
      tester,
      workflow: payload(1),
      api: api,
      reload: () async => payload(1),
    );
    await tester.tap(find.text('Galería').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Subir evidencia'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Subir evidencia'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('no se pudo confirmar'), findsOneWidget);
    expect(find.byKey(const ValueKey('saved-41-old.jpg')), findsOneWidget);
    expect(find.byKey(const ValueKey('pending-41')), findsOneWidget);
  });

  test('connection failure returns actionable error', () async {
    final api = ApiClient.forTesting(
      baseUrl: 'https://example.test/api/v1',
      httpClient: MockClient(
        (_) async => throw const SocketException('Offline'),
      ),
    );
    await expectLater(
      api.uploadCrewChecklistEvidence(
        operationId: '907',
        checklistType: 'postflight',
        itemId: '55',
        file: file,
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Revisa tu conexión'),
        ),
      ),
    );
  });

  test('Cabina uses real postflight item id and file multipart', () async {
    final api = ApiClient.forTesting(
      baseUrl: 'https://example.test/api/v1',
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/sobrecargo/operations/907/checklists/postflight/items/55/evidence',
        );
        expect(latin1.decode(request.bodyBytes), contains('name="file"'));
        return http.Response('{}', 201);
      }),
    );
    final slot = crewEvidenceSlots(payload(0)).last;
    await api.uploadCrewChecklistEvidence(
      operationId: '907',
      checklistType: slot.type,
      itemId: slot.id,
      file: file,
    );
  });
  test('HEIC bytes are rejected instead of relabeled JPEG', () async {
    await file.writeAsBytes(latin1.encode('0000ftypheic'));
    final api = ApiClient.forTesting(
      baseUrl: 'https://example.test/api/v1',
      httpClient: MockClient((_) async => throw StateError('Must not upload')),
    );
    await expectLater(
      api.uploadCrewChecklistEvidence(
        operationId: '907',
        checklistType: 'postflight',
        itemId: '55',
        file: file,
      ),
      throwsA(isA<ApiException>()),
    );
  });
}
