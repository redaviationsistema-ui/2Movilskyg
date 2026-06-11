import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/cliente_api.dart';
import '../widgets/widgets_experiencia_cliente.dart';

const Color kBg = Color(0xFFF7F7F7);
const Color kWhite = Colors.white;
const Color kBlack = Color(0xFF050505);
const Color kText = Color(0xFF111111);
const Color kMuted = Color(0xFF666666);
const Color kBorder = Color(0xFFE6E6E6);
const Color kSoft = Color(0xFFF2F2F2);

class ClientContractScreen extends StatefulWidget {
  const ClientContractScreen({
    super.key,
    required this.request,
    required this.onConfirm,
    this.showBackButton = true,
  });

  final Map<String, dynamic> request;
  final VoidCallback onConfirm;
  final bool showBackButton;

  @override
  State<ClientContractScreen> createState() => _ClientContractScreenState();
}

class _ClientContractScreenState extends State<ClientContractScreen> {
  final TextEditingController _signatureController = TextEditingController();
  final SignatureController _drawnSignatureController = SignatureController(
    penStrokeWidth: 2.6,
    penColor: kBlack,
    exportBackgroundColor: kWhite,
  );
  bool _accepted = false;
  bool _showContractDetails = false;
  bool _submitting = false;
  bool _externalSigning = false;
  bool _downloading = false;
  String _submitMessage = '';

  @override
  void initState() {
    super.initState();
    _signatureController.addListener(_handleSignatureChange);
  }

  @override
  void dispose() {
    _signatureController.removeListener(_handleSignatureChange);
    _signatureController.dispose();
    _drawnSignatureController.dispose();
    super.dispose();
  }

  void _handleSignatureChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final contractModel = _ContractModel.fromRequest(request);

    return ClientExperienceShell(
      title: 'Contrato',
      subtitle: 'Documento completo previo al checkout y liberacion operativa.',
      showBackButton: widget.showBackButton,
      trailing: const StatusBadge(label: 'Contrato', color: kBlack),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text(
            'Contrato',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: kBlack,
              height: 1,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            contractModel.routeLabel,
            style: const TextStyle(
              color: Color(0xFF625D55),
              fontSize: 16,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          _ContractHeroCard(model: contractModel),
          const SizedBox(height: 18),
          const _SectionBadge(
            title: 'Seccion 1',
            subtitle:
                'Resumen visible para revisar la reserva antes de firmar.',
          ),
          const SizedBox(height: 12),
          GlassInfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumen de la reserva',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                _ContractRow(label: 'Codigo', value: contractModel.code),
                _ContractRow(
                  label: 'Cliente',
                  value: contractModel.customerName,
                ),
                _ContractRow(
                  label: 'Representante',
                  value: contractModel.representativeName,
                ),
                _ContractRow(label: 'Ruta', value: contractModel.routeLabel),
                _ContractRow(
                  label: 'Salida',
                  value: contractModel.departureLabel,
                ),
                _ContractRow(
                  label: 'Aeronave',
                  value: contractModel.aircraftLabel,
                ),
                _ContractRow(
                  label: 'Categoria',
                  value: contractModel.categoryLabel,
                ),
                _ContractRow(
                  label: 'Servicio',
                  value: contractModel.serviceTier,
                ),
                _ContractRow(
                  label: 'Pasajeros',
                  value: contractModel.passengerLabel,
                ),
                _ContractRow(
                  label: 'Operador',
                  value: contractModel.operatorLabel,
                ),
                _ContractRow(
                  label: 'Importe total',
                  value: contractModel.finalPriceLabel,
                ),
                _ContractRow(
                  label: 'Deposito',
                  value: contractModel.depositLabel,
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
                  'Itinerario operativo',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                ...contractModel.legs.map(
                  (leg) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LegRow(leg: leg),
                  ),
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
                  'Datos bancarios del prestador del servicio',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                ..._bankAccounts.map(
                  (account) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BankCard(account: account),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _ContractLegalSection(
            isExpanded: _showContractDetails,
            onToggle:
                () => setState(() {
                  _showContractDetails = !_showContractDetails;
                }),
            children: [
              ..._definitions(contractModel).map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ContractSectionCard(section: section),
                ),
              ),
              ..._clauses(contractModel).map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ContractSectionCard(section: section),
                ),
              ),
            ],
          ),
          GlassInfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aceptacion y firma',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                const Text(
                  'La firma electronica tiene la misma validez que una firma autografa para efectos del flujo comercial y operativo dentro de Red Aviation.',
                  style: TextStyle(color: Color(0xFF3B3428), height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _signatureController,
                  decoration: InputDecoration(
                    labelText: 'Nombre completo para firma electronica',
                    hintText: contractModel.customerName,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 190,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Signature(
                      controller: _drawnSignatureController,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Dibuja tu firma dentro del recuadro.',
                        style: TextStyle(
                          color: Color(0xFF625D55),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed:
                          _submitting
                              ? null
                              : () {
                                _drawnSignatureController.clear();
                                setState(() {});
                              },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Limpiar'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _accepted,
                  onChanged: (value) {
                    setState(() {
                      _accepted = value ?? false;
                    });
                  },
                  title: const Text(
                    'Acepto los terminos del contrato y autorizo continuar al checkout.',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_submitMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _submitMessage,
                    style: const TextStyle(
                      color: Color(0xFF625D55),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _externalSigning || _submitting
                          ? null
                          : _openExternalSignature,
                  icon:
                      _externalSigning
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.open_in_new_rounded),
                  label: const Text('DocuSign'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: kBlack,
                    side: const BorderSide(color: kBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _downloading || _submitting ? null : _downloadContractPdf,
                  icon:
                      _downloading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.download_rounded),
                  label: const Text('PDF'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: kBlack,
                    side: const BorderSide(color: kBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _canContinue && !_submitting ? _signAndContinue : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: kBlack,
              foregroundColor: kWhite,
              disabledBackgroundColor: const Color(0xFFE5E5E5),
              disabledForegroundColor: const Color(0xFF999999),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child:
                _submitting
                    ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Text('Firmar y continuar'),
          ),
        ],
      ),
    );
  }

  bool get _canContinue =>
      _accepted &&
      _signatureController.text.trim().isNotEmpty &&
      _drawnSignatureController.isNotEmpty;

  Future<void> _signAndContinue() async {
    final request = widget.request;
    final contractModel = _ContractModel.fromRequest(request);
    final reservationId =
        request['id']?.toString() ??
        request['flight_request_id']?.toString() ??
        request['reservation_id']?.toString() ??
        '';

    if (reservationId.isEmpty) {
      setState(() {
        _submitMessage =
            'No se encontro el folio de reserva para guardar la firma.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _submitMessage = 'Guardando firma del contrato...';
    });

    try {
      final signatureBytes = await _drawnSignatureController.toPngBytes();
      if (signatureBytes == null || signatureBytes.isEmpty) {
        throw const ApiException('Dibuja tu firma antes de continuar.');
      }

      final signatureDataUrl =
          'data:image/png;base64,${base64Encode(signatureBytes)}';
      final payload = {
        'reservation_id': reservationId,
        'flight_request_id': reservationId,
        'booking_id': reservationId,
        'status': 'pending_payment',
        'workflow_status': 'pago pendiente',
        'contract_status': 'signed',
        'payment_status': 'pending',
        'signed_at': DateTime.now().toIso8601String(),
        'signature': {
          'type': 'drawn',
          'name': _signatureController.text.trim(),
          'data_url': signatureDataUrl,
        },
        'contract_snapshot': contractModel.toSnapshot(),
      };

      await ApiClient.instance.signClientContract(
        reservationId: reservationId,
        contractPayload: payload,
      );

      if (!mounted) return;
      setState(() {
        _submitMessage = 'Contrato firmado. Preparando pago...';
      });
      widget.onConfirm();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitMessage = 'No fue posible guardar la firma: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _openExternalSignature() async {
    final request = widget.request;
    final contractModel = _ContractModel.fromRequest(request);
    final reservationId = _reservationId(request);

    if (reservationId.isEmpty) {
      setState(() {
        _submitMessage =
            'No se encontro el folio de reserva para preparar DocuSign.';
      });
      return;
    }

    setState(() {
      _externalSigning = true;
      _submitMessage = 'Preparando enlace seguro de DocuSign...';
    });

    try {
      final payload = await ApiClient.instance.sendClientContractForSignature(
        reservationId: reservationId,
        contractPayload: {
          'contract_snapshot': contractModel.toSnapshot(),
          'return_context': 'mobile',
        },
      );
      final signingUrl = _extractSigningUrl(payload);
      if (signingUrl.isEmpty) {
        throw const ApiException(
          'El backend no devolvio un enlace de firma externo.',
        );
      }

      final uri = Uri.parse(signingUrl);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw const ApiException('No fue posible abrir DocuSign.');
      }

      if (!mounted) return;
      setState(() {
        _submitMessage =
            'DocuSign abierto. Al volver, actualiza Mis vuelos para ver el estado firmado.';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitMessage = 'No fue posible preparar DocuSign: $error';
      });
    } finally {
      if (mounted) setState(() => _externalSigning = false);
    }
  }

  Future<void> _downloadContractPdf() async {
    final reservationId = _reservationId(widget.request);
    if (reservationId.isEmpty) {
      setState(() {
        _submitMessage =
            'No se encontro el folio de reserva para descargar el contrato.';
      });
      return;
    }

    setState(() {
      _downloading = true;
      _submitMessage = 'Descargando contrato PDF...';
    });

    try {
      final bytes = await ApiClient.instance.downloadClientContractPdf(
        reservationId,
      );
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/contrato-$reservationId.pdf');
      await file.writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(file.path);

      if (!mounted) return;
      setState(() {
        _submitMessage =
            result.type == ResultType.done
                ? 'Contrato descargado y abierto.'
                : 'Contrato descargado en ${file.path}';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitMessage = 'No fue posible descargar el PDF: $error';
      });
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  String _reservationId(Map<String, dynamic> request) {
    return request['id']?.toString() ??
        request['flight_request_id']?.toString() ??
        request['reservation_id']?.toString() ??
        request['booking_id']?.toString() ??
        '';
  }

  String _extractSigningUrl(Map<String, dynamic> payload) {
    final data =
        payload['data'] is Map
            ? Map<String, dynamic>.from(payload['data'] as Map)
            : const <String, dynamic>{};
    final contract =
        payload['contract'] is Map
            ? Map<String, dynamic>.from(payload['contract'] as Map)
            : const <String, dynamic>{};
    final candidates = [
      payload['signing_url'],
      payload['signingUrl'],
      payload['recipient_view_url'],
      payload['recipientViewUrl'],
      payload['embedded_signing_url'],
      data['signing_url'],
      data['recipient_view_url'],
      contract['signing_url'],
      contract['recipient_view_url'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.startsWith('http://') || value.startsWith('https://')) {
        return value;
      }
    }

    return '';
  }
}

class _SectionBadge extends StatelessWidget {
  const _SectionBadge({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: kMuted,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: kText,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractLegalSection extends StatelessWidget {
  const _ContractLegalSection({
    required this.isExpanded,
    required this.onToggle,
    required this.children,
  });

  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionBadge(
          title: 'Seccion 2',
          subtitle:
              'Contrato legal completo. Este bloque inicia oculto para dar prioridad al resumen.',
        ),
        const SizedBox(height: 12),
        GlassInfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Texto completo del contrato',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onToggle,
                    icon: Icon(
                      isExpanded
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    label: Text(
                      isExpanded ? 'Ocultar contrato' : 'Mostrar contrato',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Puedes revisar primero la operacion, el itinerario y los datos de pago. Abre esta seccion solo cuando quieras leer el clausulado completo.',
                style: TextStyle(color: Color(0xFF625D55), height: 1.4),
              ),
            ],
          ),
        ),
        if (isExpanded) ...[const SizedBox(height: 16), ...children],
        const SizedBox(height: 18),
      ],
    );
  }
}

class _ContractHeroCard extends StatelessWidget {
  const _ContractHeroCard({required this.model});

  final _ContractModel model;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: kBlack,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroChip(label: model.code),
          const SizedBox(height: 16),
          Text(
            model.routeLabel,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: kWhite,
              height: 1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            model.departureLabel,
            style: const TextStyle(
              color: Color(0xFFBDBDBD),
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _DarkMetric(
                  label: 'Total',
                  value: model.finalPriceLabel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DarkMetric(
                  label: 'Depósito',
                  value: model.depositLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kWhite.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kWhite.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kWhite,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DarkMetric extends StatelessWidget {
  const _DarkMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWhite.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kWhite.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFBDBDBD),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kWhite,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractRow extends StatelessWidget {
  const _ContractRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                color: kMuted,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: kBlack,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegRow extends StatelessWidget {
  const _LegRow({required this.leg});

  final _ContractLeg leg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tramo ${leg.order}',
            style: const TextStyle(
              color: kMuted,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${leg.origin} → ${leg.destination}',
            style: const TextStyle(color: kBlack, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            leg.departure,
            style: const TextStyle(color: kMuted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({required this.account});

  final _BankAccount account;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account.bank,
            style: const TextStyle(color: kBlack, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text('Cuenta: ${account.account}'),
          Text('CLABE: ${account.clabe}'),
          Text('Beneficiario: ${account.beneficiary}'),
          Text('RFC: ${account.rfc}'),
        ],
      ),
    );
  }
}

class _ContractSectionCard extends StatelessWidget {
  const _ContractSectionCard({required this.section});

  final _ContractSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: kBlack,
            ),
          ),
          if (section.paragraphs.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...section.paragraphs.map(
              (paragraph) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  paragraph,
                  style: const TextStyle(
                    color: kMuted,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
          if (section.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...section.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• $item',
                  style: const TextStyle(
                    color: kMuted,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContractModel {
  _ContractModel({
    required this.code,
    required this.customerName,
    required this.representativeName,
    required this.routeLabel,
    required this.departureLabel,
    required this.aircraftLabel,
    required this.categoryLabel,
    required this.serviceTier,
    required this.passengerLabel,
    required this.operatorLabel,
    required this.finalPriceLabel,
    required this.depositLabel,
    required this.legs,
  });

  final String code;
  final String customerName;
  final String representativeName;
  final String routeLabel;
  final String departureLabel;
  final String aircraftLabel;
  final String categoryLabel;
  final String serviceTier;
  final String passengerLabel;
  final String operatorLabel;
  final String finalPriceLabel;
  final String depositLabel;
  final List<_ContractLeg> legs;

  static _ContractModel fromRequest(Map<String, dynamic> request) {
    final routeLabel = _routeLabel(request);
    return _ContractModel(
      code: _reservationCode(request),
      customerName:
          request['client_name']?.toString() ??
          request['customer_name']?.toString() ??
          request['name']?.toString() ??
          'Cliente Red Aviation',
      representativeName:
          request['client_representative']?.toString() ??
          request['customer_name']?.toString() ??
          request['name']?.toString() ??
          'Representante por confirmar',
      routeLabel: routeLabel,
      departureLabel: _formatDateTime(
        request['date']?.toString() ??
            request['departure_datetime']?.toString() ??
            request['created_at']?.toString() ??
            '',
      ),
      aircraftLabel:
          request['aircraft_name']?.toString() ??
          request['aircraft_model']?.toString() ??
          request['assigned_aircraft_model']?.toString() ??
          'Aeronave por confirmar',
      categoryLabel:
          request['aircraft_category']?.toString() ??
          request['cabin']?.toString() ??
          'Categoria ejecutiva validada',
      serviceTier:
          request['flight_package']?.toString() ??
          request['service_tier']?.toString() ??
          'Servicio ejecutivo privado',
      passengerLabel: '${request['passengers']?.toString() ?? '1'} pasajero(s)',
      operatorLabel:
          request['operator']?.toString() ??
          request['provider_name']?.toString() ??
          'Operador confirmado por SKY Group',
      finalPriceLabel: _priceLabel(request),
      depositLabel: _depositLabel(request),
      legs: _legs(request),
    );
  }

  Map<String, dynamic> toSnapshot() {
    return {
      'code': code,
      'customer_name': customerName,
      'representative_name': representativeName,
      'route': routeLabel,
      'departure': departureLabel,
      'aircraft': aircraftLabel,
      'category': categoryLabel,
      'service_tier': serviceTier,
      'passengers': passengerLabel,
      'operator': operatorLabel,
      'final_price': finalPriceLabel,
      'deposit': depositLabel,
      'legs':
          legs
              .map(
                (leg) => {
                  'order': leg.order,
                  'origin': leg.origin,
                  'destination': leg.destination,
                  'departure': leg.departure,
                },
              )
              .toList(),
    };
  }

  static String _reservationCode(Map<String, dynamic> request) {
    final raw =
        request['id']?.toString() ??
        request['flight_request_id']?.toString() ??
        '';
    if (raw.isEmpty) return 'SKY-PENDIENTE';
    return 'SKY-${raw.padLeft(4, '0')}';
  }

  static String _routeLabel(Map<String, dynamic> request) {
    final origin =
        request['origin']?.toString() ??
        request['base_airport']?.toString() ??
        'Origen';
    final destination = request['destination']?.toString() ?? 'Destino';
    return '$origin -> $destination';
  }

  static String _priceLabel(Map<String, dynamic> request) {
    final raw =
        request['formatted_final_price']?.toString() ??
        request['final_price_display']?.toString() ??
        request['estimated_total']?.toString() ??
        request['final_price']?.toString() ??
        '';
    if (raw.isNotEmpty) return raw;
    return 'Monto por confirmar';
  }

  static String _depositLabel(Map<String, dynamic> request) {
    final raw =
        request['deposit_amount']?.toString() ??
        request['deposit']?.toString() ??
        '';
    if (raw.isNotEmpty) return raw;
    return 'Por confirmar en Anexo A';
  }

  static List<_ContractLeg> _legs(Map<String, dynamic> request) {
    final legs = <_ContractLeg>[];
    final baseDate =
        request['date']?.toString() ??
        request['departure_datetime']?.toString() ??
        '';

    legs.add(
      _ContractLeg(
        order: 1,
        origin:
            request['origin']?.toString() ??
            request['base_airport']?.toString() ??
            'Origen',
        destination: request['destination']?.toString() ?? 'Destino',
        departure: _formatDateTime(baseDate),
      ),
    );

    final requirements = request['requirements'];
    if (requirements is List) {
      for (var i = 0; i < requirements.length; i++) {
        final leg = requirements[i];
        if (leg is! Map) continue;
        final item = Map<String, dynamic>.from(leg);
        final date =
            item['departure_datetime']?.toString() ??
            '${item['date'] ?? ''}T${item['time'] ?? '09:00'}';
        legs.add(
          _ContractLeg(
            order: i + 2,
            origin: item['origin']?.toString() ?? 'Origen',
            destination: item['destination']?.toString() ?? 'Destino',
            departure: _formatDateTime(date),
          ),
        );
      }
    }

    return legs;
  }

  static String _formatDateTime(String value) {
    if (value.trim().isEmpty) return 'Fecha por confirmar';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat("d 'de' MMMM 'de' y · h:mm a", 'es').format(parsed);
  }
}

class _ContractLeg {
  const _ContractLeg({
    required this.order,
    required this.origin,
    required this.destination,
    required this.departure,
  });

  final int order;
  final String origin;
  final String destination;
  final String departure;
}

class _BankAccount {
  const _BankAccount({
    required this.bank,
    required this.account,
    required this.clabe,
    required this.beneficiary,
    required this.rfc,
  });

  final String bank;
  final String account;
  final String clabe;
  final String beneficiary;
  final String rfc;
}

class _ContractSection {
  const _ContractSection({
    required this.title,
    this.paragraphs = const [],
    this.items = const [],
  });

  final String title;
  final List<String> paragraphs;
  final List<String> items;
}

const List<_BankAccount> _bankAccounts = [
  _BankAccount(
    bank: 'BANBAJIO',
    account: '046 76313 20201',
    clabe: '0304 209000 4337 2636',
    beneficiary: 'TRANSPORTACION EXITOSA BELLIKAI S.A. DE C.V.',
    rfc: 'TEB231030NU9',
  ),
  _BankAccount(
    bank: 'BANREGIO',
    account: '247 96234 0011',
    clabe: '05842 0000 150761410',
    beneficiary: 'TRANSPORTACION EXITOSA BELLIKAI S.A. DE C.V.',
    rfc: 'TEB231030NU9',
  ),
  _BankAccount(
    bank: 'BBVA',
    account: '0122 912627',
    clabe: '01243 800122 9126272',
    beneficiary: 'TRANSPORTACION EXITOSA BELLIKAI S.A. DE C.V.',
    rfc: 'TEB231030NU9',
  ),
];

List<_ContractSection> _definitions(_ContractModel model) => [
  _ContractSection(
    title: '1. Definiciones',
    items: [
      '1.1 Aeronave: cualquier aeronave asignada para la operacion descrita en esta reserva, incluyendo sustituciones por razones operativas o tecnicas.',
      '1.2 Autoridad de Aviacion: cualquier autoridad con jurisdiccion sobre aeronavegabilidad, permisos, slots o sobrevuelo aplicable a la operacion.',
      '1.3 Costo Total del Servicio: el monto total visible en el flujo comercial para esta reserva, actualmente ${model.finalPriceLabel}.',
      '1.4 Deposito: el monto requerido para garantizar el cumplimiento de las obligaciones del cliente, identificado como ${model.depositLabel}.',
      '1.5 Servicios Complementarios: catering, asistencia personalizada, bebidas, apoyo concierge y demas servicios sujetos a disponibilidad.',
    ],
  ),
];

List<_ContractSection> _clauses(_ContractModel model) => [
  _ContractSection(
    title: '2. Servicios contratados',
    paragraphs: [
      'El Prestador del Servicio proporcionara y/o coordinara a favor del Cliente los servicios de aviacion ejecutiva correspondientes a la ruta ${model.routeLabel}, con salida ${model.departureLabel}, aeronave ${model.aircraftLabel}, categoria ${model.categoryLabel} y ${model.passengerLabel}.',
    ],
  ),
  _ContractSection(
    title: '3. Costo total del servicio y deposito',
    paragraphs: [
      'El Cliente se compromete a pagar el Costo Total del Servicio, mas impuestos y tasas aplicables, conforme a la cotizacion y al presente contrato.',
      'Para esta operacion, el monto identificado en el flujo comercial es ${model.finalPriceLabel}. El deposito mostrado en esta reserva es ${model.depositLabel}.',
    ],
  ),
  _ContractSection(
    title: '4. Condiciones de pago',
    items: [
      'Todos los pagos deberan realizarse conforme a los tiempos definidos por el equipo comercial antes de la salida del vuelo.',
      'Los pagos podran realizarse en USD o su equivalente en moneda nacional conforme al tipo de cambio aplicable.',
      'Si el pago vence en un dia no habil, se recorrera al siguiente dia habil salvo instruccion operativa distinta.',
    ],
  ),
  _ContractSection(
    title: '5. Impuestos y tasas',
    paragraphs: [
      'El Cliente sera responsable del pago de impuestos, tarifas aeroportuarias, recargos operativos y demas cargos aplicables derivados de la operacion.',
    ],
  ),
  _ContractSection(
    title: '6. Equipaje y condiciones operativas',
    items: [
      'El transporte de equipaje quedara sujeto a limitaciones operativas, de seguridad y capacidad de la aeronave asignada.',
      'Cambios de horario, ruta, pernocta o servicios especiales pueden generar ajustes tarifarios adicionales.',
      'La operacion queda sujeta a slots, permisos, sobrevuelo, clima y disponibilidad final del operador.',
    ],
  ),
  _ContractSection(
    title: '7. Declaraciones del prestador del servicio',
    items: [
      'Cuenta con autorizaciones, permisos, licencias y capacidades operativas necesarias para coordinar y/o operar servicios de aviacion ejecutiva.',
      'Mantendra la aeronave y la operacion en condiciones seguras y conforme a la regulacion aplicable.',
      'Podra apoyarse en operadores aereos autorizados, contratistas y terceros especializados para cumplir la operacion.',
    ],
  ),
  _ContractSection(
    title: '8. Seguros',
    paragraphs: [
      'El Prestador del Servicio mantendra seguros vigentes sobre la aeronave y la operacion conforme a la legislacion aplicable.',
    ],
  ),
  _ContractSection(
    title: '9. Incumplimiento y terminacion',
    items: [
      'El impago oportuno, la cancelacion de permisos esenciales o el incumplimiento material de obligaciones podran constituir evento de incumplimiento.',
      'La parte no incumplidora podra exigir cumplimiento, terminar el contrato y reclamar los danos directos aplicables conforme a derecho.',
    ],
  ),
  _ContractSection(
    title: '10. Fuerza mayor',
    paragraphs: [
      'Ninguna de las partes sera responsable por retrasos o incumplimientos derivados de causas fuera de su control razonable, incluyendo clima, actos gubernamentales, restricciones operativas, eventos de seguridad, incidentes tecnicos o cierres aeroportuarios.',
    ],
  ),
  _ContractSection(
    title: '11. Indemnizacion',
    paragraphs: [
      'Cada parte asumira responsabilidad por sus actos conforme a la legislacion aplicable. El Prestador del Servicio respondera por la operacion salvo cuando exista negligencia grave o dolo imputable al Cliente.',
    ],
  ),
  _ContractSection(
    title: '12. Ley aplicable y jurisdiccion',
    paragraphs: [
      'Este Contrato se interpretara de acuerdo con las leyes de los Estados Unidos Mexicanos. Las partes se someten a la jurisdiccion de los tribunales competentes de la Ciudad de Mexico.',
    ],
  ),
  _ContractSection(
    title: '13. Politica de cancelacion',
    items: [
      'Mas de 7 dias antes del vuelo: 0% del costo total del servicio.',
      'Menos de 7 dias: 15% del costo total del servicio.',
      'Menos de 5 dias: 50% del costo total del servicio.',
      'Desde 3 dias naturales antes: 100% sin reembolso.',
    ],
  ),
  _ContractSection(
    title: '14. Validez de firmas electronicas',
    paragraphs: [
      'Las partes aceptan que la firma electronica utilizada dentro del flujo digital tiene plena validez legal y la misma fuerza que una firma autografa para efectos del proceso comercial y operativo.',
    ],
  ),
];
