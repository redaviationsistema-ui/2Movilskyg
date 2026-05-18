import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../utils/price_calculator.dart';
import '../utils/quote_calculator.dart';

class ReservationPdf {
  static final PdfColor _ink = PdfColor.fromInt(0xFF0F172A);
  static final PdfColor _steel = PdfColor.fromInt(0xFF475569);
  static final PdfColor _accent = PdfColor.fromInt(0xFF123456);
  static final PdfColor _accentSoft = PdfColor.fromInt(0xFFE8EEF5);
  static final PdfColor _line = PdfColor.fromInt(0xFFD6DFE9);
  static final PdfColor _panel = PdfColor.fromInt(0xFFF8FAFC);

  static Future<Uint8List> generate(reservation) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();
    final theme = pw.ThemeData.withFont(base: font, bold: bold);
    final pdf = pw.Document();

    final aircraft = reservation.selectedAircraft;
    final pax = aircraft?.capacityPassengers ?? 0;
    final route = reservation.routes.first;
    final startDate = reservation.startDate;
    final endDate = reservation.endDate ?? startDate;
    final totals = QuoteCalculator.calculate(reservation);
    final taxRate = (totals.taxRate * 100).toInt();
    final tripType =
        totals.isInternational ? "Vuelo Internacional" : "Vuelo Nacional";

    final logo = pw.MemoryImage(
      (await rootBundle.load("assets/logo.png")).buffer.asUint8List(),
    );

    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(20, 16, 20, 20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _topBar(logo),
              pw.SizedBox(height: 18),
              pw.Text(
                "Cotizacion Ejecutiva de Vuelo",
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                "Propuesta profesional de aviacion privada",
                style: pw.TextStyle(fontSize: 10, color: _steel),
              ),
              pw.SizedBox(height: 10),
              pw.Container(height: 1, color: _line),
              pw.SizedBox(height: 14),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _infoCard(
                      title: "Informacion del Cliente",
                      items: [
                        _InfoItem("Nombre", reservation.fullName),
                        _InfoItem("Correo", reservation.email ?? "-"),
                        _InfoItem("Telefono", reservation.phone ?? "-"),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: _infoCard(
                      title: "Perfil del Viaje",
                      items: [
                        _InfoItem("Aeronave", aircraft?.name ?? "-"),
                        _InfoItem(
                          "Ruta",
                          "${route.fromAirport?.name ?? "-"} a ${route.toAirport?.name ?? "-"}",
                        ),
                        _InfoItem("Tipo", tripType),
                        _InfoItem("Pasajeros", "${reservation.passengers}"),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              _sectionHeading("Tramos de Vuelo"),
              pw.SizedBox(height: 6),
              _legsTable(
                reservation,
                aircraft,
                startDate,
                endDate,
                totals.isInternational,
              ),
              pw.SizedBox(height: 14),
              _sectionHeading("Desglose Comercial"),
              pw.SizedBox(height: 6),
              _breakdownCard([
                _CostRow("Costo de Vuelo", totals.flightTotal),
                _CostRow("Overnight Crew", totals.overnightTotal),
                _CostRow("Gastos Operativos", totals.operationalExpenses),
                _CostRow("IVA ($taxRate%)", totals.taxAmount),
              ]),
              pw.SizedBox(height: 14),
              _totalBanner("TOTAL ESTIMADO", totals.totalPrice),
              pw.Spacer(),
              _footer(1, 2),
            ],
          );
        },
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(20, 20, 20, 24),
        footer: (context) => _footer(context.pageNumber, context.pagesCount),
        build:
            (context) => [
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: _accent,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "TERMINOS Y CONDICIONES",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "Acuerdo del servicio de aviacion privada",
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
              _title("USO DEL SERVICIO DE AVIACION PRIVADA"),
              _text(
                "El uso de la aeronave esta estrictamente limitado a fines de transporte privado, incluyendo viajes familiares, de negocios o recreativos. Queda estrictamente prohibido cualquier tipo de actividad comercial o de carga.",
              ),
              _title("SERVICIOS INCLUIDOS"),
              _text(
                "El jet privado incluye tarifas aeroportuarias, combustible, honorarios de tripulacion, minibar premium y snacks. Este servicio debe solicitarse con anticipacion por el pasajero para garantizar su disponibilidad.",
              ),
              _title("CAPACIDAD Y EQUIPAJE"),
              _text(
                "La capacidad maxima de la aeronave es de $pax pasajeros. Cada pasajero puede llevar una (1) maleta de hasta 50 libras y un (1) bolso de mano pequeno.",
              ),
              _title("PAGO Y DEPOSITO"),
              _text(
                "El pasajero debera pagar a Red Sky Group un deposito del 50% del costo total del viaje para asegurar el servicio de aviacion privada. El saldo restante debera liquidarse en su totalidad antes del abordaje.",
              ),
              _text(
                "Dependiendo del destino, Red Sky Group podra requerir un deposito mayor al 50% para cubrir gastos del viaje como combustible, servicios de handling o permisos de sobrevuelo.",
              ),
              _title("RESPONSABILIDAD DEL PASAJERO Y ACOMPANANTES"),
              _text(
                "El pasajero acepta utilizar y volar en la aeronave bajo su propio riesgo y responsabilidad, al igual que sus acompanantes. El pasajero y sus acompanantes confirman contar con seguro medico y seran responsables de cualquier gasto hospitalario en caso de accidente en la rampa del aeropuerto o instalaciones FBO.",
              ),
              _title("CUMPLIMIENTO DE INSTRUCCIONES DE SEGURIDAD"),
              _text(
                "Los pasajeros deberan cumplir en todo momento con todas las instrucciones y medidas de seguridad indicadas por el Capitan o Primer Oficial.",
              ),
              _text(
                "Si no se siguen las instrucciones de la tripulacion, Red Sky Group no sera responsable por accidentes ocurridos a bordo de la aeronave o en instalaciones aeroportuarias.",
              ),
              _title("PROHIBICIONES A BORDO"),
              _bullet("Arrojar papel sanitario o toallas en el inodoro."),
              _bullet(
                "Permanecer de pie durante el rodaje, despegue, aterrizaje o turbulencia.",
              ),
              _bullet(
                "Uso indebido de equipos electronicos o de entretenimiento.",
              ),
              _bullet("Consumo excesivo de alcohol."),
              _bullet("Posesion o uso de armas, drogas o sustancias ilegales."),
              _text(
                "Esta estrictamente prohibido transportar sustancias ilegales, explosivos, armas de fuego, municiones o cualquier objeto prohibido por las leyes de Mexico o Estados Unidos.",
              ),
              _text(
                "Esta prohibido transportar cantidades de dinero superiores a los limites legales sin declaracion. En Mexico el monto maximo sin declarar es de \$10,000 USD.",
              ),
              _title("DANOS Y COSTOS ADICIONALES"),
              _bullet(
                "Danos a equipos electronicos o de entretenimiento de la aeronave.",
              ),
              _bullet(
                "Quemaduras o manchas irreparables en asientos, piso o alfombras.",
              ),
              _bullet(
                "Mal funcionamiento del bano de la aeronave por uso indebido.",
              ),
              _bullet("Perdida o dano de mobiliario o amenidades a bordo."),
              _title("POLITICAS DE CANCELACION"),
              _text(
                "Para cancelar el servicio de aviacion privada, el pasajero debera notificar a Red Sky Group al menos 48 horas antes de la salida programada.",
              ),
              _text(
                "Cancelaciones realizadas con menos de 48 horas de anticipacion tendran un cargo de \$3,300 USD mas impuestos.",
              ),
              _text(
                "Las solicitudes de cancelacion deberan enviarse por escrito al correo Ventas@redskyg.com.",
              ),
              _title("EXENCION DE RESPONSABILIDAD"),
              _text(
                "Red Sky Group no sera responsable por acciones ilegales cometidas por el pasajero o sus acompanantes.",
              ),
              _text(
                "Los pasajeros aceptan indemnizar y mantener libre de responsabilidad a Red Sky Group y su personal ante cualquier reclamacion legal derivada de dichas acciones.",
              ),
              _title("CUMPLIMIENTO DE REGULACIONES"),
              _text(
                "Red Sky Group opera en estricto cumplimiento de las regulaciones de aviacion en Mexico y Estados Unidos. La responsabilidad del cumplimiento de las leyes relacionadas con bienes transportados o dinero en efectivo recae exclusivamente en el pasajero.",
              ),
              _title("RECHAZO DE SERVICIO"),
              _text(
                "Red Sky Group se reserva el derecho de negar el abordaje o terminar el servicio si se sospecha actividad ilegal. En estos casos no se realizara ningun reembolso.",
              ),
              _title("ACEPTACION DE TERMINOS Y CONDICIONES"),
              _text(
                "Al reservar y utilizar el jet privado de Red Sky Group, el pasajero y sus acompanantes reconocen y aceptan cumplir con todos los terminos y condiciones establecidos en este documento.",
              ),
            ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _topBar(pw.MemoryImage logo) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Image(logo, width: 72),
        pw.Container(
          width: 150,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _line, width: 1),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _metaRow("FECHA", DateTime.now().toString().split(' ')[0]),
              pw.SizedBox(height: 6),
              _metaRow("TIPO", "Reservacion"),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _metaRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: _steel,
          ),
        ),
        pw.Text(value, style: pw.TextStyle(fontSize: 9, color: _ink)),
      ],
    );
  }

  static pw.Widget _infoCard({
    required String title,
    required List<_InfoItem> items,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _panel,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 10),
          ...items.map(_detailPair),
        ],
      ),
    );
  }

  static pw.Widget _detailPair(_InfoItem item) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            item.label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _steel,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(item.value, style: pw.TextStyle(fontSize: 9.5, color: _ink)),
        ],
      ),
    );
  }

  static pw.Widget _sectionHeading(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: _ink,
      ),
    );
  }

  static pw.Widget _legsTable(
    reservation,
    aircraft,
    DateTime? startDate,
    DateTime? endDate,
    bool isInternational,
  ) {
    return pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: pw.BoxDecoration(
            color: _accentSoft,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            children: [
              _headerText("#", width: 20),
              _headerText("SALIDA", flex: 3),
              _headerText("LLEGADA", flex: 3),
              _headerText("DIST (NM)", width: 60, align: pw.TextAlign.right),
              _headerText("TIEMPO", width: 55, align: pw.TextAlign.right),
            ],
          ),
        ),
        ...List.generate(reservation.routes.length, (index) {
          final currentRoute = reservation.routes[index];
          final result = PriceCalculator.calculate(
            aircraft: aircraft,
            route: currentRoute,
            startDate: startDate,
            endDate: endDate,
            international: isInternational,
          );

          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            decoration: pw.BoxDecoration(
              color: index.isEven ? _panel : PdfColors.white,
              border: pw.Border(
                bottom: pw.BorderSide(color: _line, width: 0.6),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _bodyText("${index + 1}", width: 20),
                _bodyText(currentRoute.fromAirport?.name ?? "-", flex: 3),
                _bodyText(currentRoute.toAirport?.name ?? "-", flex: 3),
                _bodyText(
                  result.distanceNm.toStringAsFixed(0),
                  width: 60,
                  align: pw.TextAlign.right,
                ),
                _bodyText(
                  "${result.flightHours.toStringAsFixed(1)} hrs",
                  width: 55,
                  align: pw.TextAlign.right,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  static pw.Widget _headerText(
    String text, {
    int flex = 0,
    double width = 0,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    final child = pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: _accent,
      ),
    );

    if (flex > 0) return pw.Expanded(flex: flex, child: child);
    return pw.SizedBox(width: width, child: child);
  }

  static pw.Widget _bodyText(
    String text, {
    int flex = 0,
    double width = 0,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    final child = pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(fontSize: 8.5, color: _ink),
    );

    if (flex > 0) return pw.Expanded(flex: flex, child: child);
    return pw.SizedBox(width: width, child: child);
  }

  static pw.Widget _breakdownCard(List<_CostRow> rows) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _panel,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Descripcion",
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _steel,
                  ),
                ),
                pw.Text(
                  "Monto",
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _steel,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;

            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 7,
              ),
              decoration: pw.BoxDecoration(
                border:
                    index == 0
                        ? null
                        : pw.Border(
                          top: pw.BorderSide(color: _line, width: 0.6),
                        ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    row.label,
                    style: pw.TextStyle(fontSize: 9, color: _ink),
                  ),
                  pw.Text(
                    "\$${row.value.toStringAsFixed(2)}",
                    style: pw.TextStyle(fontSize: 9, color: _ink),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _totalBanner(String label, double amount) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: pw.BoxDecoration(
        color: _accent,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.Text(
            "\$${amount.toStringAsFixed(2)} USD",
            style: pw.TextStyle(
              fontSize: 17,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(int pageNumber, int pagesCount) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Column(
        children: [
          pw.Container(height: 1, color: _line),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "Red Sky Group",
                style: pw.TextStyle(fontSize: 8, color: _steel),
              ),
              pw.Text(
                "Pagina $pageNumber de $pagesCount",
                style: pw.TextStyle(fontSize: 8, color: _steel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _title(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12, bottom: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    );
  }

  static pw.Widget _text(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.justify,
        style: pw.TextStyle(fontSize: 9, color: _steel, lineSpacing: 2),
      ),
    );
  }

  static pw.Widget _bullet(String text) {
    return pw.Bullet(
      text: text,
      style: pw.TextStyle(fontSize: 9, color: _steel, lineSpacing: 2),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;

  const _InfoItem(this.label, this.value);
}

class _CostRow {
  final String label;
  final double value;

  const _CostRow(this.label, this.value);
}
