import '../providers/reservation_provider.dart';
import 'price_calculator.dart';

class QuoteTotals {
  final bool isInternational;
  final double flightTotal;
  final double overnightTotal;
  final double operationalExpenses;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double totalPrice;

  const QuoteTotals({
    required this.isInternational,
    required this.flightTotal,
    required this.overnightTotal,
    required this.operationalExpenses,
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    required this.totalPrice,
  });

  const QuoteTotals.zero({required this.isInternational})
    : flightTotal = 0,
      overnightTotal = 0,
      operationalExpenses = 0,
      subtotal = 0,
      taxRate = 0,
      taxAmount = 0,
      totalPrice = 0;
}

class QuoteCalculator {
  static bool isInternational(ReservationProvider reservation) {
    final routeType = reservation.routeType.toUpperCase();
    if (routeType == 'INTERNATIONAL' || routeType == 'INTERNACIONAL') {
      return true;
    }

    for (final route in reservation.routes) {
      final from = route.fromAirport;
      final to = route.toAirport;

      if (from == null || to == null) continue;
      final fromCountry = (from.country ?? '').trim().toUpperCase();
      final toCountry = (to.country ?? '').trim().toUpperCase();

      if (fromCountry != toCountry) {
        return true;
      }
    }

    return false;
  }

  static QuoteTotals calculate(ReservationProvider reservation) {
    final aircraft = reservation.selectedAircraft;
    final isInternationalFlight = isInternational(reservation);

    if (aircraft == null) {
      return QuoteTotals.zero(isInternational: isInternationalFlight);
    }

    final startDate = reservation.startDate;
    final endDate = reservation.endDate ?? startDate;

    double flightTotal = 0;
    double overnightTotal = 0;

    for (int i = 0; i < reservation.routes.length; i++) {
      final result = PriceCalculator.calculate(
        aircraft: aircraft,
        route: reservation.routes[i],
        startDate: startDate,
        endDate: endDate,
        international: isInternationalFlight,
      );

      flightTotal += result.flightCost;

      if (i == 0) {
        overnightTotal = result.overnightCost;
      }
    }

    final operationalExpenses =
        isInternationalFlight
            ? aircraft.internationalExpensesUsd
            : aircraft.nationalExpensesUsd;
    final taxRate = isInternationalFlight ? 0.04 : 0.16;
    final subtotal = flightTotal + overnightTotal + operationalExpenses;
    final taxAmount = subtotal * taxRate;
    final totalPrice = subtotal + taxAmount;

    return QuoteTotals(
      isInternational: isInternationalFlight,
      flightTotal: flightTotal,
      overnightTotal: overnightTotal,
      operationalExpenses: operationalExpenses,
      subtotal: subtotal,
      taxRate: taxRate,
      taxAmount: taxAmount,
      totalPrice: totalPrice,
    );
  }
}
