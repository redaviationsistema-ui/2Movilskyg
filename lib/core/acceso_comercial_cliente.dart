import 'package:intl/intl.dart';

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
    required this.expiresAt,
    required this.expiresAtLabel,
    required this.graceEndsAtLabel,
    this.backendIsActive,
    this.backendCanQuote,
    this.backendCanReserve,
    this.backendCanRenew,
    this.backendMessage = '',
  });

  final String status;
  final bool hasPaidAccess;
  final int freeQuoteLimit;
  final int freeQuotesUsed;
  final int remainingFreeQuotes;
  final bool isPastDue;
  final bool isSuspended;
  final bool isExpired;
  final DateTime? expiresAt;
  final String expiresAtLabel;
  final String graceEndsAtLabel;
  final bool? backendIsActive;
  final bool? backendCanQuote;
  final bool? backendCanReserve;
  final bool? backendCanRenew;
  final String backendMessage;

  bool get isConfirmedActive {
    if (backendIsActive is bool) {
      return backendIsActive == true && !isExpired && !isSuspended;
    }
    return !isExpired &&
        !isSuspended &&
        !isPastDue &&
        canReserve &&
        _activeStatuses.contains(status);
  }

  bool get canQuote =>
      backendCanQuote ??
      (!isExpired &&
          (hasPaidAccess ||
              isPastDue ||
              _activeStatuses.contains(status) ||
              _demoStatuses.contains(status) ||
              remainingFreeQuotes > 0));

  bool get canReserve =>
      backendCanReserve ??
      (!isExpired &&
          (hasPaidAccess || isPastDue || _activeStatuses.contains(status)));

  bool get requiresPayment =>
      backendCanRenew ??
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
    if (status == 'checkout_pending') return 'Checkout pendiente';
    if (status == 'payment_processing') return 'Verificando pago';
    if (status == 'payment_failed') return 'Pago rechazado';
    if (status == 'cancelled') return 'Pago cancelado';
    if (status == 'inactive') return 'Acceso inactivo';
    return 'Prueba consumida';
  }

  String get quoteBlockedMessage {
    if (backendMessage.isNotEmpty) return backendMessage;
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
    if (status == 'checkout_pending') {
      return 'Tu checkout sigue abierto. Completa el pago en Stripe para reactivar el acceso comercial.';
    }
    if (status == 'payment_processing') {
      return 'Stripe ya recibio tu intento de pago. Estamos verificando la confirmacion final con el backend.';
    }
    if (status == 'payment_failed') {
      return 'No pudimos validar el pago anterior. Intenta de nuevo para reactivar tu acceso comercial.';
    }
    if (status == 'cancelled') {
      return 'El pago fue cancelado antes de confirmarse. Puedes intentarlo de nuevo cuando quieras.';
    }
    return 'Tu cotizacion de prueba ya fue utilizada. Activa el acceso comercial para continuar.';
  }

  bool get shouldShowAccessBanner =>
      isSuspended ||
      isPastDue ||
      isExpired ||
      ((hasPaidAccess || _activeStatuses.contains(status))
          ? _isWithinExpiryWarningWindow(expiresAt)
          : (!hasPaidAccess || remainingFreeQuotes <= 0));

  String get accessBannerTitle {
    if (isSuspended) {
      return graceEndsAtLabel.isNotEmpty
          ? 'Acceso comercial suspendido desde $graceEndsAtLabel'
          : 'Acceso comercial suspendido';
    }
    if (isExpired) {
      return expiresAtLabel.isNotEmpty
          ? 'Acceso comercial vencido $expiresAtLabel'
          : 'Acceso comercial vencido';
    }
    if (isPastDue) {
      return graceEndsAtLabel.isNotEmpty
          ? 'Pago pendiente, gracia hasta $graceEndsAtLabel'
          : 'Pago pendiente por actualizar';
    }
    if (hasPaidAccess || _activeStatuses.contains(status)) {
      return expiresAtLabel.isNotEmpty
          ? 'Acceso comercial activo hasta $expiresAtLabel'
          : 'Acceso comercial activo';
    }
    if (remainingFreeQuotes > 0) {
      return 'Te quedan $remainingFreeQuotes cotizacion${remainingFreeQuotes == 1 ? '' : 'es'} de prueba';
    }
    if (status == 'checkout_pending') {
      return 'Tu checkout de acceso sigue pendiente';
    }
    if (status == 'payment_processing') {
      return 'Estamos verificando tu pago';
    }
    if (status == 'payment_failed') {
      return 'No pudimos renovar tu acceso comercial';
    }
    if (status == 'cancelled') {
      return 'Tu pago fue cancelado';
    }
    return 'Activa tu acceso comercial';
  }

  String get accessBannerMessage {
    if (backendMessage.isNotEmpty && (isExpired || isSuspended || !canQuote)) {
      return backendMessage;
    }
    if (isExpired || isSuspended || !canQuote) return quoteBlockedMessage;
    if (isPastDue) {
      return reservationBlockedMessage;
    }
    if (hasPaidAccess || _activeStatuses.contains(status)) {
      return 'Tu cuenta puede cotizar, reservar, firmar contrato y pagar vuelos.';
    }
    if (remainingFreeQuotes > 0) {
      return 'Todavia puedes cotizar con tu prueba, pero necesitaras activar el acceso comercial para reservar.';
    }
    return reservationBlockedMessage;
  }

  String get paymentActionLabel {
    if (isPastDue || isSuspended) return 'Actualizar metodo de pago';
    if (isExpired || status == 'payment_failed') {
      return 'Reactivar acceso comercial';
    }
    if (hasPaidAccess || _activeStatuses.contains(status)) {
      return 'Administrar acceso comercial';
    }
    return 'Activar acceso comercial';
  }

  String get quoteActionLabel {
    if (!canQuote) return paymentActionLabel;
    return 'Solicitar cotizacion';
  }

  String get reservationBlockedMessage {
    if (backendMessage.isNotEmpty && (isExpired || isSuspended || isPastDue)) {
      return backendMessage;
    }
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
    if (status == 'checkout_pending') {
      return 'Tu checkout de acceso sigue abierto. Completa el pago en Stripe para poder reservar.';
    }
    if (status == 'payment_processing') {
      return 'Tu pago de acceso esta en verificacion. En cuanto se confirme, podras reservar.';
    }
    if (status == 'payment_failed') {
      return 'No pudimos validar el pago anterior. Intenta de nuevo para activar tu acceso comercial.';
    }
    if (status == 'cancelled') {
      return 'El pago fue cancelado antes de confirmarse. Puedes reintentar la activacion para reservar.';
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

const Set<String> _checkoutPendingStatuses = {
  'checkout_pending',
  'payment_pending',
  'pending',
  'open',
};

const Set<String> _paymentProcessingStatuses = {
  'payment_processing',
  'processing',
  'complete',
  'completed',
};

const Set<String> _paymentFailureStatuses = {
  'payment_failed',
  'failed',
  'past_due',
  'unpaid',
};

CommercialAccessState resolveCommercialAccessState(
  Map<String, dynamic>? source,
) {
  final access = source ?? const <String, dynamic>{};
  final data = _map(access['data']);
  final dataAccess = _map(
    data['access'] ?? data['commercial_access'] ?? data['commercialAccess'],
  );
  final commercial = _map(
    access['commercial_access'] ??
        access['commercialAccess'] ??
        access['access'] ??
        data['commercial_access'] ??
        data['commercialAccess'] ??
        data['access'],
  );
  final subscription = _map(
    access['subscription'] ??
        access['membership'] ??
        data['subscription'] ??
        data['membership'],
  );
  final latestPayment = _firstMap([
    commercial['latest_payment'],
    commercial['payment'],
    access['latest_payment'],
    access['payment'],
    data['latest_payment'],
    data['payment'],
    dataAccess['latest_payment'],
    dataAccess['payment'],
    subscription['latest_payment'],
    subscription['payment'],
  ]);
  final checkoutSession = _firstMap([
    access['checkout_session'],
    access['session'],
    data['checkout_session'],
    data['session'],
    commercial['checkout_session'],
    commercial['session'],
  ]);
  final backendMarkedActive =
      _asBool(
        commercial['access_is_active'] ??
            dataAccess['access_is_active'] ??
            access['access_is_active'] ??
            data['access_is_active'],
      ) ||
      _activeStatuses.contains(
        _normalized(
          commercial['status'] ??
              commercial['access_status'] ??
              dataAccess['status'] ??
              access['access_status'],
        ),
      );
  final availableActions = _firstMap([
    commercial['available_actions'],
    dataAccess['available_actions'],
    access['available_actions'],
    data['available_actions'],
  ]);

  final statusCandidate = _normalized(
    commercial['access_status'] ??
        commercial['status'] ??
        dataAccess['status'] ??
        access['access_status'] ??
        data['access_status'] ??
        access['subscription_status'] ??
        data['subscription_status'] ??
        subscription['status'] ??
        latestPayment['status'] ??
        latestPayment['payment_status'] ??
        checkoutSession['payment_status'] ??
        checkoutSession['status'],
  );
  final status =
      backendMarkedActive
          ? 'active'
          : _checkoutPendingStatuses.contains(statusCandidate)
          ? 'checkout_pending'
          : _paymentProcessingStatuses.contains(statusCandidate)
          ? 'payment_processing'
          : _paymentFailureStatuses.contains(statusCandidate)
          ? 'payment_failed'
          : statusCandidate == 'trial_used'
          ? 'inactive'
          : statusCandidate;
  final hasPaidAccess = _asBool(
    commercial['has_paid_access'] ??
        dataAccess['has_paid_access'] ??
        access['has_paid_access'] ??
        data['has_paid_access'] ??
        commercial['is_paid'] ??
        dataAccess['is_paid'] ??
        access['is_paid'] ??
        data['is_paid'] ??
        commercial['payment_completed'] ??
        dataAccess['payment_completed'] ??
        access['payment_completed'] ??
        data['payment_completed'],
  );
  final freeQuoteLimit = _asInt(
    commercial['free_quote_limit'] ??
        dataAccess['free_quote_limit'] ??
        access['free_quote_limit'] ??
        data['free_quote_limit'],
    fallback: 1,
  ).clamp(1, 999);
  final freeQuotesUsed = _asInt(
    commercial['free_quotes_used'] ??
        dataAccess['free_quotes_used'] ??
        access['free_quotes_used'] ??
        data['free_quotes_used'],
  ).clamp(0, 999);
  final remainingFreeQuotes = _asInt(
    commercial['remaining_free_quotes'] ??
        dataAccess['remaining_free_quotes'] ??
        access['remaining_free_quotes'] ??
        data['remaining_free_quotes'] ??
        (freeQuoteLimit - freeQuotesUsed),
  ).clamp(0, 999);

  final backendIsInGrace =
      commercial['access_is_in_grace_period'] ??
      dataAccess['access_is_in_grace_period'] ??
      access['access_is_in_grace_period'] ??
      data['access_is_in_grace_period'];
  final backendIsActive =
      commercial['access_is_active'] ??
      dataAccess['access_is_active'] ??
      access['access_is_active'] ??
      data['access_is_active'];
  final backendIsExpired =
      commercial['access_is_expired'] ??
      dataAccess['access_is_expired'] ??
      access['access_is_expired'] ??
      data['access_is_expired'];
  final graceEndsAtValue =
      backendIsInGrace == true
          ? (commercial['grace_period_ends_at'] ??
              commercial['grace_period_ends_date'] ??
              dataAccess['grace_period_ends_at'] ??
              dataAccess['grace_period_ends_date'] ??
              access['grace_period_ends_at'] ??
              data['grace_period_ends_at'])
          : (commercial['grace_period_ends_at'] ??
              commercial['grace_ends_at'] ??
              dataAccess['grace_period_ends_at'] ??
              dataAccess['grace_ends_at'] ??
              access['grace_period_ends_at'] ??
              access['grace_ends_at'] ??
              data['grace_period_ends_at'] ??
              data['grace_ends_at']);
  final expiresAt = _firstAvailableDate([
    commercial['access_expires_date'],
    commercial['access_expires_at'],
    commercial['expires_at'],
    dataAccess['access_expires_date'],
    dataAccess['access_expires_at'],
    dataAccess['expires_at'],
    access['access_expires_date'],
    access['access_expires_at'],
    access['expires_at'],
    data['access_expires_date'],
    data['access_expires_at'],
    data['expires_at'],
  ]);
  final graceEndsAtLabel = _formatDate(graceEndsAtValue);
  final expiresAtLabel = _resolveDateLabel(
    commercial['access_expires_formatted'] ??
        dataAccess['access_expires_formatted'] ??
        access['access_expires_formatted'] ??
        data['access_expires_formatted'],
    fallback: expiresAt,
  );

  final isPastDue =
      backendIsInGrace is bool
          ? backendIsInGrace
          : _pastDueStatuses.contains(status);
  final isSuspended = !hasPaidAccess && _suspendedStatuses.contains(status);
  final isExpired =
      backendIsExpired is bool
          ? backendIsExpired
          : (!hasPaidAccess &&
              !isPastDue &&
              (status == 'expired' ||
                  isSuspended ||
                  _isDateExpired(expiresAt)));

  return CommercialAccessState(
    status: status,
    hasPaidAccess: hasPaidAccess,
    freeQuoteLimit: freeQuoteLimit,
    freeQuotesUsed: freeQuotesUsed,
    remainingFreeQuotes: remainingFreeQuotes,
    isPastDue: isPastDue,
    isSuspended: isSuspended,
    isExpired: isExpired,
    expiresAt: expiresAt,
    expiresAtLabel: expiresAtLabel,
    graceEndsAtLabel: graceEndsAtLabel,
    backendIsActive: backendIsActive is bool ? backendIsActive : null,
    backendCanQuote:
        availableActions['can_quote'] is bool
            ? availableActions['can_quote'] as bool
            : null,
    backendCanReserve:
        availableActions['can_reserve'] is bool
            ? availableActions['can_reserve'] as bool
            : null,
    backendCanRenew:
        availableActions['can_renew'] is bool
            ? availableActions['can_renew'] as bool
            : null,
    backendMessage:
        (commercial['access_message'] ??
                dataAccess['access_message'] ??
                access['access_message'] ??
                data['access_message'] ??
                '')
            .toString(),
  );
}

String _resolveDateLabel(dynamic value, {DateTime? fallback}) {
  final normalized = value?.toString().trim() ?? '';
  if (normalized.isNotEmpty) {
    final parsed = DateTime.tryParse(normalized);
    if (parsed != null) {
      return _formatDate(parsed);
    }
    return normalized;
  }
  return _formatDate(fallback);
}

Map<String, dynamic> syncCommercialAccessPayload(
  Map<String, dynamic>? currentAccess,
  Map<String, dynamic>? source,
) {
  final access = Map<String, dynamic>.from(currentAccess ?? const {});
  final commercial = _map(access['commercial_access']);
  final rawSource = _map(source);
  final sourceData = _map(rawSource['data']);
  final latestSource = _mergeMaps([
    rawSource,
    sourceData,
    _map(sourceData['access']),
    _map(sourceData['commercial_access']),
    _map(sourceData['commercialAccess']),
  ]);
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
    if ((latestCommercial['latest_payment'] ??
            latestSource['latest_payment']) !=
        null)
      'latest_payment':
          latestCommercial['latest_payment'] ?? latestSource['latest_payment'],
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

Map<String, dynamic> _firstMap(List<dynamic> values) {
  for (final value in values) {
    final map = _map(value);
    if (map.isNotEmpty) return map;
  }
  return const <String, dynamic>{};
}

Map<String, dynamic> _mergeMaps(List<Map<String, dynamic>> values) {
  final merged = <String, dynamic>{};
  for (final value in values) {
    if (value.isNotEmpty) merged.addAll(value);
  }
  return merged;
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
  final parsed = _parseDate(value);
  if (parsed == null) {
    final raw = value?.toString().trim() ?? '';
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }
  return DateFormat('d MMMM y', 'es_MX').format(parsed);
}

DateTime? _parseDate(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

bool _isDateExpired(DateTime? value) {
  final parsed = value;
  if (parsed == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return parsed.isBefore(today);
}

DateTime? _firstAvailableDate(List<dynamic> candidates) {
  for (final candidate in candidates) {
    final parsed = _parseDate(candidate);
    if (parsed != null) return parsed;
  }
  return null;
}

bool _isWithinExpiryWarningWindow(DateTime? expiresAt) {
  if (expiresAt == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final daysUntilExpiry = expiresAt.difference(today).inDays;
  return daysUntilExpiry >= 0 && daysUntilExpiry <= 7;
}
