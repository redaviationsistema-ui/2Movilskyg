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
        totals.isInternational ? "International Charter" : "National Charter";

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
                "Executive Flight Quote",
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                "Professional private aviation quotation",
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
                      title: "Client Information",
                      items: [
                        _InfoItem("Name", reservation.fullName),
                        _InfoItem("Email", reservation.email ?? "-"),
                        _InfoItem("Phone", reservation.phone ?? "-"),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: _infoCard(
                      title: "Trip Profile",
                      items: [
                        _InfoItem("Aircraft", aircraft?.name ?? "-"),
                        _InfoItem(
                          "Route",
                          "${route.fromAirport?.name ?? "-"} to ${route.toAirport?.name ?? "-"}",
                        ),
                        _InfoItem("Trip Type", tripType),
                        _InfoItem("Passengers", "${reservation.passengers}"),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              _sectionHeading("Flight Legs"),
              pw.SizedBox(height: 6),
              _legsTable(
                reservation,
                aircraft,
                startDate,
                endDate,
                totals.isInternational,
              ),
              pw.SizedBox(height: 14),
              _sectionHeading("Commercial Breakdown"),
              pw.SizedBox(height: 6),
              _breakdownCard([
                _CostRow("Flight Cost", totals.flightTotal),
                _CostRow("Overnight Crew", totals.overnightTotal),
                _CostRow("Operational Expenses", totals.operationalExpenses),
                _CostRow("Tax ($taxRate%)", totals.taxAmount),
              ]),
              pw.SizedBox(height: 14),
              _totalBanner("TOTAL ESTIMATED BALANCE", totals.totalPrice),
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
                      "TERMS AND CONDITIONS",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "Private jet charter service agreement",
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
              _title("USE OF PRIVATE AVIATION SERVICE"),
              _text(
                "The use of the aircraft is strictly limited to private transportation purposes, including family, business, and leisure travel. Any commercial or cargo activities of any kind are expressly prohibited.",
              ),
              _title("INCLUDED SERVICES"),
              _text(
                "The private jet includes airport fees, fuel, crew fees, a premium minibar, and snacks. This service must be requested in advance by the passenger to ensure proper delivery.",
              ),
              _title("CAPACITY AND LUGGAGE"),
              _text(
                "The maximum capacity of the aircraft is $pax passengers. Each passenger is permitted one (1) 50-pound bag and one (1) small handbag.",
              ),
              _title("PAYMENT AND DEPOSIT"),
              _text(
                "The passenger must pay Red Sky Group a deposit of 50% of the total trip cost to secure the private aviation service. The remaining balance must be paid in full prior to boarding.",
              ),
              _text(
                "Depending on the destination, Red Sky Group may require a deposit greater than 50% to cover trip expenses such as fuel, handling, and overflight permits.",
              ),
              _title("PASSENGER AND COMPANIONS RESPONSIBILITY"),
              _text(
                "The passenger agrees to use and fly in the aircraft at their own risk and responsibility, as do their companions. The passenger and their companions confirm that they have medical insurance and will be responsible for any hospital expenses in the event of an accident at the airport ramp or FBO facilities.",
              ),
              _title("COMPLIANCE WITH SAFETY INSTRUCTIONS"),
              _text(
                "Passengers must comply at all times with all instructions and safety measures indicated by the Captain or First Officer.",
              ),
              _text(
                "If crew instructions are not followed, Red Sky Group shall not be liable for any accidents occurring onboard the aircraft or airport facilities.",
              ),
              _title("PROHIBITIONS ONBOARD THE AIRCRAFT"),
              _bullet("Throwing sanitary paper or towels into the toilet."),
              _bullet(
                "Standing while the aircraft is taxiing, taking off, landing, or during turbulence.",
              ),
              _bullet("Improper use of electronic or entertainment equipment."),
              _bullet("Excessive alcohol consumption."),
              _bullet(
                "Possession or use of weapons, drugs, or illegal substances.",
              ),
              _text(
                "Transporting illegal substances, explosives, firearms, ammunition, or any items prohibited under the laws of Mexico or the United States is strictly forbidden.",
              ),
              _text(
                "Transporting cash amounts exceeding legal limits without declaration is prohibited. In Mexico, the maximum amount without declaration is \$10,000 USD.",
              ),
              _title("DAMAGES AND ADDITIONAL COSTS"),
              _bullet(
                "Damage to aircraft electronic or entertainment equipment.",
              ),
              _bullet(
                "Burns or irreparable stains on seats, flooring or carpets.",
              ),
              _bullet("Malfunction of aircraft toilet due to improper use."),
              _bullet("Loss or damage to onboard furniture or amenities."),
              _title("CANCELLATION POLICIES"),
              _text(
                "To cancel the private aviation service, the passenger must notify Red Sky Group at least 48 hours before the scheduled departure.",
              ),
              _text(
                "Cancellations made less than 48 hours before departure will incur a charge of \$3,300 USD plus tax.",
              ),
              _text(
                "Cancellation requests must be submitted in writing to Ventas@redskyg.com.",
              ),
              _title("DISCLAIMER OF LIABILITY"),
              _text(
                "Red Sky Group shall not be liable for illegal actions committed by the passenger or their companions.",
              ),
              _text(
                "Passengers agree to indemnify and hold harmless Red Sky Group and its personnel from any legal claims resulting from such actions.",
              ),
              _title("COMPLIANCE WITH REGULATIONS"),
              _text(
                "Red Sky Group operates in strict compliance with aviation regulations in Mexico and the United States. Responsibility for compliance with laws related to transported goods or cash rests solely with the passenger.",
              ),
              _title("REFUSAL OF SERVICE"),
              _text(
                "Red Sky Group reserves the right to refuse boarding or terminate services if illegal activity is suspected. No refund will be provided in such cases.",
              ),
              _title("ACCEPTANCE OF TERMS AND CONDITIONS"),
              _text(
                "By booking and using the private jet of Red Sky Group, the passenger and their companions acknowledge and agree to comply with all terms and conditions set forth in this document.",
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
              _metaRow("DATE", DateTime.now().toString().split(' ')[0]),
              pw.SizedBox(height: 6),
              _metaRow("TYPE", "Reservation"),
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
              _headerText("DEPARTURE", flex: 3),
              _headerText("ARRIVAL", flex: 3),
              _headerText("DIST (NM)", width: 60, align: pw.TextAlign.right),
              _headerText("TIME", width: 55, align: pw.TextAlign.right),
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
                  "Description",
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _steel,
                  ),
                ),
                pw.Text(
                  "Amount",
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
                "Page $pageNumber of $pagesCount",
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
