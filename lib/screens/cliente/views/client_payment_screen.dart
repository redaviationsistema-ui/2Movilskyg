import 'package:flutter/material.dart';

import '../widgets/client_experience_widgets.dart';

class ClientPaymentScreen extends StatefulWidget {
  const ClientPaymentScreen({
    super.key,
    required this.request,
    required this.onPaymentComplete,
    this.showBackButton = true,
  });

  final Map<String, dynamic> request;
  final VoidCallback onPaymentComplete;
  final bool showBackButton;

  @override
  State<ClientPaymentScreen> createState() => _ClientPaymentScreenState();
}

class _ClientPaymentScreenState extends State<ClientPaymentScreen> {
  String _paymentMethod = 'card';
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cardController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvcController = TextEditingController();
  final TextEditingController _wireReferenceController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_refresh);
    _cardController.addListener(_refresh);
    _expiryController.addListener(_refresh);
    _cvcController.addListener(_refresh);
    _wireReferenceController.addListener(_refresh);
  }

  @override
  void dispose() {
    _emailController.removeListener(_refresh);
    _cardController.removeListener(_refresh);
    _expiryController.removeListener(_refresh);
    _cvcController.removeListener(_refresh);
    _wireReferenceController.removeListener(_refresh);
    _emailController.dispose();
    _cardController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _wireReferenceController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final amount = _amountLabel(widget.request);
    final route = _routeLabel(widget.request);

    return ClientExperienceShell(
      title: 'Pago',
      subtitle: 'Checkout seguro dentro del mismo flujo del portal cliente.',
      showBackButton: widget.showBackButton,
      trailing: const StatusBadge(
        label: 'Checkout seguro',
        color: Color(0xFF2D6A4F),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text(
            'Configura tu pago',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
              height: 0.98,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            route,
            style: const TextStyle(
              color: Color(0xFF625D55),
              fontSize: 16,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF08121C),
                  Color(0xFF12304A),
                  Color(0xFF1C5170),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F0E2238),
                  blurRadius: 28,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Checkout cifrado',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Confirma el metodo, revisa los datos de contacto y autoriza el cargo de tu reserva.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _TrustChip(label: 'Pago protegido'),
                    _TrustChip(label: 'Concierge financiero'),
                    _TrustChip(label: 'Reserva priorizada'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassInfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detalles del pago',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _PaymentMethodCard(
                      label: 'Tarjeta corporativa',
                      note: 'Checkout seguro integrado',
                      icon: Icons.credit_card_rounded,
                      selected: _paymentMethod == 'card',
                      onTap: () => setState(() => _paymentMethod = 'card'),
                    ),
                    _PaymentMethodCard(
                      label: 'Transferencia / wire',
                      note: 'Validacion manual del comprobante',
                      icon: Icons.account_balance_rounded,
                      selected: _paymentMethod == 'wire',
                      onTap: () => setState(() => _paymentMethod = 'wire'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _InputField(
                  controller: _emailController,
                  label: 'Correo electronico',
                  hint: 'cliente@empresa.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                if (_paymentMethod == 'card') ...[
                  _InputField(
                    controller: _cardController,
                    label: 'Numero de tarjeta',
                    hint: '1234 5678 9012 3456',
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                      final grouped =
                          digits
                              .replaceAllMapped(
                                RegExp(r'.{1,4}'),
                                (match) => '${match.group(0)} ',
                              )
                              .trimRight();
                      if (grouped != value) {
                        _cardController.value = TextEditingValue(
                          text: grouped,
                          selection: TextSelection.collapsed(
                            offset: grouped.length,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _InputField(
                          controller: _expiryController,
                          label: 'Expiracion',
                          hint: 'MM/AA',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InputField(
                          controller: _cvcController,
                          label: 'CVC',
                          hint: '123',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  _InputField(
                    controller: _wireReferenceController,
                    label: 'Referencia bancaria',
                    hint: 'Folio o comprobante',
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFEFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFEADFCE)),
                    ),
                    child: const Text(
                      'Generamos referencia bancaria y el pago queda pendiente hasta validar comprobante. Este flujo permite operar sin tarjeta.',
                      style: TextStyle(color: Color(0xFF3B3428), height: 1.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassInfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumen de reserva',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                _PaymentRow(label: 'Ruta', value: route),
                _PaymentRow(
                  label: 'Pasajeros',
                  value: (widget.request['passengers'] ?? '1').toString(),
                ),
                _PaymentRow(
                  label: 'Metodo seleccionado',
                  value:
                      _paymentMethod == 'card'
                          ? 'Tarjeta corporativa'
                          : 'Transferencia / wire',
                ),
                _PaymentRow(label: 'Importe a pagar hoy', value: amount),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _canSubmit ? widget.onPaymentComplete : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: const Color(0xFF10253A),
            ),
            child: Text(
              _paymentMethod == 'card'
                  ? 'Pagar ahora'
                  : 'Registrar transferencia',
            ),
          ),
        ],
      ),
    );
  }

  bool get _canSubmit {
    if (_emailController.text.trim().isEmpty) return false;
    if (_paymentMethod == 'card') {
      return _cardController.text.trim().length >= 19 &&
          _expiryController.text.trim().isNotEmpty &&
          _cvcController.text.trim().isNotEmpty;
    }
    return _wireReferenceController.text.trim().isNotEmpty;
  }

  String _routeLabel(Map<String, dynamic> request) {
    final origin =
        request['origin']?.toString() ??
        request['base_airport']?.toString() ??
        'Origen';
    final destination = request['destination']?.toString() ?? 'Destino';
    return '$origin -> $destination';
  }

  String _amountLabel(Map<String, dynamic> request) {
    return request['formatted_final_price']?.toString() ??
        request['final_price_display']?.toString() ??
        request['estimated_total']?.toString() ??
        request['final_price']?.toString() ??
        'Monto por confirmar';
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.label,
    required this.note,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String note;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF10253A) : const Color(0xFFFFFEFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF10253A) : const Color(0xFFEADFCE),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : const Color(0xFF10253A),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF111111),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              note,
              style: TextStyle(
                color:
                    selected
                        ? Colors.white.withValues(alpha: 0.85)
                        : const Color(0xFF625D55),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: (value) => onChanged?.call(value),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF625D55),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
