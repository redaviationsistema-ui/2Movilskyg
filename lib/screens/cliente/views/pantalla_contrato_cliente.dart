// ignore_for_file: unused_element

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/acceso_comercial_cliente.dart';
import '../../../core/cliente_api.dart';
import '../../../providers/proveedor_autenticacion.dart';
import '../tema_cliente.dart';
import '../widgets/widgets_experiencia_cliente.dart';

const Color kBg = ClientThemeColors.bg;
const Color kWhite = Color(0xFFFFFCF7);
const Color kBlack = Color(0xFF2B241D);
const Color kText = Color(0xFF332A20);
const Color kMuted = Color(0xFF766B5D);
const Color kBorder = Color(0xFFE2D6C3);
const Color kSoft = Color(0xFFF5EFE3);
const String kMobileDocuSignReturnScheme = 'redsky';
const String kDocuSignReturnPath = '/cliente/contrato/';

class ClientContractScreen extends StatefulWidget {
  const ClientContractScreen({
    super.key,
    required this.request,
    required this.onConfirm,
    this.onOpenTrips,
    this.showBackButton = true,
  });

  final Map<String, dynamic> request;
  final VoidCallback onConfirm;
  final VoidCallback? onOpenTrips;
  final bool showBackButton;

  @override
  State<ClientContractScreen> createState() => _ClientContractScreenState();
}

class _ClientContractScreenState extends State<ClientContractScreen>
    with WidgetsBindingObserver {
  final TextEditingController _signatureController = TextEditingController();
  final SignatureController _drawnSignatureController = SignatureController(
    penStrokeWidth: 2.6,
    penColor: kBlack,
    exportBackgroundColor: kWhite,
  );
  bool _accepted = false;
  bool _submitting = false;
  bool _externalSigning = false;
  bool _downloading = false;
  bool _waitingForExternalSignatureReturn = false;
  String _submitMessage = '';
  String _externalContractId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _signatureController.addListener(_handleSignatureChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _signatureController.removeListener(_handleSignatureChange);
    _signatureController.dispose();
    _drawnSignatureController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_waitingForExternalSignatureReturn) return;
    _validateExternalSignatureAfterReturn();
  }

  void _handleSignatureChange() {
    if (mounted) setState(() {});
  }

  Future<String> _assetToDataUrl(String assetPath) async {
    final bytes = await rootBundle.load(assetPath);
    final extension = assetPath.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    return 'data:image/$extension;base64,${base64Encode(bytes.buffer.asUint8List())}';
  }

  String _buildContractSourcePath(String reservationId) {
    final normalized = reservationId.trim();
    if (normalized.isEmpty) return '';
    return '/cliente/contrato/$normalized';
  }

  String _buildDocuSignReturnUrl({
    required String reservationId,
    required String flightRequestId,
  }) {
    return Uri(
      scheme: kMobileDocuSignReturnScheme,
      host: 'cliente',
      path: '/contrato',
      queryParameters: {
        'reservation_id': reservationId,
        if (flightRequestId.trim().isNotEmpty)
          'flight_request_id': flightRequestId.trim(),
        'docusign_return': '1',
        'refresh': 'contract_status',
      },
    ).toString();
  }

  String _buildContractPlainText(_ContractModel model) {
    final sections = [..._definitions(model), ..._clauses(model)];
    final buffer =
        StringBuffer()
          ..writeln('Contrato de prestacion de servicios de aviacion ejecutiva')
          ..writeln('Reserva: ${model.code}')
          ..writeln('Ruta: ${model.routeLabel}')
          ..writeln('Salida: ${model.compactDepartureLabel}')
          ..writeln('Cliente: ${model.customerName}')
          ..writeln('Representante: ${model.representativeName}')
          ..writeln('Aeronave: ${model.aircraftLabel}')
          ..writeln('Categoria: ${model.categoryLabel}')
          ..writeln('Servicio: ${model.serviceTier}')
          ..writeln('Pasajeros: ${model.passengerLabel}')
          ..writeln('Operador: ${model.operatorLabel}')
          ..writeln('Costo total: ${model.finalPriceLabel}')
          ..writeln()
          ..writeln('Incluye:');

    for (final item in _includesItems) {
      buffer.writeln('- $item');
    }

    buffer
      ..writeln()
      ..writeln('No incluye:');

    for (final item in _excludesItems) {
      buffer.writeln('- $item');
    }

    for (final section in sections) {
      buffer
        ..writeln()
        ..writeln(section.title);
      for (final paragraph in section.paragraphs) {
        buffer.writeln(paragraph);
      }
      for (final item in section.items) {
        buffer.writeln('- $item');
      }
    }

    return buffer.toString().trim();
  }

  String _buildContractHtmlDocument({
    required _ContractModel model,
    required String logoSrc,
    required String headerSrc,
  }) {
    final contractDate = _escapeHtml(model.compactDepartureLabel.split(' ').first);
    final summaryRows = '''
      <tr><th>Reserva</th><td>${_escapeHtml(model.code)}</td><th>Cliente</th><td>${_escapeHtml(model.customerName)}</td><th>Prestador comercial</th><td>SKY Group</td></tr>
      <tr><th>Operador aéreo</th><td>${_escapeHtml(model.operatorLabel)}</td><th>Ruta</th><td>${_escapeHtml(model.routeLabel)}</td><th>Salida</th><td>${_escapeHtml(model.compactDepartureLabel)}</td></tr>
      <tr><th>Aeronave</th><td>${_escapeHtml(model.aircraftLabel)}</td><th>Cabina</th><td>${_escapeHtml(model.categoryLabel)}</td><th>Pasajeros</th><td>${_escapeHtml(model.passengerLabel)}</td></tr>
      <tr><th>Pernocta</th><td>Sin pernocta registrada</td><th>Servicio</th><td>${_escapeHtml(model.serviceTier)}</td><th>Tramos</th><td>${model.legs.length}</td></tr>
      <tr><th>Costo total</th><td>${_escapeHtml(model.finalPriceLabel)}</td><th colspan="4"></th></tr>
    ''';

    final itineraryRows =
        model.legs
            .map(
              (leg) => '''
          <tr>
            <td>${leg.order}</td>
            <td>${_escapeHtml(leg.origin)}</td>
            <td>${_escapeHtml(leg.destination)}</td>
            <td>${_escapeHtml(_datePart(leg.rawDeparture))}</td>
            <td>${_escapeHtml(_timePart(leg.rawDeparture))}</td>
          </tr>
          ''',
            )
            .join();
    final coverCards =
        [
          ('Reserva', model.code),
          ('Ruta', model.routeLabel),
          ('Total', model.finalPriceLabel),
        ].map((item) {
          return '''
        <td>
          <span>${_escapeHtml(item.$1)}</span>
          <strong>${_escapeHtml(item.$2)}</strong>
        </td>
      ''';
        }).join();
    final includeRows =
        _includesItems.map((item) => '<li>${_escapeHtml(item)}</li>').join();
    final excludeRows =
        _excludesItems.map((item) => '<li>${_escapeHtml(item)}</li>').join();
    final considerationsRows =
        _considerations(
          model,
        ).map((item) => '<li>${_escapeHtml(item)}</li>').join();
    final definitionsRows =
        _definitions(model)
            .expand((section) => [...section.paragraphs, ...section.items])
            .map((item) => '<li>${_escapeHtml(item)}</li>')
            .join();
    final legalRows =
        [..._definitions(model), ..._clauses(model)].map((section) {
          final paragraphs =
              section.paragraphs
                  .map((item) => '<p>${_escapeHtml(item)}</p>')
                  .join();
          final items =
              section.items
                  .map((item) => '<li>${_escapeHtml(item)}</li>')
                  .join();
          return '<div class="contract-block contract-section"><h3>${_escapeHtml(section.title)}</h3>$paragraphs${items.isEmpty ? '' : '<ul class="contract-list">$items</ul>'}</div>';
        }).join();
    final accountCards = _bankAccounts
        .map(
          (account) => '''
            <article class="account-card contract-card">
              <strong>${_escapeHtml(account.bank)}</strong>
              <span>Cuenta: ${_escapeHtml(account.account)}</span>
              <span>CLABE: ${_escapeHtml(account.clabe)}</span>
              <span>Beneficiario: ${_escapeHtml(account.beneficiary)}</span>
              <span>RFC: ${_escapeHtml(account.rfc)}</span>
            </article>
          ''',
        )
        .join();

    return '''
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Contrato ${_escapeHtml(model.code)}</title>
  <style>
    @page { margin: 18px 18px 22px; }
    * { box-sizing: border-box; }
    body { margin: 0; padding: 18px; background: #f6f1e7; color: #111; font-family: DejaVu Sans, Arial, sans-serif; font-size: 12px; line-height: 1.5; }
    .contract-preview { display: grid; gap: 0.8rem; padding: 0; border-radius: 18px; background: transparent; }
    .contract-sheet { display: grid; gap: 0.7rem; overflow: hidden; border: 1px solid #ddd4c6; border-radius: 14px; background: #ffffff; box-shadow: none; }
    .contract-brandbar { overflow: hidden; background: #16202a; margin: 0 !important; border-radius: 0 !important; }
    .contract-brandbar__banner { display: block; width: 100% !important; height: auto !important; }
    .contract-sheet__body { position: relative; isolation: isolate; display: grid; gap: 0.8rem; padding: 10mm 12mm 12mm !important; border-top: 0; background: #fffdf9; }
    .contract-watermark { position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 0; opacity: 1; pointer-events: none; }
    .contract-watermark img { width: 72%; max-width: 34rem; opacity: 0.06; filter: grayscale(1); }
    .eyebrow { color: #8b6a24; font-size: 10px; font-weight: 800; letter-spacing: 0.08em; text-transform: uppercase; }
    .contract-badge { display: inline-flex; align-items: center; justify-content: center; padding: 0.35rem 0.7rem; border-radius: 999px; background: rgba(139, 106, 36, 0.16); color: #8b6a24; font-size: 10px; font-weight: 800; letter-spacing: 0.04em; }
    .contract-cover { position: relative; z-index: 1; display: grid; gap: 0.55rem; padding: 0.05rem 0 0.35rem; }
    .contract-cover__eyebrow-row { display: flex; flex-wrap: wrap; gap: 0.75rem; align-items: center; justify-content: space-between; }
    .contract-cover h1 { margin: 8px 0 10px !important; color: #111111; font-family: Georgia, 'Times New Roman', serif; font-size: 22px !important; line-height: 1.15 !important; font-weight: 700; }
    .contract-cover__route { margin: 0; color: #3c3328; font-size: 1rem; font-weight: 700; }
    .contract-cover__meta { display: flex; flex-wrap: wrap; gap: 0.35rem 1rem; color: #625d55; font-size: 10.5px !important; font-weight: 600; }
    .contract-cover__brief { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0.55rem; margin-top: 0.2rem; }
    .contract-commercial-intro { display: grid; gap: 0.45rem; break-inside: avoid; page-break-inside: avoid; }
    .contract-sheet__head { position: relative; z-index: 1; display: grid; gap: 0.3rem; justify-items: center; padding: 0.2rem 0 0.45rem; text-align: center; }
    .contract-sheet__head strong { display: block; font-size: 18px; letter-spacing: .03em; }
    .contract-sheet__head small { color: #625d55; font-weight: 700; }
    .contract-block { position: relative; z-index: 1; display: grid; gap: 0.42rem; }
    .contract-block h3 { margin: 10px 0 6px !important; color: #111111; font-family: Georgia, 'Times New Roman', serif; font-size: 13px !important; line-height: 1.2 !important; }
    .contract-block p, .contract-list li, .signature-card small, .annex-table th, .contract-sheet__head small, .contract-cover__meta span, .signature-sheet__header p, .signature-card__caption, .signature-contact-bar__item span { color: #625d55; }
    .account-card span { color: #111111; }
    .contract-opening strong, .contract-block strong, .annex-table td, .signature-card strong, .signature-sheet__summary strong, .summary-card strong, .cover-brief-card strong { color: #111111; }
    .contract-list { display: grid; gap: 0.28rem; margin: 0; padding-left: 1.15rem; }
    .contract-summary { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.6rem; }
    .summary-card, .contract-card, .signature-card, .account-card, .annex-note-card { border: 1px solid #e1d8ca; border-radius: 10px; background: #fcfaf6; box-shadow: none; }
    .summary-card { position: relative; display: grid; gap: 0.3rem; padding: 10px 14px !important; background: #fcfaf6; }
    .summary-card span, .summary-card small, .signature-card span, .contract-card span, .contract-card label, .contract-card .label, .contract-card small { color: #6d6252; font-size: 9px !important; letter-spacing: 0.06em; }
    .summary-card strong, .contract-card strong, .contract-card .value { font-size: 11px !important; line-height: 1.3 !important; }
    .summary-card--route strong { font-size: 1.08rem; }
    .cover-brief-card { display: grid; align-content: start; gap: 0.32rem; min-height: 4.3rem; padding: 0.75rem 0.85rem 0.8rem; }
    .cover-brief-card span { color: #8c7b63; font-size: 0.74rem; font-weight: 800; letter-spacing: 0.07em; text-transform: uppercase; }
    .annex-table-wrap, .accounts-grid, .signatures-grid { display: grid; gap: 0.75rem; }
    .annex-table { width: 100%; border-collapse: collapse; border: 1px solid #ddd4c6; border-radius: 8px; overflow: hidden; background: #fcfaf6; table-layout: fixed; font-size: 10px !important; }
    .annex-table th, .annex-table td { padding: 6px 8px !important; border-bottom: 1px solid #e2d8c9; text-align: left; vertical-align: top; word-break: normal; overflow-wrap: break-word; font-size: 10px !important; }
    .annex-table th { width: 16%; background: #f1eadc; font-weight: 800; text-transform: uppercase; letter-spacing: 0.03em; }
    .annex-table td { font-weight: 600; line-height: 1.35; }
    .annex-table__spacer { background: #faf8f3; }
    .annex-legs { display: grid; gap: 0.45rem; }
    .annex-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.85rem; }
    .annex-note-card { display: grid; gap: 0.55rem; padding: 0.85rem; }
    .accounts-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    .account-card { display: grid; gap: 0.45rem; padding: 1rem; break-inside: avoid; page-break-inside: avoid; }
    .signatures-section { gap: 0.85rem; padding: 0.25rem 0 0.05rem; break-before: page; page-break-before: always; min-height: calc(100vh - 6rem); align-content: start; }
    .signature-sheet__header { display: grid; gap: 0.3rem; max-width: 42rem; }
    .signature-sheet__header h3 { font-size: 24px !important; line-height: 1.05; font-family: Georgia, 'Times New Roman', serif; margin: 0; }
    .signature-sheet__summary { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0.55rem; padding: 0.7rem 0.8rem; border: 1px solid #e2d8c9; border-radius: 10px; background: #fbf8f1; }
    .signature-sheet__summary span { color: #5d5448; font-size: 0.92rem; line-height: 1.45; }
    .signatures-grid { grid-template-columns: minmax(0, 1fr); justify-items: center; }
    .signature-card.signature-block { width: min(100%, 58rem); justify-items: center; text-align: center; }
    .signature-card { display: grid; gap: 0.45rem; padding: 1rem; }
    .signature-card__role { color: #8b6a24 !important; font-size: 0.82rem; font-weight: 800; letter-spacing: 0.06em; text-transform: uppercase; }
    .signature-line { min-height: 5.5rem; margin-top: 0.45rem; padding: 0 0.2rem 0.35rem; border-bottom: 1.5px solid #111111; display: flex; align-items: flex-end; justify-content: center; overflow: hidden; width: min(100%, 54rem); }
    .signature-external-placeholder { display: grid; align-content: center; justify-items: center; gap: 0.3rem; min-height: 4.75rem; padding: 0.75rem; border: 1px dashed #d9cba8; border-radius: 14px; background: rgba(139, 106, 36, 0.06); text-align: center; width: 100%; }
    .signature-external-placeholder span { color: #6f6557; font-size: 0.78rem; font-weight: 800; letter-spacing: 0.05em; text-transform: uppercase; }
    .signature-external-placeholder strong { color: #1a1816; font-size: 0.95rem; }
    .docusign-anchor { color: transparent; font-size: 1px; line-height: 1px; user-select: none; }
    .signature-card__caption { color: #756958 !important; font-size: 0.9rem; }
    .signature-contact-bar { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px !important; margin-top: 0.15rem; padding-top: 12px !important; border-top: 1.5px solid #e4dbcd !important; }
    .signature-contact-bar__item { display: grid; align-content: start; gap: 3px !important; }
    .signature-contact-bar__item span { color: #8d7c64; font-size: 9px !important; font-weight: 800; letter-spacing: 0.05em !important; text-transform: uppercase; }
    .signature-contact-bar__item strong, .signature-contact-bar__item a { color: #1a1816; font-size: 1.18rem; line-height: 1.35; font-weight: 800; text-decoration: none; overflow-wrap: anywhere; }
    .contract-pdf p, .contract-pdf li, .contract-pdf td, .contract-pdf th, .contract-pdf div, .contract-pdf span, .contract-pdf small { font-size: 10.5px !important; line-height: 1.35 !important; }
    .contract-card, .contract-section, .contract-commercial-intro, .signature-block, .contract-table { break-inside: avoid; page-break-inside: avoid; }
  </style>
</head>
<body>
  <article class="contract-preview contract-pdf">
    <section class="contract-sheet">
      <header class="contract-brandbar">
        <img src="$headerSrc" alt="Sky Group" class="contract-brandbar__banner" />
      </header>
      <div class="contract-sheet__body">
        <div class="contract-watermark" aria-hidden="true">
          <img src="$logoSrc" alt="" />
        </div>
        <section class="contract-cover">
          <div class="contract-cover__eyebrow-row">
            <span class="eyebrow">Reserva ${_escapeHtml(model.code)}</span>
            <span class="contract-badge">CONFIDENCIAL · DOCUMENTO PARA FIRMA</span>
          </div>
          <h1>Contrato de prestación de servicios de aviación ejecutiva</h1>
          <p class="contract-cover__route">${_escapeHtml(model.routeLabel)}</p>
          <div class="contract-cover__meta">
            <span>Salida: ${_escapeHtml(model.compactDepartureLabel)}</span>
            <span>Pasajeros: ${_escapeHtml(model.passengerLabel)}</span>
            <span>Aeronave: ${_escapeHtml(model.aircraftLabel)}</span>
            <span>Tramos: ${model.legs.length}</span>
            <span>Total: ${_escapeHtml(model.finalPriceLabel)}</span>
          </div>
          <table class="mini-grid"><tr>$coverCards</tr></table>
        </section>

        <section class="contract-commercial-intro contract-section">
          <div class="contract-sheet__head">
            <span class="eyebrow">Contrato ${_escapeHtml(model.code)}</span>
            <strong>ANEXO A — DATOS COMERCIALES DE LA RESERVA</strong>
            <small>$contractDate</small>
          </div>
          <div class="contract-summary">
            <article class="summary-card summary-card--route contract-card">
              <span>Ruta contratada</span>
              <strong>${_escapeHtml(model.routeLabel)}</strong>
              <small>${_escapeHtml(model.compactDepartureLabel)}</small>
            </article>
            <article class="summary-card contract-card">
              <span>Aeronave</span>
              <strong>${_escapeHtml(model.aircraftLabel)}</strong>
              <small>${_escapeHtml(model.categoryLabel)}</small>
            </article>
            <article class="summary-card contract-card">
              <span>Servicio</span>
              <strong>${_escapeHtml(model.serviceTier)}</strong>
              <small>${_escapeHtml(model.passengerLabel)}</small>
            </article>
            <article class="summary-card contract-card">
              <span>Costo total</span>
              <strong>${_escapeHtml(model.finalPriceLabel)}</strong>
            </article>
          </div>
        </section>

        <div class="contract-block contract-section">
          <p class="contract-opening">El presente Contrato se celebra en la fecha <strong>$contractDate</strong>.</p>
          <p>ENTRE <strong>RED AVIATION COMPANY S.A. DE C.V.</strong>, sociedad constituida conforme a las leyes de los Estados Unidos Mexicanos, con domicilio en Circuito Alfonso G. de Orozco, Manzana 007, C.P. 50225, San Miguel Totoltepec, Toluca de Lerdo, Estado de México, legalmente representada en este acto por José Luis Hernández Ortiz, quien cuenta con facultades suficientes para este acto, en lo sucesivo el <strong>Prestador del Servicio</strong>.</p>
          <p>Y <strong>${_escapeHtml(model.customerName)}</strong>, persona física o moral según corresponda, con domicilio en <strong>Domicilio por confirmar</strong>, por su propio derecho o representada en este acto por <strong>${_escapeHtml(model.representativeName)}</strong>, quien declara contar con la capacidad jurídica y/o facultades suficientes para obligarse en los términos del presente Contrato, en lo sucesivo el <strong>Cliente</strong>.</p>
        </div>

        <div class="contract-block contract-section">
          <h3>CONSIDERANDO QUE</h3>
          <ul class="contract-list">$considerationsRows</ul>
        </div>

        <div class="contract-block contract-section">
          <h3>ANEXO A — RESUMEN COMERCIAL</h3>
          <div class="annex-table-wrap">
            <table class="annex-table contract-table"><tbody>$summaryRows</tbody></table>
          </div>
          <div class="annex-legs">
            <strong>Itinerario</strong>
            <div class="annex-table-wrap">
              <table class="annex-table contract-table">
                <thead>
                  <tr><th>Tramo</th><th>Origen</th><th>Destino</th><th>Fecha</th><th>Hora</th></tr>
                </thead>
                <tbody>$itineraryRows</tbody>
              </table>
            </div>
          </div>
          <div class="annex-grid">
            <article class="annex-note-card contract-card"><strong>Incluye</strong><ul class="contract-list">$includeRows</ul></article>
            <article class="annex-note-card contract-card"><strong>No incluye, salvo pacto expreso</strong><ul class="contract-list">$excludeRows</ul></article>
          </div>
        </div>

        <div class="contract-block contract-section">
          <h3>1. DEFINICIONES</h3>
          <ul class="contract-list">$definitionsRows</ul>
        </div>

        $legalRows

        <div class="contract-block contract-section">
          <h3>Condiciones operativas</h3>
          <ul class="contract-list">${_operationalConditions.map((p) => '<li>${_escapeHtml(p)}</li>').join()}</ul>
        </div>

        <div class="contract-block contract-section">
          <h3>CUENTAS PARA PAGO</h3>
          <div class="accounts-grid">$accountCards</div>
        </div>

        <div class="contract-block contract-section">
          <p>El Cliente reconoce y acepta que, por razones administrativas, fiscales, operativas o de cobranza, los pagos podrán realizarse a cuentas bancarias de terceros autorizados expresamente por el Prestador del Servicio.</p>
        </div>

        <div class="contract-block contract-section signatures-section">
          <div class="signature-sheet__header">
            <span class="eyebrow">Formalización</span>
            <h3>FIRMAS</h3>
            <p>Las partes aceptan el presente contrato mediante firma electrónica.</p>
            <p>La firma de este contrato se realizará de forma digital mediante DocuSign. Al completar la firma, el documento quedará registrado y asociado a esta reserva <strong>${_escapeHtml(model.code)}</strong>.</p>
          </div>
          <div class="signature-sheet__summary">
            <span><strong>Cliente:</strong> ${_escapeHtml(model.customerName)}</span>
            <span><strong>Ruta:</strong> ${_escapeHtml(model.routeLabel)}</span>
            <span><strong>Total:</strong> ${_escapeHtml(model.finalPriceLabel)}</span>
          </div>
          <div class="signatures-grid">
            <article class="signature-card contract-card signature-block">
              <span class="signature-card__role">Cliente</span>
              <strong>${_escapeHtml(model.customerName)}</strong>
              <small>Representante: ${_escapeHtml(model.representativeName)}</small>
              <small>Cargo: Cliente / Representante</small>
              <div class="signature-line">
                <div class="signature-external-placeholder" aria-hidden="true">
                  <span>Espacio reservado para firma digital</span>
                  <strong>Firma digital del cliente</strong>
                  <span class="docusign-anchor">/sig_cliente/</span>
                </div>
              </div>
              <small class="signature-card__caption">Pendiente de firma del cliente</small>
            </article>
          </div>
          <div class="signature-contact-bar">
            <div class="signature-contact-bar__item">
              <span>Contacto comercial</span>
              <strong><a href="mailto:sales@redskyg.com">sales@redskyg.com</a></strong>
            </div>
            <div class="signature-contact-bar__item">
              <span>Sitio web</span>
              <strong><a href="https://redskyg.com/mx">https://redskyg.com/mx</a></strong>
            </div>
            <div class="signature-contact-bar__item">
              <span>Teléfonos</span>
              <strong>+52 558 618 6576 · +52 722 112 6671 · +1 305 464 6394</strong>
            </div>
          </div>
        </div>
      </div>
    </section>
  </article>
</body>
</html>
''';
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _datePart(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? value : parts.first;
  }

  String _timePart(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return '';
    return parts.sublist(1).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final auth = context.watch<AuthProvider>();
    final contractModel = _ContractModel.fromRequest(
      request,
      fallbackCustomerName: auth.user?.companyName,
      fallbackRepresentativeName: auth.user?.name,
    );
    final legalSections = [
      ..._definitions(contractModel),
      ..._clauses(contractModel),
    ];

    return ClientExperienceShell(
      title: 'Contrato',
      subtitle: 'Documento completo previo al checkout y liberacion operativa.',
      showBackButton: widget.showBackButton,
      trailing: const StatusBadge(label: 'Contrato', color: kBlack),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
              children: [
                _ClientContractReplicaDocument(
                  model: contractModel,
                  legalSections: legalSections,
                ),
                const SizedBox(height: 18),
                _SignaturePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitleRow(
                        icon: Icons.draw_rounded,
                        title: 'Aceptacion y firma',
                        subtitle:
                            'Firma local o DocuSign para liberar el checkout.',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'La firma electronica tiene la misma validez que una firma autografa para efectos del flujo comercial y operativo dentro de Red Aviation.',
                        style: TextStyle(color: Color(0xFF3B3428), height: 1.4),
                      ),

                      const SizedBox(height: 12),
                      _DocuSignFlowCard(
                        isLoading: _externalSigning,
                        isWaitingForReturn: _waitingForExternalSignatureReturn,
                        onOpen:
                            _externalSigning || _submitting
                                ? null
                                : _openExternalSignature,
                      ),
                      const SizedBox(height: 14),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
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
                        activeColor: kBlack,
                      ),
                      if (_submitMessage.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _InlineContractMessage(message: _submitMessage),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
          _ContractActionBar(
            canSign: _canContinue && !_submitting,
            isSigning: _submitting,
            isDownloading: _downloading,
            onOpenTrips: widget.onOpenTrips,
            onDownload:
                _downloading || _submitting ? null : _downloadContractPdf,
            onSign: _canContinue && !_submitting ? _signAndContinue : null,
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
    final accessState = resolveCommercialAccessState(
      context.read<AuthProvider>().accessData,
    );
    if (!accessState.canReserve) {
      setState(() {
        _submitMessage = accessState.reservationBlockedMessage;
      });
      return;
    }

    final request = widget.request;
    final auth = context.read<AuthProvider>();
    final contractModel = _contractModelForRequest(request, auth: auth);
    final reservationId = _reservationId(request);
    final flightRequestId = _flightRequestId(request);

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
        'flight_request_id': flightRequestId,
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

      await _markContractReadyForPayment(
        reservationId: reservationId,
        payload: payload,
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
    final accessState = resolveCommercialAccessState(
      context.read<AuthProvider>().accessData,
    );
    if (!accessState.canReserve) {
      setState(() {
        _submitMessage = accessState.reservationBlockedMessage;
      });
      return;
    }

    final request = widget.request;
    final auth = context.read<AuthProvider>();
    final contractModel = _contractModelForRequest(request, auth: auth);
    final reservationId = _reservationId(request);
    final flightRequestId = _flightRequestId(request);
    final customerEmail = _firstMeaningfulText([
      request['client_email'],
      request['customer_email'],
      request['email'],
      auth.user?.email,
    ], fallback: '');

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
      final contractSnapshot = contractModel.toSnapshot(
        reservationId: reservationId,
        flightRequestId: flightRequestId,
        clientSignatureAnchor: '/sig_cliente/',
      );
      final assets = await Future.wait([
        _assetToDataUrl('assets/Logo.png'),
        _assetToDataUrl('assets/contract_margin.png'),
      ]);
      final fullContractHtml = _buildContractHtmlDocument(
        model: contractModel,
        logoSrc: assets[0],
        headerSrc: assets[1],
      );
      final fullContractPlainText = _buildContractPlainText(contractModel);
      final returnUrl = _buildDocuSignReturnUrl(
        reservationId: reservationId,
        flightRequestId: flightRequestId,
      );
      final payload = await ApiClient.instance.sendClientContractForSignature(
        reservationId: reservationId,
        contractPayload: {
          'id': reservationId,
          'reservation': reservationId,
          'booking_id': reservationId,
          'reservation_id': reservationId,
          'flight_request': flightRequestId,
          'flight_request_id': flightRequestId,
          'client_name': contractModel.customerName,
          'client_email': customerEmail,
          'route': contractModel.routeLabel,
          'flight_date': contractModel.compactDepartureLabel,
          'aircraft': contractModel.aircraftLabel,
          'total': contractModel.finalPriceLabel,
          'currency': 'USD',
          'return_url': returnUrl,
          'callback_url': returnUrl,
          'return_path': kDocuSignReturnPath,
          'contract_snapshot': contractSnapshot,
          'contract_html': fullContractHtml,
          'contract_markup': fullContractHtml,
          'contract_plain_text': fullContractPlainText,
          'document_html': fullContractHtml,
          'full_contract_html': fullContractHtml,
          'full_contract_text': fullContractPlainText,
          'source_contract_path': _buildContractSourcePath(reservationId),
          'document_source': 'client_contract_full_html',
          'regenerate': true,
          'docusign': {
            'provider': 'docusign',
            'client_signature_anchor': '/sig_cliente/',
          },
          'return_context': 'mobile',
        },
      );
      final signingUrl = _extractSigningUrl(payload);
      _externalContractId = _extractContractId(payload);
      if (signingUrl.isEmpty) {
        throw const ApiException(
          'El backend no devolvio un enlace de firma externo.',
        );
      }
      if (!_isDocuSignRecipientSigningUrl(signingUrl)) {
        throw const ApiException(
          'El backend devolvio una URL de DocuSign invalida para firma del cliente.',
        );
      }

      final uri = Uri.parse(signingUrl);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw const ApiException('No fue posible abrir DocuSign.');
      }

      if (!mounted) return;
      setState(() {
        _waitingForExternalSignatureReturn = true;
        _submitMessage =
            'DocuSign abierto. Al volver a la app validaremos la firma automaticamente.';
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

  Future<void> _validateExternalSignatureAfterReturn() async {
    if (_externalSigning || _submitting) return;

    final reservationId = _reservationId(widget.request);
    if (reservationId.isEmpty) return;

    setState(() {
      _externalSigning = true;
      _submitMessage = 'Validando firma de DocuSign...';
    });

    try {
      Map<String, dynamic>? statusPayload;
      for (var attempt = 0; attempt < 4; attempt++) {
        if (_externalContractId.isNotEmpty) {
          try {
            statusPayload = await ApiClient.instance.getClientContractStatus(
              _externalContractId,
            );
          } catch (_) {
            statusPayload = null;
          }
        }

        if (_contractReadyForPayment(statusPayload)) break;
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }

      if (!_contractReadyForPayment(statusPayload)) {
        if (!mounted) return;
        setState(() {
          _submitMessage =
              'DocuSign regreso a la app, pero el backend aun no confirma la firma. Actualiza Mis vuelos en unos segundos.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _externalContractId = '';
        _waitingForExternalSignatureReturn = false;
        _submitMessage = 'Contrato firmado. Preparando pago...';
      });
      widget.onConfirm();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitMessage =
            'No fue posible validar automaticamente la firma: $error';
      });
    } finally {
      if (mounted) setState(() => _externalSigning = false);
    }
  }

  Future<void> _markContractReadyForPayment({
    required String reservationId,
    required Map<String, dynamic> payload,
  }) {
    return ApiClient.instance.signClientContract(
      reservationId: reservationId,
      contractPayload: payload,
    );
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

  String _flightRequestId(Map<String, dynamic> request) {
    return request['flight_request_id']?.toString() ??
        request['request_id']?.toString() ??
        request['id']?.toString() ??
        request['reservation_id']?.toString() ??
        request['booking_id']?.toString() ??
        '';
  }

  _ContractModel _contractModelForRequest(
    Map<String, dynamic> request, {
    required AuthProvider auth,
  }) {
    return _ContractModel.fromRequest(
      request,
      fallbackCustomerName: auth.user?.companyName,
      fallbackRepresentativeName: auth.user?.name,
    );
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

  bool _isDocuSignRecipientSigningUrl(String url) {
    final normalized = url.toLowerCase();
    if (normalized.isEmpty) return false;

    const blockedTokens = [
      'tagger',
      'prepare',
      'sender',
      'correct',
      'edit',
      'documents/details',
      'addfields',
      'console',
    ];

    if (!normalized.contains('docusign')) return false;

    for (final token in blockedTokens) {
      if (normalized.contains(token)) return false;
    }

    return normalized.startsWith('http://') ||
        normalized.startsWith('https://');
  }

  String _extractContractId(Map<String, dynamic> payload) {
    return _firstText(payload, const [
      'contract_id',
      'contractId',
      'id',
      'docusign_contract_id',
    ]);
  }

  bool _contractReadyForPayment(Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) return false;
    final state = _nestedMap(payload['frontend_state']);
    final contract = _nestedMap(payload['contract']);
    final data = _nestedMap(payload['data']);
    final nestedState = _nestedMap(contract['frontend_state']);

    final ready =
        state['ready_for_payment'] == true ||
        nestedState['ready_for_payment'] == true ||
        data['ready_for_payment'] == true;
    final nextAction = _firstNonEmpty([
      _firstText(payload, const ['next_action']),
      _firstText(state, const ['next_action']),
      _firstText(nestedState, const ['next_action']),
    ]);
    final status = _firstNonEmpty([
      _firstText(payload, const [
        'docusign_status',
        'envelope_status',
        'status',
        'contract_status',
      ]),
      _firstText(contract, const ['docusign_status', 'status']),
      _firstText(state, const ['ui_status', 'docusign_status', 'status']),
      _firstText(nestedState, const ['ui_status', 'docusign_status', 'status']),
    ]);
    final signedPdf = _firstNonEmpty([
      _firstText(payload, const ['signed_pdf_url', 'signedPdfUrl']),
      _firstText(contract, const ['signed_pdf_url', 'signedPdfUrl']),
      _firstText(state, const ['signed_pdf_url', 'signedPdfUrl']),
      _firstText(nestedState, const ['signed_pdf_url', 'signedPdfUrl']),
    ]);

    final normalizedStatus = status.toLowerCase();
    return ready ||
        nextAction == 'go_to_payment' ||
        nextAction == 'go_to_history' ||
        normalizedStatus == 'completed' ||
        normalizedStatus == 'signed' ||
        signedPdf.isNotEmpty;
  }

  Map<String, dynamic> _nestedMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String _firstText(Map<String, dynamic>? payload, List<String> keys) {
    if (payload == null) return '';
    for (final key in keys) {
      final value = payload[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }

    final data = payload['data'];
    if (data is Map) {
      final value = _firstText(Map<String, dynamic>.from(data), keys);
      if (value.isNotEmpty) return value;
    }

    final contract = payload['contract'];
    if (contract is Map) {
      final value = _firstText(Map<String, dynamic>.from(contract), keys);
      if (value.isNotEmpty) return value;
    }

    final frontendState = payload['frontend_state'];
    if (frontendState is Map) {
      final value = _firstText(Map<String, dynamic>.from(frontendState), keys);
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
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
      padding: const EdgeInsets.all(12),
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
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCover extends StatelessWidget {
  const _DocumentCover({required this.model});

  final _ContractModel model;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4D8C5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kBlack,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: kWhite,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contrato de servicio',
                      style: TextStyle(
                        color: kBlack,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      model.code,
                      style: const TextStyle(
                        color: kMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            model.routeLabel,
            style: const TextStyle(
              color: Color(0xFF332A20),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            model.departureLabel,
            style: const TextStyle(
              color: Color(0xFF766B5D),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientContractReplicaDocument extends StatelessWidget {
  const _ClientContractReplicaDocument({
    required this.model,
    required this.legalSections,
  });

  final _ContractModel model;
  final List<_ContractSection> legalSections;

  @override
  Widget build(BuildContext context) {
    final summaryRows = [
      ('RESERVA', model.code, 'CLIENTE', model.customerName),
      ('OPERADOR', model.operatorLabel, 'RUTA', model.routeLabel),
      ('SALIDA', model.compactDepartureLabel, 'AERONAVE', model.aircraftLabel),
      ('CABINA', model.categoryLabel, 'PASAJEROS', model.passengerLabel),
      ('SERVICIO', model.serviceTier, 'COSTO TOTAL', model.finalPriceLabel),
      ('DEPOSITO', model.depositLabel, 'SALDO', model.balanceLabel),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3EC),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFFE6DAC7), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF7),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE2D5C1), width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: _ContractFrameHeader(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 430;
                      final reservationLabel = Text(
                        'RESERVA ${model.code}',
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8B6A24),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      );
                      final badge = Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4E6B9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'CONFIDENCIAL · DOCUMENTO PARA FIRMA',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF9A7A2A),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            reservationLabel,
                            const SizedBox(height: 10),
                            badge,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: reservationLabel),
                          const SizedBox(width: 12),
                          badge,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Contrato de prestación de servicios de aviación ejecutiva',
                    style: TextStyle(
                      color: kBlack,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    model.routeLabel,
                    style: const TextStyle(
                      color: Color(0xFF3A352E),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _ReplicaMetaText(
                        'Fecha de salida: ${model.compactDepartureLabel}',
                      ),
                      _ReplicaMetaText('Pasajeros: ${model.passengerLabel}'),
                      _ReplicaMetaText('Aeronave: ${model.aircraftLabel}'),
                      _ReplicaMetaText('Tramos: ${model.legs.length}'),
                      _ReplicaMetaText('Total: ${model.finalPriceLabel}'),
                    ],
                  ),
                const SizedBox(height: 22),
                const _ReplicaSectionTitle('ANEXO A — RESUMEN COMERCIAL'),
                const SizedBox(height: 12),
                ...summaryRows.map(
                  (row) => _ReplicaSummaryRow(
                    leftLabel: row.$1,
                    leftValue: row.$2,
                    rightLabel: row.$3,
                    rightValue: row.$4,
                  ),
                ),
                const SizedBox(height: 22),
                const _ReplicaSectionTitle('Itinerario'),
                const SizedBox(height: 12),
                _ReplicaItineraryTable(legs: model.legs),
                const SizedBox(height: 22),
                const _ReplicaSectionTitle('Desglose comercial'),
                const SizedBox(height: 12),
                _ReplicaBreakdownTable(model: model),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final vertical = constraints.maxWidth < 560;
                    final cards = [
                      _ReplicaBulletCard(
                        title: 'Incluye',
                        items: _includesItems,
                      ),
                      _ReplicaBulletCard(
                        title: 'No incluye, salvo pacto expreso',
                        items: _excludesItems,
                      ),
                    ];

                    if (vertical) {
                      return Column(
                        children: [
                          cards[0],
                          const SizedBox(height: 12),
                          cards[1],
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[1]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                const _ReplicaSectionTitle('Contrato'),
                const SizedBox(height: 10),
                ..._contractPreviewParagraphs(model).map(
                  (paragraph) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      paragraph,
                      style: const TextStyle(
                        color: Color(0xFF4E473D),
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const _ReplicaSectionTitle('Condiciones operativas'),
                const SizedBox(height: 10),
                ..._operationalConditions.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '• $item',
                      style: const TextStyle(
                        color: Color(0xFF4E473D),
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const _ReplicaSectionTitle('Clausulas'),
                const SizedBox(height: 12),
                ...legalSections.map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReplicaLegalCard(section: section),
                  ),
                ),
                const SizedBox(height: 18),
                const _ReplicaSectionTitle('Cuentas para pago'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      _bankAccounts
                          .map(
                            (account) => SizedBox(
                              width:
                                  MediaQuery.sizeOf(context).width > 520
                                      ? 240
                                      : double.infinity,
                              child: _ReplicaBankCard(account: account),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 14),
                const Text(
                  'El Cliente reconoce y acepta que, por razones administrativas, fiscales, operativas o de cobranza, los pagos podrán realizarse a cuentas bancarias de terceros autorizados expresamente por el Prestador del Servicio.',
                  style: TextStyle(
                    color: Color(0xFF4E473D),
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                  const _ReplicaSectionTitle('Firmas'),
                  const SizedBox(height: 18),
                  const Divider(color: Color(0xFF1C2430), thickness: 2),
                  const SizedBox(height: 10),
                  const Text(
                    'Teléfonos: +52 558 618 6576 · +52 722 112 6671 · +1 305 464 6394',
                    style: TextStyle(
                      color: Color(0xFF6F6557),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Correo: sales@redskyg.com · Sitio:https://redskyg.com/mx',
                    style: TextStyle(
                      color: Color(0xFF6F6557),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContractFrameHeader extends StatelessWidget {
  const _ContractFrameHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF17212B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF23303D)),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 2048 / 410,
        child: Image.asset(
          'assets/contract_margin.png',
          width: double.infinity,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) {
            return const ColoredBox(color: Color(0xFF17212B));
          },
        ),
      ),
    );
  }
}

class _ReplicaMetaText extends StatelessWidget {
  const _ReplicaMetaText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: const TextStyle(
        color: Color(0xFF6B645A),
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ReplicaSectionTitle extends StatelessWidget {
  const _ReplicaSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF2A241D),
        fontSize: 15,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ReplicaLegalCard extends StatelessWidget {
  const _ReplicaLegalCard({required this.section});

  final _ContractSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3D7C3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              color: Color(0xFF2A241D),
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (section.paragraphs.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...section.paragraphs.map(
              (paragraph) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  paragraph,
                  style: const TextStyle(
                    color: Color(0xFF4E473D),
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          if (section.items.isNotEmpty) ...[
            if (section.paragraphs.isNotEmpty) const SizedBox(height: 2),
            ...section.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• $item',
                  style: const TextStyle(
                    color: Color(0xFF4E473D),
                    height: 1.42,
                    fontWeight: FontWeight.w600,
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

class _ReplicaSummaryRow extends StatelessWidget {
  const _ReplicaSummaryRow({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 430;

        Widget pair(String label, String value) {
          return Row(
            children: [
              Expanded(
                flex: 2,
                child: _ReplicaTableCell(
                  label: label,
                  value: label,
                  isLabel: true,
                  compact: isCompact,
                ),
              ),
              Expanded(
                flex: 3,
                child: _ReplicaTableCell(
                  label: value,
                  value: value,
                  compact: isCompact,
                ),
              ),
            ],
          );
        }

        if (isCompact) {
          return Column(
            children: [
              pair(leftLabel, leftValue),
              pair(rightLabel, rightValue),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              flex: 2,
              child: _ReplicaTableCell(
                label: leftLabel,
                value: leftLabel,
                isLabel: true,
              ),
            ),
            Expanded(
              flex: 3,
              child: _ReplicaTableCell(label: leftValue, value: leftValue),
            ),
            Expanded(
              flex: 2,
              child: _ReplicaTableCell(
                label: rightLabel,
                value: rightLabel,
                isLabel: true,
              ),
            ),
            Expanded(
              flex: 3,
              child: _ReplicaTableCell(label: rightValue, value: rightValue),
            ),
          ],
        );
      },
    );
  }
}

class _ReplicaTableCell extends StatelessWidget {
  const _ReplicaTableCell({
    required this.label,
    required this.value,
    this.isLabel = false,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool isLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 48 : 56),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: isLabel ? const Color(0xFFF5EFE2) : kWhite,
        border: Border.all(color: const Color(0xFFE5DAC8)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        isLabel ? label : value,
        softWrap: true,
        style: TextStyle(
          color: isLabel ? const Color(0xFF746A5A) : const Color(0xFF2A241D),
          fontSize: compact ? (isLabel ? 10.5 : 12.5) : (isLabel ? 11.5 : 13.5),
          fontWeight: FontWeight.w800,
          height: compact ? 1.2 : 1.28,
        ),
      ),
    );
  }
}

class _ReplicaItineraryTable extends StatelessWidget {
  const _ReplicaItineraryTable({required this.legs});

  final List<_ContractLeg> legs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 430;

        if (isCompact) {
          return Column(
            children:
                legs
                    .map(
                      (leg) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5DAC8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TRAMO ${leg.order}',
                              style: const TextStyle(
                                color: Color(0xFF7D6F5B),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${leg.origin} → ${leg.destination}',
                              style: const TextStyle(
                                color: Color(0xFF2A241D),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              leg.rawDeparture,
                              style: const TextStyle(
                                color: Color(0xFF5A5247),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
          );
        }

        return Column(
          children: [
            const Row(
              children: [
                Expanded(child: _ReplicaHeadCell('TRAMO')),
                Expanded(child: _ReplicaHeadCell('ORIGEN')),
                Expanded(child: _ReplicaHeadCell('DESTINO')),
                Expanded(child: _ReplicaHeadCell('SALIDA')),
              ],
            ),
            ...legs.map(
              (leg) => Row(
                children: [
                  Expanded(child: _ReplicaBodyCell('${leg.order}')),
                  Expanded(child: _ReplicaBodyCell(leg.origin)),
                  Expanded(child: _ReplicaBodyCell(leg.destination)),
                  Expanded(child: _ReplicaBodyCell(leg.rawDeparture)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReplicaHeadCell extends StatelessWidget {
  const _ReplicaHeadCell(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFE2),
        border: Border.all(color: const Color(0xFFE5DAC8)),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFF746A5A),
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReplicaBodyCell extends StatelessWidget {
  const _ReplicaBodyCell(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: kWhite,
        border: Border.all(color: const Color(0xFFE5DAC8)),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFF2A241D),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ReplicaBreakdownTable extends StatelessWidget {
  const _ReplicaBreakdownTable({required this.model});

  final _ContractModel model;

  @override
  Widget build(BuildContext context) {
    final rows = [('COSTO TOTAL DEL SERVICIO', model.finalPriceLabel)];

    return Column(
      children:
          rows
              .map(
                (row) => Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _ReplicaTableCell(
                        label: row.$1,
                        value: row.$1,
                        isLabel: true,
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: _ReplicaTableCell(label: row.$2, value: row.$2),
                    ),
                  ],
                ),
              )
              .toList(),
    );
  }
}

class _ReplicaBulletCard extends StatelessWidget {
  const _ReplicaBulletCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3D7C3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF2A241D),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '• $item',
                style: const TextStyle(
                  color: Color(0xFF4E473D),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplicaBankCard extends StatelessWidget {
  const _ReplicaBankCard({required this.account});

  final _BankAccount account;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3D7C3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account.bank,
            style: const TextStyle(
              color: Color(0xFF2A241D),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuenta: ${account.account}',
            style: const TextStyle(color: kBlack, fontWeight: FontWeight.w600),
          ),
          Text(
            'CLABE: ${account.clabe}',
            style: const TextStyle(color: kBlack, fontWeight: FontWeight.w600),
          ),
          Text(
            'Beneficiario: ${account.beneficiary}',
            style: const TextStyle(color: kBlack, fontWeight: FontWeight.w600),
          ),
          Text(
            'RFC: ${account.rfc}',
            style: const TextStyle(color: kBlack, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ReplicaSignatureBox extends StatelessWidget {
  const _ReplicaSignatureBox({
    required this.title,
    required this.lineOne,
    required this.lineTwo,
  });

  final String title;
  final String lineOne;
  final String lineTwo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3D7C3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF2A241D),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(lineOne, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(lineTwo, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 28),
          const Divider(color: Color(0xFF6F6557), thickness: 1),
        ],
      ),
    );
  }
}

class _ContractProgressRail extends StatelessWidget {
  const _ContractProgressRail({
    required this.isAccepted,
    required this.canSignLocally,
    required this.waitingForDocuSign,
  });

  final bool isAccepted;
  final bool canSignLocally;
  final bool waitingForDocuSign;

  @override
  Widget build(BuildContext context) {
    final steps = [
      _ProgressStepData(
        label: 'Revisar',
        icon: Icons.fact_check_rounded,
        state: _ProgressStepState.done,
      ),
      _ProgressStepData(
        label: waitingForDocuSign ? 'DocuSign' : 'Firmar',
        icon: waitingForDocuSign ? Icons.verified_user_rounded : Icons.draw,
        state:
            waitingForDocuSign || canSignLocally
                ? _ProgressStepState.active
                : isAccepted
                ? _ProgressStepState.active
                : _ProgressStepState.todo,
      ),
      _ProgressStepData(
        label: 'Pagar',
        icon: Icons.payment_rounded,
        state: _ProgressStepState.todo,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E1D5)),
      ),
      child: Row(
        children:
            steps.asMap().entries.expand<Widget>((entry) {
              final isLast = entry.key == steps.length - 1;
              return [
                Expanded(child: _ProgressStep(data: entry.value)),
                if (!isLast)
                  Container(
                    width: 22,
                    height: 1.5,
                    color: const Color(0xFFE2D8C9),
                  ),
              ];
            }).toList(),
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({required this.data});

  final _ProgressStepData data;

  @override
  Widget build(BuildContext context) {
    final active = data.state != _ProgressStepState.todo;
    final done = data.state == _ProgressStepState.done;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color:
                done
                    ? const Color(0xFFE5F7EA)
                    : active
                    ? const Color(0xFFF3E6C9)
                    : const Color(0xFFF1ECE3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            done ? Icons.check_rounded : data.icon,
            color:
                done
                    ? const Color(0xFF14673A)
                    : active
                    ? const Color(0xFF8B6A24)
                    : const Color(0xFF8C7B63),
            size: 18,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          data.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? kBlack : const Color(0xFF8C7B63),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ProgressStepData {
  const _ProgressStepData({
    required this.label,
    required this.icon,
    required this.state,
  });

  final String label;
  final IconData icon;
  final _ProgressStepState state;
}

enum _ProgressStepState { todo, active, done }

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitleRow(icon: icon, title: title, subtitle: subtitle),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SectionTitleRow extends StatelessWidget {
  const _SectionTitleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8D3),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFE2D1B3)),
          ),
          child: Icon(icon, color: const Color(0xFF8B6A24), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: kBlack,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF6F6557),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SignaturePanel extends StatelessWidget {
  const _SignaturePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE1D4BD)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DocuSignFlowCard extends StatelessWidget {
  const _DocuSignFlowCard({
    required this.isLoading,
    required this.isWaitingForReturn,
    required this.onOpen,
  });

  final bool isLoading;
  final bool isWaitingForReturn;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final label =
        isWaitingForReturn
            ? 'Validar regreso de DocuSign'
            : 'Firmar con DocuSign';
    final caption =
        isWaitingForReturn
            ? 'Al volver a la app se consulta el estado real del contrato.'
            : 'Se abre la firma externa y el pago queda bloqueado hasta confirmar completed.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F1E4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3D4BC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E6C9),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFE2D1B3)),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF8B6A24),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DocuSign',
                      style: TextStyle(
                        color: kBlack,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      caption,
                      style: const TextStyle(
                        color: Color(0xFF62584A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DocuSignStep(label: 'Generar'),
              _DocuSignStep(label: 'Firmar'),
              _DocuSignStep(label: 'Habilitar pago'),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onOpen,
            icon:
                isLoading
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kBlack,
                      ),
                    )
                    : const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(label),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              backgroundColor: ClientThemeColors.accent,
              foregroundColor: kBlack,
              disabledBackgroundColor: const Color(0xFFE6DAC3),
              disabledForegroundColor: const Color(0xFF7C705F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocuSignStep extends StatelessWidget {
  const _DocuSignStep({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE8D7B7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF9A7A2A),
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8B6A24),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalSignatureCard extends StatelessWidget {
  const _LocalSignatureCard({
    required this.customerName,
    required this.signatureController,
    required this.drawnSignatureController,
    required this.isSubmitting,
    required this.onClear,
  });

  final String customerName;
  final TextEditingController signatureController;
  final SignatureController drawnSignatureController;
  final bool isSubmitting;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8DDCB)),
      ),
    );
  }
}

class _InlineContractMessage extends StatelessWidget {
  const _InlineContractMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F0E4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3D4BC)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF5F5446),
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      ),
    );
  }
}

class _ContractActionBar extends StatelessWidget {
  const _ContractActionBar({
    required this.canSign,
    required this.isSigning,
    required this.isDownloading,
    required this.onOpenTrips,
    required this.onDownload,
    required this.onSign,
  });

  final bool canSign;
  final bool isSigning;
  final bool isDownloading;
  final VoidCallback? onOpenTrips;
  final VoidCallback? onDownload;
  final VoidCallback? onSign;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: const BoxDecoration(
          color: kWhite,
          border: Border(top: BorderSide(color: Color(0xFFE7DFD2))),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 18,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: onDownload,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: kBlack,
                      side: const BorderSide(color: Color(0xFFDCD2C3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child:
                        isDownloading
                            ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.download_rounded),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSign,
                    icon:
                        isSigning
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: kWhite,
                              ),
                            )
                            : const Icon(Icons.check_rounded),
                    label: Text(
                      isSigning
                          ? 'Firmando...'
                          : canSign
                          ? 'Firmar y continuar'
                          : 'Completa firma local',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: kBlack,
                      foregroundColor: kWhite,
                      disabledBackgroundColor: const Color(0xFFE5E1DA),
                      disabledForegroundColor: const Color(0xFF8A8174),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (onOpenTrips != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenTrips,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Volver a tus vuelos'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: kBlack,
                    side: const BorderSide(color: Color(0xFFDCD2C3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContractSummaryGrid extends StatelessWidget {
  const _ContractSummaryGrid({required this.model});

  final _ContractModel model;

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryItem('Cliente', model.customerName, Icons.person_rounded),
      _SummaryItem(
        'Representante',
        model.representativeName,
        Icons.badge_rounded,
      ),
      _SummaryItem('Aeronave', model.aircraftLabel, Icons.flight_rounded),
      _SummaryItem(
        'Categoria',
        model.categoryLabel,
        Icons.airline_seat_recline_extra,
      ),
      _SummaryItem('Servicio', model.serviceTier, Icons.workspace_premium),
      _SummaryItem('Pasajeros', model.passengerLabel, Icons.groups_rounded),
      _SummaryItem('Operador', model.operatorLabel, Icons.verified_rounded),
      _SummaryItem('Total', model.finalPriceLabel, Icons.payments_rounded),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 430 ? 2 : 1;
        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 86,
          ),
          itemBuilder: (context, index) => _SummaryTile(item: items[index]),
        );
      },
    );
  }
}

class _ContractHistorySection extends StatelessWidget {
  const _ContractHistorySection({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final model = _ContractHistoryModel.fromRequest(request);
    final colors = _historyToneColors(model.tone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.$1,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.$3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: kWhite.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(model.icon, color: colors.$2, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      model.statusLabel,
                      style: TextStyle(
                        color: colors.$2,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                model.summary,
                style: const TextStyle(
                  color: Color(0xFF3B3428),
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...model.entries.asMap().entries.map((entry) {
          final isLast = entry.key == model.entries.length - 1;
          return _HistoryEntryTile(entry: entry.value, isLast: isLast);
        }),
      ],
    );
  }
}

class _HistoryEntryTile extends StatelessWidget {
  const _HistoryEntryTile({required this.entry, required this.isLast});

  final _HistoryEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = switch (entry.state) {
      _HistoryEntryState.done => (
        const Color(0xFFE5F7EA),
        const Color(0xFF14673A),
        const Color(0xFFCEEED9),
      ),
      _HistoryEntryState.active => (
        const Color(0xFFFFF3DE),
        const Color(0xFF9A6500),
        const Color(0xFFEBD8B1),
      ),
      _HistoryEntryState.todo => (
        const Color(0xFFF5F1EA),
        const Color(0xFF8A8174),
        const Color(0xFFE3DBCF),
      ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colors.$1,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: colors.$3),
              ),
              child: Icon(
                entry.state == _HistoryEntryState.done
                    ? Icons.check_rounded
                    : entry.icon,
                color: colors.$2,
                size: 17,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 46,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: const Color(0xFFE7DDCD),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F6F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE7DDCD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: const TextStyle(
                            color: kBlack,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.timeLabel,
                        style: const TextStyle(
                          color: Color(0xFF8C7B63),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF625D55),
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.item});

  final _SummaryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F6F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7DDCD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 18, color: const Color(0xFF8B6A24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8C7B63),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: Text(
                    item.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kBlack,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

enum _HistoryTone { info, pending, confirmed, completed, cancelled }

enum _HistoryEntryState { done, active, todo }

class _HistoryEntry {
  const _HistoryEntry({
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.icon,
    required this.state,
  });

  final String title;
  final String subtitle;
  final String timeLabel;
  final IconData icon;
  final _HistoryEntryState state;
}

class _ContractHistoryModel {
  const _ContractHistoryModel({
    required this.statusLabel,
    required this.summary,
    required this.icon,
    required this.tone,
    required this.entries,
  });

  final String statusLabel;
  final String summary;
  final IconData icon;
  final _HistoryTone tone;
  final List<_HistoryEntry> entries;

  static _ContractHistoryModel fromRequest(Map<String, dynamic> request) {
    final workflow = _normalizeHistoryStatus(
      request['workflow_status'] ??
          request['status'] ??
          request['flight_status'] ??
          request['reservation_status'],
    );
    final contractStatus = _normalizeHistoryStatus(
      request['contract_status'] ??
          request['signature_status'] ??
          request['docusign_status'],
    );
    final paymentStatus = _normalizeHistoryStatus(
      request['payment_status'] ??
          request['checkout_status'] ??
          request['payment'],
    );
    final providerStatus = _normalizeHistoryStatus(
      request['provider_status'] ??
          request['match_status'] ??
          request['supplier_status'],
    );
    final trackingStatus = _normalizeHistoryStatus(
      request['tracking_status'] ??
          request['tracking'] ??
          request['monitoring_status'],
    );

    final providerConfirmed =
        _containsHistoryAny(providerStatus, const [
          'accepted',
          'approved',
          'confirmed',
        ]) ||
        _containsHistoryAny(workflow, const [
          'provider accepted',
          'provider_accepted',
          'accepted',
          'approved',
          'matched',
          'confirmado',
        ]) ||
        _historyHasValue(request['provider_id']) ||
        _historyHasValue(request['assigned_aircraft_id']) ||
        _historyHasValue(request['assigned_provider_id']);

    final contractReady =
        _containsHistoryAny(contractStatus, const [
          'signed',
          'completed',
          'approved',
        ]) ||
        _historyAsBool(
          request['contract_signed'] ??
              request['contract_completed'] ??
              request['contract_ready'],
        ) ||
        _historyHasValue(request['contract_url']) ||
        _historyHasValue(request['contract_document_url']) ||
        _historyHasValue(request['signed_pdf_url']);

    final paymentDone =
        _containsHistoryAny(paymentStatus, const [
          'paid',
          'completed',
          'confirmed',
          'succeeded',
        ]) ||
        _historyAsBool(request['payment_completed'] ?? request['is_paid']) ||
        _historyHasValue(request['payment_reference']);

    final paymentPending =
        paymentDone ||
        _containsHistoryAny(paymentStatus, const [
          'pending',
          'processing',
          'awaiting',
        ]);

    final flightReady =
        _containsHistoryAny(workflow, const [
          'flight confirmed',
          'scheduled',
          'boarding',
          'departed',
          'airborne',
        ]) ||
        _containsHistoryAny(
          _normalizeHistoryStatus(request['flight_status']),
          const ['confirmed', 'scheduled', 'boarding', 'departed', 'airborne'],
        );

    final trackingReady =
        _containsHistoryAny(trackingStatus, const [
          'active',
          'live',
          'enabled',
        ]) ||
        _containsHistoryAny(workflow, const ['tracking']) ||
        _historyHasValue(request['tracking_url']) ||
        _historyHasValue(request['live_tracking_url']);

    final isCompleted = workflow.contains('completed');
    final isCancelled =
        workflow.contains('cancel') || workflow.contains('rejected');

    final createdAt = _historyFormatDate(
      _historyFirstText(request, const ['created_at', 'requested_at']),
      fallback: 'Registrada',
    );
    final providerAt = _historyFormatDate(
      _historyFirstText(request, const ['provider_confirmed_at', 'matched_at']),
      fallback: providerConfirmed ? 'Proveedor asignado' : 'Pendiente',
    );
    final contractAt = _historyFormatDate(
      _historyFirstText(request, const ['signed_at', 'contract_signed_at']),
      fallback:
          contractReady
              ? 'Contrato listo'
              : _containsHistoryAny(contractStatus, const ['pending', 'sent'])
              ? 'En espera'
              : 'Pendiente',
    );
    final paymentAt = _historyFormatDate(
      _historyFirstText(request, const ['paid_at', 'payment_confirmed_at']),
      fallback:
          paymentDone
              ? 'Pago validado'
              : paymentPending
              ? 'En proceso'
              : 'Pendiente',
    );
    final operationAt = _historyFormatDate(
      _historyFirstText(request, const [
        'completed_at',
        'departure_datetime',
        'start_datetime',
        'date',
      ]),
      fallback:
          isCompleted
              ? 'Cerrada'
              : trackingReady
              ? 'Tracking activo'
              : flightReady
              ? 'Operación lista'
              : isCancelled
              ? 'Cancelada'
              : 'Pendiente',
    );

    final entries = <_HistoryEntry>[
      _HistoryEntry(
        title: 'Reserva registrada',
        subtitle:
            'La solicitud fue creada y ya forma parte del flujo comercial.',
        timeLabel: createdAt,
        icon: Icons.event_available_rounded,
        state: _HistoryEntryState.done,
      ),
      _HistoryEntry(
        title: 'Proveedor y aeronave',
        subtitle:
            providerConfirmed
                ? 'La reserva ya tiene proveedor o aeronave asignada para continuar.'
                : 'Estamos validando disponibilidad y asignación operativa.',
        timeLabel: providerAt,
        icon: Icons.verified_user_rounded,
        state:
            providerConfirmed
                ? _HistoryEntryState.done
                : _HistoryEntryState.active,
      ),
      _HistoryEntry(
        title: 'Contrato',
        subtitle:
            contractReady
                ? 'El contrato fue firmado o quedó habilitado para avanzar a pago.'
                : _containsHistoryAny(contractStatus, const ['pending', 'sent'])
                ? 'El contrato fue generado y sigue pendiente de firma.'
                : 'Aún no se habilita la etapa de firma.',
        timeLabel: contractAt,
        icon: Icons.description_rounded,
        state:
            contractReady
                ? _HistoryEntryState.done
                : providerConfirmed
                ? _HistoryEntryState.active
                : _HistoryEntryState.todo,
      ),
      _HistoryEntry(
        title: 'Pago',
        subtitle:
            paymentDone
                ? 'El pago ya fue confirmado correctamente.'
                : paymentPending
                ? 'El pago está listo o en proceso de confirmación.'
                : 'El pago se habilita después de la firma del contrato.',
        timeLabel: paymentAt,
        icon: Icons.payments_rounded,
        state:
            paymentDone
                ? _HistoryEntryState.done
                : paymentPending
                ? _HistoryEntryState.active
                : contractReady
                ? _HistoryEntryState.active
                : _HistoryEntryState.todo,
      ),
      _HistoryEntry(
        title:
            isCancelled
                ? 'Reserva cerrada'
                : isCompleted
                ? 'Vuelo completado'
                : trackingReady
                ? 'Seguimiento activo'
                : 'Operación del vuelo',
        subtitle:
            isCancelled
                ? 'La reserva se cerró y ya no tiene seguimiento operativo activo.'
                : isCompleted
                ? 'La operación terminó y queda disponible dentro del historial.'
                : trackingReady
                ? 'El seguimiento en tiempo real ya está disponible para esta reserva.'
                : flightReady
                ? 'El vuelo está confirmado y avanzando a liberación operativa.'
                : 'Esta etapa se habilita al confirmar pago y salida.',
        timeLabel: operationAt,
        icon:
            isCancelled
                ? Icons.block_rounded
                : isCompleted
                ? Icons.task_alt_rounded
                : trackingReady
                ? Icons.radar_rounded
                : Icons.flight_takeoff_rounded,
        state:
            isCancelled || isCompleted
                ? _HistoryEntryState.done
                : trackingReady || flightReady
                ? _HistoryEntryState.active
                : _HistoryEntryState.todo,
      ),
    ];

    if (isCancelled) {
      return _ContractHistoryModel(
        statusLabel: 'Reserva cerrada',
        summary:
            'La operación fue cancelada o rechazada y el seguimiento quedó concluido.',
        icon: Icons.block_rounded,
        tone: _HistoryTone.cancelled,
        entries: entries,
      );
    }

    if (isCompleted) {
      return _ContractHistoryModel(
        statusLabel: 'Vuelo completado',
        summary: 'El flujo comercial y operativo terminó correctamente.',
        icon: Icons.task_alt_rounded,
        tone: _HistoryTone.completed,
        entries: entries,
      );
    }

    if (trackingReady || flightReady) {
      return _ContractHistoryModel(
        statusLabel: trackingReady ? 'Seguimiento activo' : 'Vuelo confirmado',
        summary:
            trackingReady
                ? 'La reserva ya está en fase de monitoreo operativo.'
                : 'Todo está listo para la operación del vuelo.',
        icon:
            trackingReady ? Icons.radar_rounded : Icons.flight_takeoff_rounded,
        tone: _HistoryTone.confirmed,
        entries: entries,
      );
    }

    if (paymentDone || paymentPending || contractReady) {
      return _ContractHistoryModel(
        statusLabel:
            paymentDone
                ? 'Pago confirmado'
                : paymentPending
                ? 'Pago en curso'
                : 'Contrato firmado',
        summary:
            paymentDone
                ? 'La reserva ya terminó la etapa comercial y pasa a operación.'
                : paymentPending
                ? 'La reserva está en checkout o esperando validación de pago.'
                : 'El contrato ya está listo y el siguiente paso es el pago.',
        icon:
            paymentDone
                ? Icons.payments_rounded
                : paymentPending
                ? Icons.credit_card_rounded
                : Icons.description_rounded,
        tone: paymentDone ? _HistoryTone.confirmed : _HistoryTone.pending,
        entries: entries,
      );
    }

    if (providerConfirmed) {
      return _ContractHistoryModel(
        statusLabel: 'Proveedor confirmado',
        summary:
            'La reserva avanzó a validación contractual para continuar con la firma.',
        icon: Icons.verified_rounded,
        tone: _HistoryTone.confirmed,
        entries: entries,
      );
    }

    return _ContractHistoryModel(
      statusLabel: 'Reserva activa',
      summary:
          'La reserva sigue en validación comercial antes de habilitar contrato y pago.',
      icon: Icons.schedule_rounded,
      tone: _HistoryTone.info,
      entries: entries,
    );
  }
}

(Color, Color, Color) _historyToneColors(_HistoryTone tone) {
  return switch (tone) {
    _HistoryTone.info => (
      const Color(0xFFEEF4FF),
      const Color(0xFF355DA8),
      const Color(0xFFD7E2F5),
    ),
    _HistoryTone.pending => (
      const Color(0xFFFFF2D8),
      const Color(0xFF9A6500),
      const Color(0xFFEBD8B1),
    ),
    _HistoryTone.confirmed => (
      const Color(0xFFE5F7EA),
      const Color(0xFF14673A),
      const Color(0xFFCEEED9),
    ),
    _HistoryTone.completed => (
      const Color(0xFFDDF7E6),
      const Color(0xFF0D6A34),
      const Color(0xFFC9EACE),
    ),
    _HistoryTone.cancelled => (
      const Color(0xFFFFE6E2),
      const Color(0xFFA13622),
      const Color(0xFFF0C8C1),
    ),
  };
}

String _normalizeHistoryStatus(dynamic value) =>
    value?.toString().trim().toLowerCase() ?? '';

bool _containsHistoryAny(String value, List<String> needles) {
  for (final needle in needles) {
    if (value.contains(needle.toLowerCase())) return true;
  }
  return false;
}

bool _historyHasValue(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isNotEmpty && text.toLowerCase() != 'null';
}

bool _historyAsBool(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes';
}

String _historyFirstText(Map<String, dynamic> request, List<String> keys) {
  for (final key in keys) {
    final value = request[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return '';
}

String _historyFormatDate(String raw, {required String fallback}) {
  if (raw.trim().isEmpty) return fallback;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return DateFormat("d MMM y · h:mm a", 'es').format(parsed);
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8EFD9), Color(0xFFEBD9B4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
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
          const SizedBox(height: 12),
          Text(
            model.routeLabel,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: kBlack,
              height: 1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            model.departureLabel,
            style: const TextStyle(
              color: Color(0xFF62584A),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DarkMetric(
                  label: 'Total',
                  value: model.finalPriceLabel,
                ),
              ),
              const SizedBox(width: 10),
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
        color: const Color(0xFFFFFBF4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4D5B7)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kBlack,
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
        color: const Color(0xFFFFFBF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4D5B7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF7E715F),
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
              color: kBlack,
              fontSize: 14,
              fontWeight: FontWeight.w900,
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
          Text(
            'Cuenta: ${account.account}',
            style: const TextStyle(color: kBlack, fontWeight: FontWeight.w600),
          ),
          Text(
            'CLABE: ${account.clabe}',
            style: const TextStyle(color: kBlack, fontWeight: FontWeight.w600),
          ),
          Text(
            'Beneficiario: ${account.beneficiary}',
            style: const TextStyle(color: kBlack, fontWeight: FontWeight.w600),
          ),
          Text(
            'RFC: ${account.rfc}',
            style: const TextStyle(color: kBlack, fontWeight: FontWeight.w600),
          ),
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
    required this.balanceLabel,
    required this.compactDepartureLabel,
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
  final String balanceLabel;
  final String compactDepartureLabel;
  final List<_ContractLeg> legs;

  String get depositDetailLabel => depositLabel;

  static _ContractModel fromRequest(
    Map<String, dynamic> request, {
    String? fallbackCustomerName,
    String? fallbackRepresentativeName,
  }) {
    final routeLabel = _routeLabel(request);
    final customerName = _firstMeaningfulText([
      request['client_name'],
      request['customer_name'],
      request['company_name'],
      request['client_company_name'],
      request['name'],
      fallbackCustomerName,
      fallbackRepresentativeName,
    ], fallback: 'Cliente por confirmar');
    final representativeName = _firstMeaningfulText([
      request['client_representative'],
      request['representative_name'],
      request['customer_representative'],
      request['customer_name'],
      request['name'],
      fallbackRepresentativeName,
      fallbackCustomerName,
    ], fallback: 'Representante por confirmar');

    return _ContractModel(
      code: _reservationCode(request),
      customerName: customerName,
      representativeName: representativeName,
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
      balanceLabel: _balanceLabel(request),
      compactDepartureLabel: _compactDateTime(
        request['date']?.toString() ??
            request['departure_datetime']?.toString() ??
            request['created_at']?.toString() ??
            '',
      ),
      legs: _legs(request),
    );
  }

  Map<String, dynamic> toSnapshot({
    String reservationId = '',
    String flightRequestId = '',
    String clientSignatureAnchor = '/sig_cliente/',
  }) {
    return {
      'contract_version': 'client_contract_v1',
      'contract_provider': 'docusign',
      'client_signature_anchor': clientSignatureAnchor,
      'reservation_id': reservationId,
      'flight_request_id': flightRequestId,
      'reservation_code': code,
      'code': code,
      'customer_name': customerName,
      'customer_representative': representativeName,
      'representative_name': representativeName,
      'customer_address': 'Domicilio por confirmar',
      'route': routeLabel,
      'departure_date': compactDepartureLabel,
      'departure': departureLabel,
      'aircraft': aircraftLabel,
      'aircraft_category': categoryLabel,
      'category': categoryLabel,
      'service_tier': serviceTier,
      'passengers': passengerLabel,
      'operator': operatorLabel,
      'contract_date': compactDepartureLabel.split(' ').first,
      'overnight': 'Sin pernocta registrada',
      'final_price': finalPriceLabel,
      'deposit_amount': depositLabel,
      'deposit': depositLabel,
      'balance': balanceLabel,
      'itinerary_segments':
          legs
              .map(
                (leg) => {
                  'order': leg.order,
                  'origin': leg.origin,
                  'destination': leg.destination,
                  'departure': leg.rawDeparture,
                  'departure_label': leg.departure,
                },
              )
              .toList(),
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
        request['reservation_code']?.toString() ??
        request['id']?.toString() ??
        request['flight_request_id']?.toString() ??
        '';
    if (raw.isEmpty) return 'SKY-PENDIENTE';
    if (raw.toUpperCase().contains('PV-') ||
        raw.toUpperCase().contains('SKY-')) {
      return raw.toUpperCase();
    }
    return 'SKY-${raw.padLeft(4, '0')}';
  }

  static String _routeLabel(Map<String, dynamic> request) {
    final origin =
        request['origin']?.toString() ??
        request['base_airport']?.toString() ??
        'Origen';
    final destination = request['destination']?.toString() ?? 'Destino';
    return '$origin → $destination';
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
    final total = _parseMoney(_priceLabel(request));
    if (total > 0) {
      return _formatUsd(total * 0.5);
    }
    return 'Por confirmar en Anexo A';
  }

  static String _balanceLabel(Map<String, dynamic> request) {
    final total = _parseMoney(_priceLabel(request));
    final deposit = _parseMoney(_depositLabel(request));
    if (total > 0) {
      return _formatUsd((total - deposit).clamp(0, double.infinity));
    }
    return 'Saldo por definir';
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
        rawDeparture: _rawDateTime(baseDate),
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
            rawDeparture: _rawDateTime(date),
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

  static String _compactDateTime(String value) {
    if (value.trim().isEmpty) return 'Fecha por confirmar';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed);
  }

  static String _rawDateTime(String value) {
    if (value.trim().isEmpty) return 'Fecha por confirmar';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed);
  }
}

String _firstMeaningfulText(
  List<dynamic> candidates, {
  required String fallback,
}) {
  for (final candidate in candidates) {
    final value = candidate?.toString().trim() ?? '';
    if (value.isEmpty) continue;

    final normalized = value.toLowerCase();
    if (normalized == 'null' ||
        normalized == 'cliente red aviation' ||
        normalized == 'red aviation') {
      continue;
    }

    return value;
  }

  return fallback;
}

class _ContractLeg {
  const _ContractLeg({
    required this.order,
    required this.origin,
    required this.destination,
    required this.departure,
    required this.rawDeparture,
  });

  final int order;
  final String origin;
  final String destination;
  final String departure;
  final String rawDeparture;
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

const List<String> _includesItems = [
  'Aeronave y tripulación asignada para la ruta contratada.',
  'Coordinación operativa y seguimiento comercial de SKY Group / Red Aviation.',
  'Combustible y operación contemplados en la cotización validada.',
  'Uso de aeronave conforme al itinerario confirmado en este Anexo A.',
];

const List<String> _excludesItems = [
  'Catering especial no contemplado expresamente.',
  'Transporte terrestre, hospedaje o concierge fuera del alcance contratado.',
  'Cambios de itinerario solicitados por el Cliente después de la firma.',
  'Tiempos de espera extraordinarios, permisos especiales o costos por reprogramación.',
];

const List<String> _operationalConditions = [
  'Pago requerido antes de confirmación final.',
  'Operación sujeta a condiciones de seguridad y slot.',
  'Cualquier cambio relevante queda registrado en historial operativo.',
];

List<String> _contractPreviewParagraphs(_ContractModel model) => [
  'El presente Contrato se celebra en fecha ${model.compactDepartureLabel.split(' ').first} entre RED AVIATION COMPANY S.A. DE C.V. y ${model.customerName}, representado por ${model.representativeName}, con domicilio en Domicilio por confirmar.',
  'El servicio contratado corresponde a la ruta ${model.routeLabel}, con salida programada para ${model.compactDepartureLabel}, aeronave ${model.aircraftLabel}, categoría ${model.categoryLabel} y ${model.passengerLabel}.',
  'El costo total del servicio asciende a ${model.finalPriceLabel}. ',
];

List<String> _considerations(_ContractModel model) => [
  'Que RED AVIATION COMPANY S.A. DE C.V. cuenta con la capacidad comercial y operativa para coordinar servicios de aviación ejecutiva privada.',
  'Que el Cliente ha solicitado la prestación del servicio correspondiente a la ruta ${model.routeLabel}, conforme a la cotización validada.',
  'Que ambas partes reconocen y aceptan la información comercial, operativa y económica contenida en el presente Contrato y su Anexo A.',
];

double _parseMoney(String value) {
  final normalized = value.replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (normalized.isEmpty) return 0;

  if (normalized.contains(',') && normalized.contains('.')) {
    if (normalized.lastIndexOf(',') > normalized.lastIndexOf('.')) {
      return double.tryParse(
            normalized.replaceAll('.', '').replaceAll(',', '.'),
          ) ??
          0;
    }
    return double.tryParse(normalized.replaceAll(',', '')) ?? 0;
  }

  if (RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(normalized)) {
    return double.tryParse(normalized.replaceAll(',', '')) ?? 0;
  }

  if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(normalized)) {
    return double.tryParse(normalized.replaceAll('.', '')) ?? 0;
  }

  return double.tryParse(normalized.replaceAll(',', '.')) ?? 0;
}

String _formatUsd(num value) {
  return NumberFormat.currency(
    locale: 'en_US',
    symbol: r'$',
    decimalDigits: 2,
  ).format(value);
}

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
