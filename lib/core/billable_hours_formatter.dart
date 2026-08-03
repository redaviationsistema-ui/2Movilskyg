double? extractBackendBillableHours(Map<String, dynamic> quote) {
  return _firstPositive([
    _backendPricingBreakdown(quote)['billable_hours'],
    quote['billable_hours'],
  ]);
}

class QuoteDisplayTimeResolution {
  const QuoteDisplayTimeResolution({required this.time, required this.source});

  final String time;
  final String source;
}

QuoteDisplayTimeResolution resolveQuoteDisplayTime(Map<String, dynamic> quote) {
  final pricingBreakdown = _backendPricingBreakdown(quote);
  final selectedHours = extractBackendBillableHours(quote);
  final selectedSource =
      _asDouble(pricingBreakdown['billable_hours']) != null &&
              (_asDouble(pricingBreakdown['billable_hours']) ?? 0) > 0
          ? 'pricing_breakdown.billable_hours'
          : _asDouble(quote['billable_hours']) != null &&
              (_asDouble(quote['billable_hours']) ?? 0) > 0
          ? 'billable_hours'
          : 'default_zero';

  if (selectedHours != null && selectedHours.isFinite && selectedHours > 0) {
    return QuoteDisplayTimeResolution(
      time: hoursToTimeText(selectedHours),
      source: selectedSource,
    );
  }

  return const QuoteDisplayTimeResolution(
    time: '0 h 00 min',
    source: 'default_zero',
  );
}

String normalizeQuoteDisplayTime(Map<String, dynamic> quote) {
  return resolveQuoteDisplayTime(quote).time;
}

String hoursToTimeText(double hours) {
  if (!hours.isFinite || hours <= 0) return '0 h 00 min';

  var totalMinutes = (hours * 60).round();
  if (totalMinutes < 0) totalMinutes = 0;

  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  return '$h h ${m.toString().padLeft(2, '0')} min';
}

String? normalizeTimeText(dynamic value) {
  if (value == null) return null;

  final raw = value.toString().trim();
  if (raw.isEmpty) return null;

  final hhmmMatch = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(raw);
  if (hhmmMatch != null) {
    final hours = int.tryParse(hhmmMatch.group(1)!);
    final minutes = int.tryParse(hhmmMatch.group(2)!);
    if (hours != null && minutes != null && minutes >= 0 && minutes < 60) {
      return '$hours h ${minutes.toString().padLeft(2, '0')} min';
    }
  }

  final compact = raw.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  final hmMatch = RegExp(
    r'^(\d+)\s*h(?:\s*(\d{1,2})\s*(?:m|min))?$',
    caseSensitive: false,
  ).firstMatch(compact);
  if (hmMatch != null) {
    final hours = int.tryParse(hmMatch.group(1)!);
    final minutesRaw = hmMatch.group(2);
    final minutes = minutesRaw == null ? 0 : int.tryParse(minutesRaw);
    if (hours != null && minutes != null && minutes >= 0 && minutes < 60) {
      return '$hours h ${minutes.toString().padLeft(2, '0')} min';
    }
  }

  return null;
}

double? extractBackendTotalBillableHours(Map<String, dynamic> quote) {
  return _firstPositive([
    _backendPricingBreakdown(quote)['billable_hours'],
    _backendPricingBreakdown(quote)['billableHours'],
    _backendPricing(quote)['billable_hours'],
    _backendPricing(quote)['billableHours'],
    _backendPricingContext(quote)['billable_hours'],
    _backendPricingContext(quote)['billableHours'],
    quote['billable_hours'],
    _backendDebugPricing(quote)['billable_hours'],
    extractBackendBillableHours(quote),
  ]);
}

double? extractBackendRouteBillableHours(Map<String, dynamic> quote) {
  return _firstPositive([
    _backendPricingBreakdown(quote)['route_billable_hours'],
    _backendPricing(quote)['route_billable_hours'],
    _backendPricingContext(quote)['route_billable_hours'],
    quote['route_billable_hours'],
    _backendDebugPricing(quote)['route_billable_hours'],
  ]);
}

Map<String, dynamic> mergeBackendPricingSources(Map<String, dynamic> quote) {
  final debugPricing = _asMap(quote['debug_pricing']);
  final pricing = _asMap(quote['pricing']);
  final pricingBreakdown = _asMap(quote['pricing_breakdown']);
  final pricingContext = _asMap(quote['pricing_context']);

  return {...pricing, ...pricingContext, ...pricingBreakdown, ...debugPricing};
}

bool shouldUseBackendBillableHoursAsPrimaryTime(Map<String, dynamic> quote) {
  return extractBackendBillableHours(quote) != null;
}

bool shouldDisplayBackendBillableHours(Map<String, dynamic> quote) {
  return extractBackendBillableHours(quote) != null;
}

String formatBillableHoursLabel(double? billableHours) {
  if (billableHours == null || !billableHours.isFinite || billableHours <= 0) {
    return '';
  }
  return hoursToTimeText(billableHours);
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

Map<String, dynamic> _backendDebugPricing(Map<String, dynamic> quote) =>
    _asMap(quote['debug_pricing']);

Map<String, dynamic> _backendPricing(Map<String, dynamic> quote) =>
    _asMap(quote['pricing']);

Map<String, dynamic> _backendPricingBreakdown(Map<String, dynamic> quote) =>
    _asMap(quote['pricing_breakdown']);

Map<String, dynamic> _backendPricingContext(Map<String, dynamic> quote) =>
    _asMap(quote['pricing_context']);

bool _hasExplicitFinalBillableHours(Map<String, dynamic> source) {
  if (source.isEmpty) return false;
  if (source.containsKey('has_explicit_final_billable_hours')) {
    return source['has_explicit_final_billable_hours'] == true;
  }
  return _firstPositive([source['final_billable_hours']]) != null;
}

bool _hasTopLevelExplicitFinalBillableHours(Map<String, dynamic> quote) {
  if (quote.containsKey('has_explicit_final_billable_hours')) {
    return quote['has_explicit_final_billable_hours'] == true;
  }
  return _firstPositive([quote['final_billable_hours']]) != null;
}

double? _firstPositive(List<dynamic> candidates) {
  for (final candidate in candidates) {
    final value = _asDouble(candidate);
    if (value != null && value.isFinite && value > 0) return value;
  }
  return null;
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().trim());
}
