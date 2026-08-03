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

  test(
    'normalizeQuoteDisplayTime prefers explicit backend billable hours over billed display fields',
    () {
      final quote = <String, dynamic>{
        'trip_time': '3h 3m',
        'billed_time': '4h',
        'pricing': {'final_billable_hours': 4.0},
      };

      final resolution = resolveQuoteDisplayTime(quote);

      expect(resolution.source, 'pricing.final_billable_hours');
      expect(resolution.time, '4 h 00 min');
    },
  );

  test(
    'normalizeQuoteDisplayTime falls back to final billable hours before trip time',
    () {
      final quote = <String, dynamic>{
        'trip_time': '3h 3m',
        'pricing': {'final_billable_hours': 4.0},
      };

      final resolution = resolveQuoteDisplayTime(quote);

      expect(resolution.source, 'pricing.final_billable_hours');
      expect(resolution.time, '4 h 00 min');
    },
  );

  test(
    'normalizeQuoteDisplayTime prefers backend final billable hours before stale top-level time',
    () {
      final quote = <String, dynamic>{
        'time': '3 h 27 min',
        'card_time': '3 h 27 min',
        'pricing_breakdown': {'final_billable_hours': 4.33},
        'debug_pricing': {'final_billable_hours': 4.333333333333333},
      };

      final resolution = resolveQuoteDisplayTime(quote);

      expect(resolution.source, 'debug_pricing.final_billable_hours');
      expect(resolution.time, '4 h 20 min');
    },
  );

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
}
