import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:red_sky/core/cliente_api.dart';

void main() {
  group('Crew canonical API contracts', () {
    test('loads workflow from canonical operation endpoint', () async {
      late http.Request request;
      final api = ApiClient.forTesting(
        baseUrl: 'https://api.example.test/api/v1',
        httpClient: MockClient((value) async {
          request = value;
          return http.Response(
            jsonEncode({'operation_id': 9, 'crew_status': 'checked_in'}),
            200,
          );
        }),
      );
      await api.getCrewOperationWorkflow('9');
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/sobrecargo/operations/9/workflow');
    });

    test('persists checklist item through canonical endpoint', () async {
      late http.Request request;
      final api = ApiClient.forTesting(
        baseUrl: 'https://api.example.test/api/v1',
        httpClient: MockClient((value) async {
          request = value;
          return http.Response(
            jsonEncode({
              'checklist': {'id': 3},
            }),
            200,
          );
        }),
      );
      await api.updateCrewChecklistItem(
        operationId: '9',
        checklistType: 'preflight',
        itemId: '14',
        status: 'completed',
        notes: 'Verificado',
      );
      expect(request.method, 'PUT');
      expect(
        request.url.path,
        '/api/v1/sobrecargo/operations/9/checklists/preflight/items/14',
      );
      expect(jsonDecode(request.body)['status'], 'completed');
    });

    test('checkin sends backend-required fit_to_operate', () async {
      late http.Request request;
      final api = ApiClient.forTesting(
        baseUrl: 'https://api.example.test/api/v1',
        httpClient: MockClient((value) async {
          request = value;
          return http.Response('{}', 200);
        }),
      );
      await api.updateCrewOperationStep(assignmentId: '9', step: 'checkin');
      expect(request.url.path, '/api/v1/sobrecargo/operations/9/checkin');
      expect(jsonDecode(request.body)['fit_to_operate'], isTrue);
    });

    test('final report uses canonical report endpoint', () async {
      late http.Request request;
      final api = ApiClient.forTesting(
        baseUrl: 'https://api.example.test/api/v1',
        httpClient: MockClient((value) async {
          request = value;
          return http.Response('{}', 201);
        }),
      );
      await api.submitCrewFinalReport(
        operationId: '9',
        report: const {
          'service_rating': 5,
          'cabin_condition': 'Correcta',
          'catering_condition': 'Correcta',
          'cleaning_required': false,
          'restocking_required': false,
        },
      );
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/sobrecargo/operations/9/report');
    });

    test('uploads checklist evidence to canonical Laravel endpoint', () async {
      late http.Request request;
      final api = ApiClient.forTesting(
        baseUrl: 'https://api.example.test/api/v1',
        httpClient: MockClient((value) async {
          request = value;
          return http.Response(
            jsonEncode({
              'evidence': {'id': 21},
            }),
            201,
          );
        }),
      );
      final directory = await Directory.systemTemp.createTemp(
        'crew-evidence-contract-',
      );
      final evidence = File('${directory.path}/cabin.jpg');
      await evidence.writeAsBytes(const [0xFF, 0xD8, 0xFF, 0xD9]);
      addTearDown(() => directory.delete(recursive: true));

      await api.uploadCrewChecklistEvidence(
        operationId: '9',
        checklistType: 'preflight',
        itemId: '14',
        file: evidence,
      );

      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/api/v1/sobrecargo/operations/9/checklists/preflight/items/14/evidence',
      );
    });
  });
}
