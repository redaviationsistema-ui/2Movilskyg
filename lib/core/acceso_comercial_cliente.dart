class CommercialAccessState {
  const CommercialAccessState({
    required this.status,
    required this.hasPaidAccess,
    required this.freeQuoteLimit,
    required this.freeQuotesUsed,
    required this.remainingFreeQuotes,
    required this.isPastDue,
    required this.isSuspended,
    required this.isExpired,
    required this.expiresAtLabel,
    required this.graceEndsAtLabel,
  });

  final String status;
  final bool hasPaidAccess;
  final int freeQuoteLimit;
  final int freeQuotesUsed;
  final int remainingFreeQuotes;
  final bool isPastDue;
  final bool isSuspended;
  final bool isExpired;
  final String expiresAtLabel;
  final String graceEndsAtLabel;

  bool get canQuote =>
      !isExpired &&
      (hasPaidAccess ||
          isPastDue ||
          _activeStatuses.contains(status) ||
          _demoStatuses.contains(status) ||
          remainingFreeQuotes > 0);

  bool get canReserve =>
      !isExpired &&
      (hasPaidAccess || isPastDue || _activeStatuses.contains(status));

  bool get requiresPayment =>
      isSuspended ||
      isPastDue ||
      isExpired ||
      (!hasPaidAccess && remainingFreeQuotes <= 0);

  String get statusLabel {
    if (isSuspended) {
      return graceEndsAtLabel.isNotEmpty
          ? 'Suspendido desde $graceEndsAtLabel'
          : 'Suspendido';
    }
    if (isExpired) {
      return expiresAtLabel.isNotEmpty ? 'Vencido $expiresAtLabel' : 'Vencido';
    }
    if (isPastDue) {
      return graceEndsAtLabel.isNotEmpty
          ? 'Gracia hasta $graceEndsAtLabel'
          : 'Pago pendiente';
    }
    if (hasPaidAccess || _activeStatuses.contains(status)) {
      return expiresAtLabel.isNotEmpty
          ? 'Activo hasta $expiresAtLabel'
          : 'Activo';
    }
    if (remainingFreeQuotes > 0) {
      return '$remainingFreeQuotes cotizacion gratis';
    }
    if (status == 'payment_pending') return 'Pago en validacion';
    if (status == 'payment_failed') return 'Pago rechazado';
    return 'Prueba consumida';
  }

  String get quoteBlockedMessage {
    if (isSuspended) {
      return graceEndsAtLabel.isNotEmpty
          ? 'Tu periodo de gracia termino el $graceEndsAtLabel. Actualiza el metodo de pago para reactivar cotizaciones.'
          : 'Tu acceso comercial esta suspendido. Actualiza el metodo de pago para reactivar cotizaciones.';
    }
    if (isExpired) {
      return expiresAtLabel.isNotEmpty
          ? 'Tu acceso comercial vencio el $expiresAtLabel. Reactiva el pago para continuar.'
          : 'Tu acceso comercial vencio. Reactiva el pago para continuar.';
    }
    if (isPastDue) {
      return graceEndsAtLabel.isNotEmpty
          ? 'El cobro automatico fallo. Tu cuenta sigue activa hasta $graceEndsAtLabel mientras actualizas el metodo de pago.'
          : 'El cobro automatico fallo. Tu cuenta sigue activa temporalmente mientras actualizas el metodo de pago.';
    }
    if (hasPaidAccess) return 'Tu acceso comercial ya esta activo.';
    if (remainingFreeQuotes > 0) {
      return 'Tienes $remainingFreeQuotes cotizacion${remainingFreeQuotes == 1 ? '' : 'es'} de prueba disponible${remainingFreeQuotes == 1 ? '' : 's'}.';
    }
    if (status == 'payment_pending') {
      return 'Tu pago de acceso esta en validacion. En cuanto se confirme podras continuar.';
    }
    if (status == 'payment_failed') {
      return 'No pudimos validar el pago anterior. Intenta de nuevo para reactivar tu acceso comercial.';
    }
    return 'Tu cotizacion de prueba ya fue utilizada. Activa el acceso comercial para continuar.';
  }

  String get reservationBlockedMessage {
    if (isSuspended) {
      return graceEndsAtLabel.isNotEmpty
          ? 'Tu periodo de gracia termino el $graceEndsAtLabel. Actualiza el metodo de pago para volver a reservar y pagar vuelos.'
          : 'Tu acceso comercial esta suspendido. Actualiza el metodo de pago para volver a reservar y pagar vuelos.';
    }
    if (isExpired) {
      return expiresAtLabel.isNotEmpty
          ? 'Tu acceso comercial vencio el $expiresAtLabel. Reactiva el pago para poder reservar.'
          : 'Tu acceso comercial vencio. Reactiva el pago para poder reservar.';
    }
    if (isPastDue) {
      return graceEndsAtLabel.isNotEmpty
          ? 'Tu pago automatico fallo, pero sigues activo hasta $graceEndsAtLabel. Actualiza el metodo de pago para evitar el bloqueo.'
          : 'Tu pago automatico fallo, pero sigues activo temporalmente. Actualiza el metodo de pago para evitar el bloqueo.';
    }
    if (hasPaidAccess) return 'Tu acceso comercial ya esta activo.';
    if (remainingFreeQuotes > 0) {
      return 'Tu prueba gratis cubre la cotizacion inicial. Para reservar este vuelo primero activa el acceso comercial de USD 115.';
    }
    if (status == 'payment_pending') {
      return 'Tu pago de acceso esta en validacion. En cuanto se confirme, podras reservar.';
    }
    if (status == 'payment_failed') {
      return 'No pudimos validar el pago anterior. Intenta de nuevo para activar tu acceso comercial.';
    }
    return 'Necesitas activar el acceso comercial para reservar, firmar contrato y pagar el vuelo.';
  }
}

const Set<String> _activeStatuses = {
  'active',
  'activa',
  'vigente',
  'approved',
  'paid',
};

const Set<String> _demoStatuses = {
  'trial_active',
  'demo_active',
  'demo_activa',
  'trial',
  'demo',
  'registered',
};

const Set<String> _pastDueStatuses = {
  'past_due',
  'past due',
  'payment_failed',
  'failed',
  'retry_required',
  'retry_pending',
  'grace',
  'grace_period',
  'in_grace',
};

const Set<String> _suspendedStatuses = {
  'unpaid',
  'suspended',
  'suspendida',
  'suspendido',
  'blocked',
  'inactive',
  'cancelled',
  'canceled',
};

CommercialAccessState resolveCommercialAccessState(
  Map<String, dynamic>? source,
) {
  final access = source ?? const <String, dynamic>{};
  final commercial = _map(
    access['commercial_access'] ??
        access['commercialAccess'] ??
        access['access'],
  );
  final subscription = _map(access['subscription'] ?? access['membership']);

  final status = _normalized(
    commercial['status'] ??
        access['access_status'] ??
        access['subscription_status'] ??
        subscription['status'],
  );
  final hasPaidAccess = _asBool(
    commercial['has_paid_access'] ?? access['has_paid_access'],
  );
  final freeQuoteLimit = _asInt(
    commercial['free_quote_limit'] ?? access['free_quote_limit'],
    fallback: 1,
  ).clamp(1, 999);
  final freeQuotesUsed = _asInt(
    commercial['free_quotes_used'] ?? access['free_quotes_used'],
  ).clamp(0, 999);
  final remainingFreeQuotes = _asInt(
    commercial['remaining_free_quotes'] ??
        access['remaining_free_quotes'] ??
        (freeQuoteLimit - freeQuotesUsed),
  ).clamp(0, 999);

  final graceEndsAtLabel = _formatDate(
    commercial['grace_period_ends_at'] ??
        commercial['grace_ends_at'] ??
        access['grace_period_ends_at'] ??
        access['grace_ends_at'],
  );
  final expiresAtLabel = _formatDate(
    commercial['access_expires_at'] ??
        commercial['billing_period_end'] ??
        access['access_expires_at'] ??
        access['billing_period_end'] ??
        _map(commercial['latest_payment'])['billing_period_end'] ??
        _map(access['latest_payment'])['billing_period_end'],
  );

  final isPastDue = _pastDueStatuses.contains(status);
  final isSuspended = _suspendedStatuses.contains(status);
  final isExpired =
      !isPastDue && (isSuspended || _isDateExpired(expiresAtLabel));

  return CommercialAccessState(
    status: status,
    hasPaidAccess: hasPaidAccess,
    freeQuoteLimit: freeQuoteLimit,
    freeQuotesUsed: freeQuotesUsed,
    remainingFreeQuotes: remainingFreeQuotes,
    isPastDue: isPastDue,
    isSuspended: isSuspended,
    isExpired: isExpired,
    expiresAtLabel: expiresAtLabel,
    graceEndsAtLabel: graceEndsAtLabel,
  );
}

Map<String, dynamic> syncCommercialAccessPayload(
  Map<String, dynamic>? currentAccess,
  Map<String, dynamic>? source,
) {
  final access = Map<String, dynamic>.from(currentAccess ?? const {});
  final commercial = _map(access['commercial_access']);
  final latestSource = _map(source);
  final state = resolveCommercialAccessState(latestSource);
  final latestCommercial = _map(
    latestSource['commercial_access'] ??
        latestSource['commercialAccess'] ??
        latestSource['access'],
  );

  final mergedCommercial = <String, dynamic>{
    ...commercial,
    ...latestCommercial,
    'status': state.status,
    'has_paid_access': state.hasPaidAccess,
    'free_quote_limit': state.freeQuoteLimit,
    'free_quotes_used': state.freeQuotesUsed,
    'remaining_free_quotes': state.remainingFreeQuotes,
    if (latestCommercial['access_expires_at'] != null)
      'access_expires_at': latestCommercial['access_expires_at'],
    if (latestCommercial['billing_period_end'] != null)
      'billing_period_end': latestCommercial['billing_period_end'],
    if (latestCommercial['grace_period_ends_at'] != null)
      'grace_period_ends_at': latestCommercial['grace_period_ends_at'],
    if (latestCommercial['payment_preview'] != null)
      'payment_preview': latestCommercial['payment_preview'],
    if (latestCommercial['latest_payment'] != null)
      'latest_payment': latestCommercial['latest_payment'],
  };

  return {
    ...access,
    'commercial_access': mergedCommercial,
    'access_status': state.status,
    'has_paid_access': state.hasPaidAccess,
    'free_quote_limit': state.freeQuoteLimit,
    'free_quotes_used': state.freeQuotesUsed,
    'remaining_free_quotes': state.remainingFreeQuotes,
    if (mergedCommercial['access_expires_at'] != null)
      'access_expires_at': mergedCommercial['access_expires_at'],
    if (mergedCommercial['billing_period_end'] != null)
      'billing_period_end': mergedCommercial['billing_period_end'],
    if (mergedCommercial['grace_period_ends_at'] != null)
      'grace_period_ends_at': mergedCommercial['grace_period_ends_at'],
    if (latestSource['payment_preview'] != null)
      'payment_preview': latestSource['payment_preview'],
    if (latestSource['payment_preview'] == null &&
        mergedCommercial['payment_preview'] != null)
      'payment_preview': mergedCommercial['payment_preview'],
    if (mergedCommercial['latest_payment'] != null)
      'latest_payment': mergedCommercial['latest_payment'],
  };
}

Map<String, dynamic> consumeTrialQuoteLocally(
  Map<String, dynamic>? currentAccess,
) {
  final access = syncCommercialAccessPayload(currentAccess, currentAccess);
  final state = resolveCommercialAccessState(access);

  if (state.hasPaidAccess || state.remainingFreeQuotes <= 0) {
    return access;
  }

  final nextUsed = state.freeQuotesUsed + 1;
  final nextRemaining = (state.freeQuoteLimit - nextUsed).clamp(0, 999);
  final nextStatus =
      nextRemaining > 0
          ? (state.status.isEmpty ? 'trial_active' : state.status)
          : state.status == 'payment_pending'
          ? 'payment_pending'
          : 'trial_used';

  return syncCommercialAccessPayload(access, {
    'commercial_access': {
      ..._map(access['commercial_access']),
      'status': nextStatus,
      'has_paid_access': false,
      'free_quote_limit': state.freeQuoteLimit,
      'free_quotes_used': nextUsed,
      'remaining_free_quotes': nextRemaining,
    },
    'access_status': nextStatus,
    'has_paid_access': false,
    'free_quote_limit': state.freeQuoteLimit,
    'free_quotes_used': nextUsed,
    'remaining_free_quotes': nextRemaining,
  });
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  final normalized = _normalized(value);
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _normalized(dynamic value) =>
    value?.toString().trim().toLowerCase() ?? '';

String _formatDate(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return '';
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return raw;
  final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (parsed == null) return raw.length >= 10 ? raw.substring(0, 10) : raw;
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  return '${parsed.year}-$month-$day';
}

bool _isDateExpired(String value) {
  if (value.isEmpty) return false;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final expiry = DateTime(parsed.year, parsed.month, parsed.day);
  return expiry.isBefore(today);
}
