import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

class RegistrationOcrResult {
  const RegistrationOcrResult({
    required this.rawText,
    required this.fields,
    required this.method,
  });

  final String rawText;
  final Map<String, String> fields;
  final String method;
}

class RegistrationOcrService {
  RegistrationOcrService._();

  static Future<RegistrationOcrResult> scanIne(List<File> images) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final scanner = MobileScannerController(
      formats: const [
        BarcodeFormat.pdf417,
        BarcodeFormat.qrCode,
        BarcodeFormat.dataMatrix,
        BarcodeFormat.aztec,
      ],
    );
    final ocrParts = <String>[];
    final barcodeParts = <String>[];

    try {
      for (var index = 0; index < images.length; index++) {
        final source = images[index];
        final variants = await _buildOcrVariants(source, index);
        try {
          for (final variant in variants) {
            final recognized = await textRecognizer.processImage(
              InputImage.fromFilePath(variant.path),
            );
            if (recognized.text.trim().isNotEmpty) {
              ocrParts.add(recognized.text);
            }
          }
        } finally {
          for (final variant in variants.skip(1)) {
            try {
              await variant.delete();
            } catch (_) {
              // El sistema tambien limpia estos temporales.
            }
          }
        }

        try {
          final capture = await scanner.analyzeImage(source.path);
          for (final barcode in capture?.barcodes ?? const <Barcode>[]) {
            final value = barcode.rawValue?.trim() ?? '';
            if (value.isNotEmpty) barcodeParts.add(value);
          }
        } catch (_) {
          // El OCR sigue funcionando aunque el documento no exponga codigo.
        }
      }
    } finally {
      await textRecognizer.close();
      await scanner.dispose();
    }

    final rawText = [...barcodeParts, ...ocrParts].join('\n\n');
    return RegistrationOcrResult(
      rawText: rawText,
      fields: _parseIne(rawText),
      method:
          barcodeParts.isNotEmpty && ocrParts.isNotEmpty
              ? 'codigo+ocr'
              : barcodeParts.isNotEmpty
              ? 'codigo'
              : 'ocr',
    );
  }

  static Map<String, String> _parseIne(String rawText) {
    final normalized = rawText.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    final compact = normalized.replaceAll(RegExp(r'[^A-Z0-9<]'), '');
    final mrz = _parseMrz(rawText);
    final curp = _findCurp(normalized, compact);
    final electorKey = _findElectorKey(normalized, compact);
    final name = _extractName(rawText);
    final birthDate = _birthDateFromCurp(curp);
    final expiration = _extractExpiration(normalized);
    final cic =
        RegExp(
          r'(?:CIC|IDCIC)[:\s-]*(\d{8,12})',
        ).firstMatch(normalized)?.group(1) ??
        '';
    final ocr =
        RegExp(
          r'(?:OCR|IDENTIFICADOR)[:\s-]*(\d{10,14})',
        ).firstMatch(normalized)?.group(1) ??
        '';

    return {
      'raw': rawText,
      'curp': curp,
      'document_number': electorKey.isNotEmpty ? electorKey : curp,
      'cic': cic,
      'ocr': ocr,
      'name': name.isNotEmpty ? name : mrz['name'] ?? '',
      'birth_date': birthDate.isNotEmpty ? birthDate : mrz['birth_date'] ?? '',
      'document_expiration':
          expiration.isNotEmpty ? expiration : mrz['document_expiration'] ?? '',
      if (curp.isNotEmpty || mrz.isNotEmpty) 'nationality': 'Mexicana',
    };
  }

  static String _findCurp(String normalized, String compact) {
    final direct = RegExp(
      r'[A-Z][AEIOUX][A-Z]{2}\d{6}[HM][A-Z]{5}[A-Z0-9]\d',
    ).firstMatch(normalized)?.group(0);
    if (direct != null) return direct;

    final plain = compact.replaceAll('<', '');
    for (var index = 0; index <= plain.length - 18; index++) {
      final candidate = _normalizeCurpCandidate(
        plain.substring(index, index + 18),
      );
      if (RegExp(
        r'^[A-Z][AEIOUX][A-Z]{2}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$',
      ).hasMatch(candidate)) {
        return candidate;
      }
    }
    return '';
  }

  static String _findElectorKey(String normalized, String compact) {
    final labeled = RegExp(
      r'CLAVE(?: DE)? ELECTOR[:\s-]*([A-Z0-9\s]{17,26})',
    ).firstMatch(normalized)?.group(1);
    final plain = compact.replaceAll('<', '');
    final candidates = <String>[
      if (labeled != null) labeled.replaceAll(RegExp(r'[^A-Z0-9]'), ''),
      for (final match in RegExp(r'[A-Z0-9]{18}').allMatches(plain))
        match.group(0) ?? '',
    ];

    for (final value in candidates) {
      if (value.length < 18) continue;
      final candidate = _normalizeElectorKey(value.substring(0, 18));
      if (RegExp(r'^[A-Z]{6}\d{8}[A-Z]\d{3}$').hasMatch(candidate)) {
        return candidate;
      }
    }
    return '';
  }

  static String _normalizeCurpCandidate(String value) {
    final chars = value.substring(0, 18).split('');
    const letterPositions = {0, 1, 2, 3, 10, 11, 12, 13, 14, 15};
    const digitPositions = {4, 5, 6, 7, 8, 9, 17};
    for (var index = 0; index < chars.length; index++) {
      if (letterPositions.contains(index)) {
        chars[index] = _digitToLetter(chars[index]);
      } else if (digitPositions.contains(index)) {
        chars[index] = _letterToDigit(chars[index]);
      } else if (index == 16 && chars[index] == 'O') {
        chars[index] = '0';
      }
    }
    return chars.join();
  }

  static String _normalizeElectorKey(String value) {
    final chars = value.substring(0, 18).split('');
    const letterPositions = {0, 1, 2, 3, 4, 5, 14};
    for (var index = 0; index < chars.length; index++) {
      chars[index] =
          letterPositions.contains(index)
              ? _digitToLetter(chars[index])
              : _letterToDigit(chars[index]);
    }
    return chars.join();
  }

  static String _digitToLetter(String value) {
    return const {'0': 'O', '1': 'I', '2': 'Z', '5': 'S', '8': 'B'}[value] ??
        value;
  }

  static String _letterToDigit(String value) {
    return const {
          'O': '0',
          'Q': '0',
          'D': '0',
          'I': '1',
          'L': '1',
          'Z': '2',
          'S': '5',
          'B': '8',
        }[value] ??
        value;
  }

  static String _birthDateFromCurp(String curp) {
    final match = RegExp(
      r'^[A-Z][AEIOUX][A-Z]{2}(\d{2})(\d{2})(\d{2})',
    ).firstMatch(curp);
    if (match == null) return '';
    final shortYear = int.parse(match.group(1)!);
    final currentYear = DateTime.now().year % 100;
    final century = shortYear > currentYear ? '19' : '20';
    return '$century${match.group(1)}-${match.group(2)}-${match.group(3)}';
  }

  static String _extractExpiration(String text) {
    final fullDate = RegExp(
      r'VIGENCIA[:\s-]*(\d{4})[-/](\d{2})[-/](\d{2})',
    ).firstMatch(text);
    if (fullDate != null) {
      return '${fullDate.group(1)}-${fullDate.group(2)}-${fullDate.group(3)}';
    }

    final yearRange = RegExp(
      r'VIGENCIA[:\s-]*(20\d{2})\s*[-/A ]+\s*(20\d{2})',
    ).firstMatch(text);
    if (yearRange != null) return '${yearRange.group(2)}-12-31';

    final singleYear = RegExp(r'VIGENCIA[:\s-]*(20\d{2})').firstMatch(text);
    return singleYear == null ? '' : '${singleYear.group(1)}-12-31';
  }

  static String _extractName(String rawText) {
    final lines =
        rawText
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim().toUpperCase())
            .where((line) => line.isNotEmpty)
            .toList();
    final index = lines.indexWhere(
      (line) => RegExp(r'^N[O0]MBRE').hasMatch(line),
    );
    if (index < 0) return '';

    return lines
        .skip(index + 1)
        .take(4)
        .where(
          (line) =>
              !RegExp(
                r'DOMICILIO|CLAVE|CURP|FECHA|SEXO|VIGENCIA|INSTITUTO',
              ).hasMatch(line),
        )
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Map<String, String> _parseMrz(String rawText) {
    final lines =
        rawText
            .split(RegExp(r'\r?\n'))
            .map(
              (line) => line
                  .toUpperCase()
                  .replaceAll(' ', '')
                  .replaceAll(RegExp(r'[^A-Z0-9<]'), ''),
            )
            .where((line) => line.length >= 20)
            .toList();
    final nameLine = lines.firstWhere(
      (line) => line.contains('<<') && RegExp(r'[A-Z]<[A-Z]').hasMatch(line),
      orElse: () => '',
    );
    final dataLine = lines.firstWhere(
      (line) => RegExp(r'[0-9OILZSBDQ]{6}[0-9OILZSBDQ][HM]').hasMatch(line),
      orElse: () => '',
    );

    final name =
        nameLine
            .replaceAll(RegExp(r'^ID[A-Z]{3}'), '')
            .replaceAll(RegExp(r'<+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    var birthDate = '';
    var expiration = '';
    final match = RegExp(
      r'([0-9OILZSBDQ]{6})[0-9OILZSBDQ][HM]([0-9OILZSBDQ]{6})',
    ).firstMatch(dataLine);
    if (match != null) {
      final birth = match.group(1)!.split('').map(_letterToDigit).join();
      final expiry = match.group(2)!.split('').map(_letterToDigit).join();
      birthDate = _dateFromMrz(birth, birthDate: true);
      expiration = _dateFromMrz(expiry, birthDate: false);
    }

    if (name.isEmpty && birthDate.isEmpty && expiration.isEmpty) {
      return const {};
    }
    return {
      'name': name,
      'birth_date': birthDate,
      'document_expiration': expiration,
    };
  }

  static String _dateFromMrz(String value, {required bool birthDate}) {
    if (!RegExp(r'^\d{6}$').hasMatch(value)) return '';
    final shortYear = int.parse(value.substring(0, 2));
    final currentShortYear = DateTime.now().year % 100;
    final century =
        birthDate ? (shortYear > currentShortYear ? 1900 : 2000) : 2000;
    return '${century + shortYear}-${value.substring(2, 4)}-${value.substring(4, 6)}';
  }

  static Future<List<File>> _buildOcrVariants(
    File source,
    int imageIndex,
  ) async {
    final decoded = img.decodeImage(await source.readAsBytes());
    if (decoded == null) return [source];

    final directory = await getTemporaryDirectory();
    final prefix =
        '${directory.path}${Platform.pathSeparator}ine_${DateTime.now().microsecondsSinceEpoch}_$imageIndex';
    final variants = <File>[source];
    final scaled =
        decoded.width < 2200
            ? img.copyResize(decoded, width: 2200)
            : img.Image.from(decoded);
    final contrast = img.adjustColor(
      img.grayscale(img.Image.from(scaled)),
      contrast: 1.65,
    );
    variants.add(await _writeVariant('$prefix-contrast.jpg', contrast));

    final threshold = img.Image.from(contrast);
    for (final pixel in threshold) {
      final value = pixel.r > 145 ? 255 : 0;
      pixel
        ..r = value
        ..g = value
        ..b = value;
    }
    variants.add(await _writeVariant('$prefix-threshold.jpg', threshold));

    final lowerCrop = img.copyCrop(
      scaled,
      x: 0,
      y: (scaled.height * 0.56).round(),
      width: scaled.width,
      height: (scaled.height * 0.44).round(),
    );
    variants.add(
      await _writeVariant(
        '$prefix-lower.jpg',
        img.adjustColor(img.grayscale(lowerCrop), contrast: 1.7),
      ),
    );
    return variants;
  }

  static Future<File> _writeVariant(String path, img.Image image) async {
    final file = File(path);
    await file.writeAsBytes(img.encodeJpg(image, quality: 94));
    return file;
  }
}
