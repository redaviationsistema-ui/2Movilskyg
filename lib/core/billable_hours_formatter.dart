double? extractBackendBillableHours(Map<String, dynamic> quote) {
  return _firstPositive([
    _backendDebugPricing(quote)['final_billable_hours'],
    quote['billable_hours'],
    _backendPricingBreakdown(quote)['final_billable_hours'],
    _backendPricing(quote)['final_billable_hours'],
    quote['final_billable_hours'],
    _backendPricingBreakdown(quote)['billable_hours'],
  ]);
}

class QuoteDisplayTimeResolution {
  const QuoteDisplayTimeResolution({required this.time, required this.source});

  final String time;
  final String source;
}

QuoteDisplayTimeResolution resolveQuoteDisplayTime(Map<String, dynamic> quote) {
  final pricingBreakdown = _backendPricingBreakdown(quote);
  final pricing = _backendPricing(quote);
  final pricingContext = _backendPricingContext(quote);
  final hourCandidates = <(String, dynamic)>[
    ('display_route_hours', quote['display_route_hours']),
    (
      'pricing_breakdown.display_route_hours',
      pricingBreakdown['display_route_hours'],
    ),
    ('pricing.display_route_hours', pricing['display_route_hours']),
    (
      'pricing_context.display_route_hours',
      pricingContext['display_route_hours'],
    ),
    ('client_display_flight_hours', quote['client_display_flight_hours']),
    (
      'pricing_breakdown.client_display_flight_hours',
      pricingBreakdown['client_display_flight_hours'],
    ),
    (
      'pricing.client_display_flight_hours',
      pricing['client_display_flight_hours'],
    ),
  ];
  for (final candidate in hourCandidates) {
    final hours = _asNonNegativeDouble(candidate.$2);
    if (hours != null && hours > 0) {
      return QuoteDisplayTimeResolution(
        time: hoursToTimeText(hours),
        source: candidate.$1,
      );
    }
  }

  final legsResolution = _sumRouteLegHours(quote);
  if (legsResolution != null) {
    return QuoteDisplayTimeResolution(
      time: hoursToTimeText(legsResolution.hours),
      source: legsResolution.source,
    );
  }

  final minuteCandidates = <(String, dynamic)>[
    ('estimated_flight_minutes', quote['estimated_flight_minutes']),
    ('pricing.estimated_flight_minutes', pricing['estimated_flight_minutes']),
    (
      'pricing_breakdown.estimated_flight_minutes',
      pricingBreakdown['estimated_flight_minutes'],
    ),
  ];
  for (final candidate in minuteCandidates) {
    final minutes = _asNonNegativeDouble(candidate.$2);
    if (minutes != null && minutes > 0) {
      return QuoteDisplayTimeResolution(
        time: hoursToTimeText(minutes / 60),
        source: candidate.$1,
      );
    }
  }

  for (final candidate in <(String, dynamic)>[
    ('trip_time', quote['trip_time']),
    ('flight_time', quote['flight_time']),
    ('operative_time', quote['operative_time']),
  ]) {
    final hours = parseDurationToHours(candidate.$2);
    if (hours != null && hours > 0) {
      return QuoteDisplayTimeResolution(
        time: hoursToTimeText(hours),
        source: candidate.$1,
      );
    }
  }

  for (final candidate in <(String, dynamic)>[
    ('display_time', quote['display_time']),
    ('card_time', quote['card_time']),
    ('ui_time', quote['ui_time']),
    ('time', quote['time']),
  ]) {
    final hours = parseDurationToHours(candidate.$2);
    if (hours != null && hours > 0) {
      return QuoteDisplayTimeResolution(
        time: hoursToTimeText(hours),
        source: candidate.$1,
      );
    }
  }

  return const QuoteDisplayTimeResolution(
    time: '0 h 00 min',
    source: 'default_zero',
  );
}

String normalizeQuoteDisplayTime(Map<String, dynamic> quote) {
  return resolveQuoteDisplayTime(quote).time;
}

double? extractBackendDisplayRouteHours(Map<String, dynamic> quote) {
  return _firstPositive([
    quote['display_route_hours'],
    _backendPricingBreakdown(quote)['display_route_hours'],
    _backendPricing(quote)['display_route_hours'],
    _backendPricingContext(quote)['display_route_hours'],
    quote['client_display_flight_hours'],
    _backendPricingBreakdown(quote)['client_display_flight_hours'],
    _backendPricing(quote)['client_display_flight_hours'],
  ]);
}

String hoursToTimeText(double hours) {
  if (!hours.isFinite || hours <= 0) return '0 h 00 min';

  var totalMinutes = (hours * 60).round();
  if (totalMinutes < 0) totalMinutes = 0;

  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h == 0) return '$m min';
  return '$h h ${m.toString().padLeft(2, '0')} min';
}

double? parseDurationToHours(dynamic value) {
  final numeric = _asNonNegativeDouble(value);
  if (numeric != null && value is! String) return numeric;

  final raw = value?.toString().trim().toLowerCase() ?? '';
  if (raw.isEmpty) return null;
  final decimal = _asNonNegativeDouble(raw);
  if (decimal != null) return decimal;

  final hhmm = RegExp(r'^(\d+):(\d{1,2})$').firstMatch(raw);
  if (hhmm != null) {
    final hours = int.parse(hhmm.group(1)!);
    final minutes = int.parse(hhmm.group(2)!);
    if (minutes < 60) return hours + minutes / 60;
  }

  final hoursMatch = RegExp(r'(\d+(?:\.\d+)?)\s*h').firstMatch(raw);
  final minutesMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:m|min)').firstMatch(raw);
  if (hoursMatch == null && minutesMatch == null) return null;
  final hours = double.tryParse(hoursMatch?.group(1) ?? '') ?? 0;
  final minutes = double.tryParse(minutesMatch?.group(1) ?? '') ?? 0;
  if (minutes >= 60) return null;
  return hours + minutes / 60;
}

({double hours, String source})? _sumRouteLegHours(Map<String, dynamic> quote) {
  final pricingBreakdown = _backendPricingBreakdown(quote);
  final pricing = _backendPricing(quote);
  for (final entry in <(String, dynamic)>[
    ('client_legs', quote['client_legs']),
    ('pricing_breakdown.client_legs', pricingBreakdown['client_legs']),
    ('pricing.client_legs', pricing['client_legs']),
    ('legs', quote['legs']),
    ('segments', quote['segments']),
    ('routes', quote['routes']),
  ]) {
    if (entry.$2 is! List || (entry.$2 as List).isEmpty) continue;
    var total = 0.0;
    var resolvedLegs = 0;
    for (final rawLeg in entry.$2 as List) {
      if (rawLeg is! Map) continue;
      final leg = _asMap(rawLeg);
      final hours =
          _asNonNegativeDouble(leg['display_flight_hours']) ??
          _asNonNegativeDouble(leg['flight_hours']) ??
          _asNonNegativeDouble(leg['direct_hours']) ??
          _asNonNegativeDouble(leg['real_flight_hours']) ??
          _asNonNegativeDouble(leg['duration_hours']) ??
          ((_asNonNegativeDouble(leg['flight_minutes']) ??
                      _asNonNegativeDouble(leg['duration_minutes'])) !=
                  null
              ? (_asNonNegativeDouble(leg['flight_minutes']) ??
                      _asNonNegativeDouble(leg['duration_minutes']))! /
                  60
              : null) ??
          parseDurationToHours(leg['flight_time']) ??
          parseDurationToHours(leg['duration']);
      if (hours != null) {
        total += hours;
        resolvedLegs++;
      }
    }
    if (resolvedLegs > 0 && total > 0) return (hours: total, source: entry.$1);
  }
  return null;
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

double? _asNonNegativeDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    final result = value.toDouble();
    return result.isFinite && result >= 0 ? result : null;
  }
  if (value is! String) return null;
  final normalized = value.replaceAll('USD', '').replaceAll(',', '').trim();
  final result = double.tryParse(normalized);
  return result != null && result.isFinite && result >= 0 ? result : null;
}
