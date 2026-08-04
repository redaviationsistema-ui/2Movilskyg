import 'package:intl/intl.dart';

double extractOfficialQuoteTotal(Map<String, dynamic> quote) {
  final pricing = _asMap(quote['pricing']);
  final pricingBreakdown = _asMap(quote['pricing_breakdown']);
  final pricingContext = _asMap(quote['pricing_context']);
  for (final candidate in [
    pricing['total_amount'],
    pricingBreakdown['total_amount'],
    pricingContext['total_amount'],
    quote['total_amount'],
    quote['amount_due'],
    quote['selected_card_price'],
    quote['estimated_total'],
    quote['final_price'],
    quote['total'],
    quote['price'],
  ]) {
    final value = _positiveMoney(candidate);
    if (value != null) return value;
  }
  return 0;
}

bool hasBackendQuotedPrice(Map<String, dynamic> quote) {
  final pricing = _asMap(quote['pricing']);
  final pricingBreakdown = _asMap(quote['pricing_breakdown']);
  final pricingContext = _asMap(quote['pricing_context']);
  final hasMatchIdentity =
      _text(quote['match_id']).isNotEmpty ||
      _text(quote['matched_option_id']).isNotEmpty;
  final officialTotal =
      _asNumber(pricing['total_amount']) > 0
          ? _asNumber(pricing['total_amount'])
          : _asNumber(pricingBreakdown['total_amount']) > 0
          ? _asNumber(pricingBreakdown['total_amount'])
          : _asNumber(pricingContext['total_amount']) > 0
          ? _asNumber(pricingContext['total_amount'])
          : _asNumber(quote['total_amount']);
  final hasPrice =
      _asNumber(quote['base_price']) > 0 ||
      officialTotal > 0 ||
      _asNumber(quote['total']) > 0 ||
      moneyValue(quote['final_price']) > 0;

  return hasMatchIdentity && hasPrice;
}

double resolveQuoteOperationalFees(Map<String, dynamic> quote) {
  final explicitFees =
      _asNumber(quote['repositioning_cost'] ?? quote['repositioning_fee']) +
      _asNumber(quote['return_to_base_cost']) +
      _asNumber(quote['landing_fees']) +
      _asNumber(quote['fbo_fees']) +
      _asNumber(quote['fuel_surcharge']) +
      _asNumber(quote['airport_expenses'] ?? quote['expense_fee']) +
      _asNumber(quote['overnight_cost'] ?? quote['overnight_fees']) +
      _asNumber(quote['margin_amount']) +
      _asNumber(quote['taxes']);

  return explicitFees > 0 ? explicitFees : 0;
}

double resolveDisplayedQuotePriceValue(Map<String, dynamic> quote) {
  return extractOfficialQuoteTotal(quote);
}

String formatQuotePriceLabel(Map<String, dynamic> quote) {
  final finalPrice = resolveDisplayedQuotePriceValue(quote);
  if (finalPrice > 0) return _formatCurrency(finalPrice);
  return 'Cotizacion inmediata';
}

double moneyValue(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return 0;
  final normalized = raw.replaceAll(RegExp(r'[^\d.\-]'), '');
  return double.tryParse(normalized) ?? 0;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

double _asNumber(dynamic value) {
  if (value is num) return value.toDouble();
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return 0;
  return double.tryParse(text.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;
}

double? _positiveMoney(dynamic value) {
  final parsed = _asNumber(value);
  return parsed.isFinite && parsed > 0 ? parsed : null;
}

String _text(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return '';
  return text;
}

String _formatCurrency(double value) {
  final formatter = NumberFormat.currency(
    locale: 'es_MX',
    name: 'USD',
    decimalDigits: 0,
  );
  return formatter.format(value);
}
