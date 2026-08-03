import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/core/quote_price_formatter.dart';

void main() {
  test('extractOfficialQuoteTotal prefers backend pricing total_amount', () {
    final quote = <String, dynamic>{
      'total': 13535,
      'final_price': 'USD 13,535',
      'pricing': {'total_amount': 14493},
    };

    expect(extractOfficialQuoteTotal(quote), 14493);
  });

  test('resolveDisplayedQuotePriceValue uses backend official total first', () {
    final quote = <String, dynamic>{
      'match_id': 'match-hawker',
      'base_price': 10000,
      'total': 13535,
      'pricing': {'total_amount': 14493},
      'airport_expenses': 300,
      'margin_amount': 1200,
    };

    expect(resolveDisplayedQuotePriceValue(quote), 14493);
  });

  test('formatQuotePriceLabel formats backend amount like web/mobile cards', () {
    final quote = <String, dynamic>{
      'match_id': 'match-g450',
      'pricing_breakdown': {'total_amount': 42960},
    };

    expect(formatQuotePriceLabel(quote), 'USD42,960');
  });
}
