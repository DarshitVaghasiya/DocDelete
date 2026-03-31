import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:doc_delete/Models/department_model.dart';
import 'package:doc_delete/Models/get_all_manifest_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

ByteData? _fontData;
ByteData? _boldFontData;
ByteData? _logoData;

Future<Uint8List> generateManifestPdf(
  GetAllManifestModel manifest, {
  String technicianName = "",
}) async {
  _fontData ??= await rootBundle.load("assets/Fonts/Roboto-Regular.ttf");
  _boldFontData ??= await rootBundle.load("assets/Fonts/Roboto-Bold.ttf");
  _logoData ??= await rootBundle.load("assets/images/DocDelete.png");

  final args = {
    'manifest': manifest,
    'fontData': _fontData!,
    'boldFontData': _boldFontData!,
    'logoData': _logoData!,
    'technicianName': technicianName,
  };

  if (kIsWeb) {
    return Future.microtask(() => _buildPdfInIsolate(args));
  } else {
    return Isolate.run(() => _buildPdfInIsolate(args));
  }
}

Future<Uint8List> _buildPdfInIsolate(Map<String, dynamic> args) async {
  final GetAllManifestModel manifest = args['manifest'];
  final ByteData fontData = args['fontData'];
  final ByteData boldFontData = args['boldFontData'];
  final ByteData logoData = args['logoData'];
  final String technicianName = args['technicianName'] ?? "";

  final font = pw.Font.ttf(fontData);
  final boldFont = pw.Font.ttf(boldFontData);
  final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: boldFont),
  );
  final unitList = manifest.units;
  final minRows = 7;
  final totalRows = unitList.length > minRows ? unitList.length : minRows;

  pw.Widget buildSignatureSync(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return pw.SizedBox(width: 120);
    }

    try {
      final cleanedBase64 = base64String.contains(',')
          ? base64String.split(',').last
          : base64String;

      final bytes = base64Decode(cleanedBase64);

      return pw.Container(
        width: 120,
        height: 20,
        alignment: pw.Alignment.center,
        child: pw.Image(
          pw.MemoryImage(bytes),
          fit: pw.BoxFit.contain, // 🔥 important
        ),
      );
    } catch (e) {
      return pw.SizedBox(width: 120, height: 40);
    }
  }

  final customerSignWidget = buildSignatureSync(manifest.customerSign);
  final technicianSignWidget = buildSignatureSync(manifest.technicianSign);

  String getDepartmentName(int id, List<DepartmentModel1> departments) {
    try {
      return departments.firstWhere((d) => d.id == id).departmentName;
    } catch (e) {
      return "";
    }
  }

  String format(String address) {
    if (address.isEmpty) return "";

    List<String> parts = address
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.length <= 1) return address;

    // ✅ Line 3 → City, PR ZIP (છેલ્લા 2 parts)
    String line3 = "${parts[parts.length - 2]}, ${parts[parts.length - 1]}";

    // ✅ બાકી parts Line 1 અને Line 2 માં વહેંચો
    List<String> remaining = parts.sublist(0, parts.length - 2);

    if (remaining.isEmpty) return line3;

    if (remaining.length == 1) {
      // ✅ ફક્ત 1 part → Line 1 + Line 3
      return "${remaining[0]},\n$line3";
    }

    // ✅ Line 1 → first part
    String line1 = remaining[0];
    // ✅ Line 2 → ALL parts
    String line2 = remaining.sublist(1).join(', ');

    return "$line1,\n$line2,\n$line3";
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => [
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Image(logoImage, width: 110),
            pw.Column(
              children: [
                pw.Text(
                  "DOCUMENT MANIFEST",
                  style: pw.TextStyle(
                    fontSize: 18,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Container(
                  width: 180,
                  alignment: pw.Alignment.center,
                  child: pw.Column(
                    children: [
                      pw.Text(
                        manifest.manifestNo,
                        style: pw.TextStyle(color: PdfColors.red, fontSize: 14),
                      ),
                      pw.Container(height: 1, color: PdfColors.black),
                      pw.Text("NUMBER", style: pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        _sectionTitle("I. Generator"),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: {
            0: const pw.FlexColumnWidth(),
            1: const pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Column(
                  children: [
                    _generatorCell(
                      label: "a. Generators Name:",
                      value: manifest.customer.name,
                    ),
                    _generatorCell(
                      label: "b. Contact Name / Department:",
                      value: manifest.customer.contactPerson,
                    ),
                    _generatorCell(
                      label: "c. Phone:",
                      value: manifest.customer.phone,
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    _generatorCell(
                      label: "d. Generators Location:",
                      value: format(manifest.customer.address),
                      height: 80,
                    ),
                    _generatorCell(
                      label: "e. Date",
                      value: DateFormat(
                        'MMMM d, yyyy',
                      ).format(DateTime.parse(manifest.serviceDate)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 15),
        _sectionTitle("II. Service Description"),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1.7),
            3: const pw.FlexColumnWidth(1.3),
            4: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              children: [
                _tableHeader("a. Information:"),
                _tableHeader("b. Department:"),
                _tableHeader("c. Measure / Volume:"),
                _tableHeader("d. Quantity Units:"),
                _tableHeader("e. Unit:"),
              ],
            ),
            for (int i = 0; i < totalRows; i++)
              pw.TableRow(
                children: [
                  _buildCell(
                    i < unitList.length ? unitList[i].serviceType : "",
                  ),
                  _buildCell(
                    i < unitList.length
                        ? getDepartmentName(
                            unitList[i].departmentId,
                            manifest.departments,
                          )
                        : "",
                  ),
                  _buildCell(i < unitList.length ? unitList[i].measure : ""),
                  _buildCell(i < unitList.length ? unitList[i].quantity : ""),
                  _buildCell(i < unitList.length ? unitList[i].unitType : ""),
                ],
              ),
          ],
        ),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: {
            0: const pw.FlexColumnWidth(),
            1: const pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              children: [
                _buildRichCell(
                  label: "e. Generators Authorized Agent Name (Print):",
                  value: manifest.customerName,
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start, // 🔥 FIX
                    children: [
                      pw.Text(
                        "f. Signature:",
                        style: pw.TextStyle(fontSize: 8),
                      ),
                      pw.SizedBox(width: 5),

                      pw.Expanded(
                        // 🔥 important
                        child: pw.Center(child: customerSignWidget),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 15),
        _sectionTitle("III. Transporter"),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: {
            0: const pw.FlexColumnWidth(),
            1: const pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              children: [
                _buildRichCell(
                  label: "a.  Driver Name (print):",
                  value: technicianName,
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "b. Signature:",
                        style: pw.TextStyle(fontSize: 8),
                      ),
                      pw.SizedBox(width: 5), // ✅ spacing
                      pw.Expanded(
                        // 🔥 important
                        child: pw.Center(child: technicianSignWidget),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 15),
        _sectionTitle("IV. Destination"),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "a. Site Address:",
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.Center(
                        child: pw.Column(
                          children: [
                            pw.Text(
                              "DOC DELETE PR - HQ",
                              style: pw.TextStyle(fontSize: 12),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              "SABANETAS INDUSTRIAL PARK T1416 - PONCE, PUERTO RICO 00716",
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: {
            0: const pw.FlexColumnWidth(),
            1: const pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              children: [
                _buildRichCell(
                  label: "b.  Name of the Authorized Receiving Agent (Print):",
                  value: "CHRISTIAN GONZALEZ",
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "c. Signature:",
                        style: pw.TextStyle(fontSize: 8),
                      ),
                      pw.SizedBox(width: 5),
                      pw.Expanded(
                        // 🔥 important
                        child: pw.Center(child: pw.SizedBox()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Center(
          child: pw.Text(
            "•  W W W . D O C D E L E T E P R . C O M   •   7 8 7 - 9 0 0 - 5 5 1 1   •   P O   B O X   7 5 9 1   P O N C E ,   P R   0 0 7 3 2  •",
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
      ],
    ),
  );

  return pdf.save();
}

// ✅ Isolate માટે હેલ્પર ફંક્શન્સ
pw.Widget _sectionTitle(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  );
}

pw.Widget _buildCell(String text) {
  return pw.Container(
    height: 28,
    padding: const pw.EdgeInsets.all(4),
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 9),
      textAlign: pw.TextAlign.center,
    ),
  );
}

pw.Widget _tableHeader(String text) {
  return pw.Container(
    height: 20,
    padding: const pw.EdgeInsets.all(4),
    alignment: pw.Alignment.topLeft,
    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 8),
      maxLines: 2,
      overflow: pw.TextOverflow.clip,
    ),
  );
}

pw.Widget _buildRichCell({required String label, required String value}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(5),
    alignment: pw.Alignment.topLeft,
    decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) pw.Text(label, style: pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12),
            softWrap: true,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _generatorCell({
  required String label,
  required String value,
  double height = 40,
}) {
  return pw.Container(
    height: height,
    alignment: pw.Alignment.topLeft,
    padding: const pw.EdgeInsets.all(5),
    decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          pw.Text(label, style: pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 4),
        ],
        pw.Center(
          child: pw.Column(
            children: value
                .split('\n')
                .map(
                  (line) =>
                      pw.Text(line.trim(), style: pw.TextStyle(fontSize: 12)),
                )
                .toList(),
          ),
        ),
      ],
    ),
  );
}
