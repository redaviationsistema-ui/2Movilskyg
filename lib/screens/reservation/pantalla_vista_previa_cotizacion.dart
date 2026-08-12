import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/billable_hours_formatter.dart';
import '../../core/cliente_api.dart';
import '../../core/quote_price_formatter.dart';
import '../../providers/proveedor_reservaciones.dart';
import 'pantalla_exito.dart';

class QuotePreviewScreen extends StatelessWidget {
  const QuotePreviewScreen({super.key, this.onReservationCreated});

  final ValueChanged<String?>? onReservationCreated;

  Future<void> confirm(BuildContext context) async {
    final reservation = context.read<ReservationProvider>();
    final quote = reservation.selectedQuoteMatch;

    if (quote == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay una cotizacion real seleccionada.'),
        ),
      );
      return;
    }

    final primaryRoute = reservation.routes.first;
    final origin =
        primaryRoute.fromAirport?.iata ?? primaryRoute.fromAirport?.name ?? '';
    final destination =
        primaryRoute.toAirport?.iata ?? primaryRoute.toAirport?.name ?? '';
    final departure = reservation.startDate ?? primaryRoute.startDate;

    if (origin.isEmpty || destination.isEmpty || departure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faltan datos base para crear la solicitud.'),
        ),
      );
      return;
    }

    if (quote['is_available'] == false) {
      reservation.handleAircraftUnavailable(quote);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (quote['availability_reason']?.toString().trim().isNotEmpty ??
                    false)
                ? quote['availability_reason'].toString()
                : 'Disponibilidad actualizada. Esta aeronave ya no esta disponible. Te mostramos otras opciones para tu vuelo.',
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const Dialog(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('Creando solicitud...'),
                ],
              ),
            ),
          ),
    );

    try {
      final response = await reservation.createFlightRequestForMatch(quote);
      final createdId = reservation.createdFlightRequestIdFromResponse(
        response,
      );
      await reservation.loadClientWorkspaceData(force: true);
      reservation.rememberCreatedFlightRequest(response);

      if (!context.mounted) return;

      Navigator.pop(context);
      if (onReservationCreated != null) {
        reservation.resetForm();
        onReservationCreated!(createdId);
        return;
      }

      reservation.resetForm();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SuccessScreen()),
      );
    } on ApiException catch (error) {
      if (context.mounted) Navigator.pop(context);

      if (error.isAircraftAvailabilityConflict) {
        reservation.handleAircraftUnavailable({...quote, ...?error.payload});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Disponibilidad actualizada. La aeronave seleccionada ya no se encuentra disponible. Te mostramos otras opciones disponibles para tu vuelo.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear la solicitud: ${error.message}'),
        ),
      );
    } catch (error) {
      if (context.mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear la solicitud: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reservation = context.watch<ReservationProvider>();
    final quote = reservation.selectedQuoteMatch;

    if (quote == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vista previa de cotizacion')),
        body: const Center(
          child: Text('No hay una cotizacion real disponible.'),
        ),
      );
    }

    final aircraft =
        (quote['aircraft_name'] ?? quote['model'] ?? '-').toString();
    final total = formatQuotePriceLabel(quote);
    final resolvedTime = resolveQuoteDisplayTime(quote).time;
    final billableHours =
        shouldDisplayBackendBillableHours(quote)
            ? extractBackendBillableHours(quote)
            : null;
    final formattedTime = formatBillableHoursLabel(billableHours);
    final time =
        resolvedTime.isNotEmpty && resolvedTime != '0 h 00 min'
            ? resolvedTime
            : formattedTime.isNotEmpty
            ? formattedTime
            : 'Por confirmar';
    final backendBillableLabel =
        formattedTime.isNotEmpty
            ? 'Horas cobrables backend: $formattedTime'
            : '';

    final cabin = (quote['cabin'] ?? 'Jet privado').toString();
    final capacity = (quote['capacity'] ?? 'N/D').toString();
    final providerName =
        ((quote['provider'] is Map)
            ? quote['provider']['company_name']?.toString()
            : null) ??
        quote['provider_name']?.toString() ??
        'Proveedor asignado por sistema';
    final breakdown =
        quote['pricing_breakdown'] is Map
            ? Map<String, dynamic>.from(quote['pricing_breakdown'] as Map)
            : <String, dynamic>{};
    final breakdownBillableHours =
        breakdown['final_billable_hours'] ??
        breakdown['billable_hours'] ??
        breakdown['billableHours'] ??
        '-';
    final subtotal =
        breakdown['subtotal'] ??
        breakdown['subtotal_before_multipliers'] ??
        '-';
    final fuel =
        breakdown['fuel'] ??
        breakdown['fuel_cost'] ??
        breakdown['fuel_surcharge'] ??
        '-';
    final repositioning =
        breakdown['repositioning'] ?? breakdown['repositioning_fee'] ?? '-';
    final overnight =
        breakdown['overnight'] ?? breakdown['overnight_fee'] ?? '-';
    final breakdownTotal = breakdown['total'] ?? quote['total'] ?? '-';
    final packageLabel = reservation.selectedPriorityLabel;
    final preference =
        reservation.preference.trim().isEmpty
            ? 'Sin preferencia especial'
            : reservation.preference.trim();
    final pets =
        reservation.pets.trim().isEmpty
            ? 'Sin mascotas registradas'
            : reservation.pets.trim();
    final baggage =
        reservation.specialBaggage.trim().isEmpty
            ? 'Sin equipaje especial'
            : reservation.specialBaggage.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Vista previa de cotizacion')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Cotizacion real',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Esta pantalla ya consume el preview del backend antes de crear la solicitud.',
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aircraft,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('$cabin · $capacity pasajeros'),
                  const SizedBox(height: 8),
                  Text('Proveedor: $providerName'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _PriceBlock(label: 'Total', value: total),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PriceBlock(label: 'Tiempo', value: time),
                      ),
                    ],
                  ),
                  if (backendBillableLabel.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _BackendBillableHoursChip(label: backendBillableLabel),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaPill(label: 'Paquete', value: packageLabel),
                      _MetaPill(
                        label: 'Tipo de viaje',
                        value: reservation.currentTripTypeLabel,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Preferencias del cliente',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _LineItem(label: 'Preferencia', value: preference),
                  _LineItem(label: 'Mascotas', value: pets),
                  _LineItem(label: 'Equipaje especial', value: baggage),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (breakdown.isNotEmpty) ...[
            const Text(
              'Desglose',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _LineItem(
                      label: 'Horas billables',
                      value: '$breakdownBillableHours',
                    ),
                    _LineItem(label: 'Subtotal', value: '\$$subtotal'),
                    _LineItem(label: 'Combustible', value: '\$$fuel'),
                    _LineItem(
                      label: 'Repositioning',
                      value: '\$$repositioning',
                    ),
                    _LineItem(label: 'Overnight', value: '\$$overnight'),
                    _LineItem(label: 'Total', value: '\$$breakdownTotal'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => confirm(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: const Color(0xFF10253A),
              ),
              child: const Text('Crear solicitud real'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF607080))),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF10253A),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackendBillableHoursChip extends StatelessWidget {
  const _BackendBillableHoursChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFD8B15D).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFD8B15D).withValues(alpha: .32),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: Color(0xFFB8860B),
            size: 13,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6F4E12),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFF10253A),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
