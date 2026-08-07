import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/core/billable_hours_formatter.dart';

void main() {
  group('formatBillableHoursLabel', () {
    test(
      'formats backend billable hours exactly as mobile should display them',
      () {
        expect(formatBillableHoursLabel(4.00), '4 h 00 min');
        expect(formatBillableHoursLabel(3.28), '3 h 17 min');
        expect(formatBillableHoursLabel(3.45), '3 h 27 min');
        expect(formatBillableHoursLabel(4.05), '4 h 03 min');
        expect(formatBillableHoursLabel(4.83), '4 h 50 min');
        expect(formatBillableHoursLabel(3.77), '3 h 46 min');
        expect(formatBillableHoursLabel(3.69), '3 h 41 min');
      },
    );

    test('carries 60 rounded minutes into the next hour', () {
      expect(formatBillableHoursLabel(3.999), '4 h 00 min');
    });
  });

  test(
    'extractBackendBillableHours matches the web flow and prefers debug final billable hours first',
    () {
      final quote = <String, dynamic>{
        'billable_hours': 3.25,
        'pricing': {'total_amount': 25000},
        'pricing_breakdown': {'final_billable_hours': 4.0},
        'debug_pricing': {'final_billable_hours': 4.1},
      };

      expect(extractBackendBillableHours(quote), 4.1);
    },
  );

  test(
    'extractBackendBillableHours prefers top-level billable_hours before pricing_breakdown final',
    () {
      final quote = <String, dynamic>{
        'billable_hours': 6.5,
        'pricing': {'total_amount': 25000},
        'pricing_breakdown': {'final_billable_hours': 4.0},
      };

      expect(extractBackendBillableHours(quote), 6.5);
    },
  );

  test(
    'extractBackendBillableHours still falls back to pricing_breakdown final billable hours',
    () {
      final quote = <String, dynamic>{
        'pricing': {'total_amount': 25000},
        'pricing_breakdown': {'final_billable_hours': 4.0},
      };

      expect(extractBackendBillableHours(quote), 4.0);
    },
  );

  test(
    'extractBackendTotalBillableHours prefers total billed hours over final flight base hours',
    () {
      final quote = <String, dynamic>{
        'billable_hours': 3.28,
        'pricing_breakdown': {
          'final_billable_hours': 4.17,
          'billable_hours': 6.1,
        },
      };

      expect(extractBackendTotalBillableHours(quote), 6.1);
    },
  );

  test(
    'extractBackendRouteBillableHours reads route billable hours from backend structures',
    () {
      final quote = <String, dynamic>{
        'pricing_breakdown': {'route_billable_hours': 3.28},
        'pricing': {'total_amount': 47700},
      };

      expect(extractBackendRouteBillableHours(quote), 3.28);
    },
  );

  test('mergeBackendPricingSources preserves the richest backend view', () {
    final quote = <String, dynamic>{
      'pricing': {'total_amount': 47700},
      'pricing_context': {'billable_hours': 6.1},
      'pricing_breakdown': {'final_billable_hours': 4.17},
      'debug_pricing': {'route_billable_hours': 3.28},
    };

    expect(mergeBackendPricingSources(quote), {
      'total_amount': 47700,
      'billable_hours': 6.1,
      'final_billable_hours': 4.17,
      'route_billable_hours': 3.28,
    });
  });

  test('normalizeTimeText accepts backend-supported time formats', () {
    expect(normalizeTimeText('4h'), '4 h 00 min');
    expect(normalizeTimeText('4h 10m'), '4 h 10 min');
    expect(normalizeTimeText('4 h 10 min'), '4 h 10 min');
    expect(normalizeTimeText('04:10'), '4 h 10 min');
  });

  test('visible time uses trip time instead of final billable hours', () {
    final quote = <String, dynamic>{
      'trip_time': '3h 3m',
      'billed_time': '4h',
      'pricing': {'final_billable_hours': 4.0},
    };

    final resolution = resolveQuoteDisplayTime(quote);

    expect(resolution.source, 'trip_time');
    expect(resolution.time, '3 h 03 min');
  });

  test('display route hours take precedence over billable duration', () {
    final quote = <String, dynamic>{
      'trip_time': '3h 3m',
      'pricing_breakdown': {
        'display_route_hours': 2.75,
        'route_billable_hours': 2.75,
        'final_billable_hours': 4.0,
      },
    };

    final resolution = resolveQuoteDisplayTime(quote);

    expect(resolution.source, 'pricing_breakdown.display_route_hours');
    expect(resolution.time, '2 h 45 min');
  });

  test('extractBackendDisplayRouteHours reads official visible route hours', () {
    final quote = <String, dynamic>{
      'pricing': {'display_route_hours': 1.83, 'total_amount': 25000},
    };

    expect(extractBackendDisplayRouteHours(quote), 1.83);
  });

  test('visible time never falls back to minimum billable hours', () {
    final quote = <String, dynamic>{
      'time': '3 h 27 min',
      'card_time': '3 h 27 min',
      'pricing_breakdown': {'final_billable_hours': 4.33},
      'debug_pricing': {'final_billable_hours': 4.333333333333333},
    };

    final resolution = resolveQuoteDisplayTime(quote);

    expect(resolution.source, 'card_time');
    expect(resolution.time, '3 h 27 min');
  });

  test(
    'shouldDisplayBackendBillableHours requires an explicit backend billable-time signal',
    () {
      expect(
        shouldDisplayBackendBillableHours({
          'time': '45 min',
          'pricing': {'billable_hours': 3.25},
        }),
        isFalse,
      );

      expect(
        shouldDisplayBackendBillableHours({
          'pricing_breakdown': {'final_billable_hours': 4.17},
        }),
        isTrue,
      );
    },
  );

  group('dynamic requested-route time', () {
    test('one way sums its only requested leg', () {
      final result = resolveQuoteDisplayTime({
        'legs': [
          {'flight_hours': '0.92'},
        ],
      });
      expect(result.source, 'legs');
      expect(result.time, '55 min');
    });

    test('round trip sums asymmetric legs instead of doubling one leg', () {
      final result = resolveQuoteDisplayTime({
        'segments': [
          {'duration': '55 min'},
          {'duration': '1 h 09 min'},
        ],
        'pricing_breakdown': {'final_billable_hours': 4},
      });
      expect(result.source, 'segments');
      expect(result.time, '2 h 04 min');
    });

    test('multidestination sums every requested leg', () {
      final result = resolveQuoteDisplayTime({
        'routes': [
          {'duration_hours': 0.75},
          {'flight_time': '42 min'},
          {'flight_hours': 1.1},
        ],
      });
      expect(result.source, 'routes');
      expect(result.time, '2 h 33 min');
    });

    test('falls back to calculated backend client legs', () {
      final result = resolveQuoteDisplayTime({
        'pricing_breakdown': {
          'client_legs': [
            {'flight_hours': 0.92, 'flight_minutes': 55},
            {'flight_hours': 0.91, 'flight_minutes': 55},
          ],
        },
        'final_billable_hours': 3,
      });
      expect(result.source, 'pricing_breakdown.client_legs');
      expect(result.time, '1 h 50 min');
    });

    test('minimums and repositioning do not replace requested-route time', () {
      final result = resolveQuoteDisplayTime({
        'pricing_breakdown': {
          'display_route_hours': 1.83,
          'route_billable_hours': 1.83,
          'final_billable_hours': 4,
          'billable_hours': 5.25,
        },
        'repositioning': {'flight_hours': 1.5},
      });
      expect(result.time, '1 h 50 min');
      expect(
        extractBackendTotalBillableHours({
          'pricing_breakdown': {
            'route_billable_hours': 1.83,
            'final_billable_hours': 4,
            'billable_hours': 5.25,
          },
        }),
        5.25,
      );
    });
  });
}
