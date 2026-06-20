import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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

  static const MethodChannel _ocrChannel = MethodChannel('redsky/ocr');

  static Map<String, String> parseIneText(String rawText) {
    return _parseIne(rawText);
  }

  static Future<RegistrationOcrResult> scanIne(List<File> images) async {
    final scanner = MobileScannerController(
      formats: const [
        BarcodeFormat.pdf417,
        BarcodeFormat.qrCode,
        BarcodeFormat.dataMatrix,
        BarcodeFormat.aztec,
      ],
    );
    final barcodeParts = <String>[];
    final textParts = <String>[];

    try {
      for (var index = 0; index < images.length; index++) {
        final source = images[index];
        try {
          final capture = await scanner.analyzeImage(source.path);
          for (final barcode in capture?.barcodes ?? const <Barcode>[]) {
            final value = barcode.rawValue?.trim() ?? '';
            if (value.isNotEmpty) barcodeParts.add(value);
          }
        } catch (_) {
          // El OCR sigue funcionando aunque el documento no exponga codigo.
        }

        try {
          final text = await _scanText(source.path);
          if (text.isNotEmpty) {
            textParts.add(text);
          }
        } catch (_) {
          // Si el OCR de texto falla, aun podemos usar barcode o backend.
        }
      }
    } finally {
      await scanner.dispose();
    }

    final rawText = [
      if (barcodeParts.isNotEmpty) barcodeParts.join('\n\n'),
      if (textParts.isNotEmpty) textParts.join('\n\n'),
    ].join('\n\n');

    return RegistrationOcrResult(
      rawText: rawText,
      fields: _parseIne(rawText),
      method:
          barcodeParts.isNotEmpty && textParts.isNotEmpty
              ? 'codigo_y_texto'
              : barcodeParts.isNotEmpty
              ? 'codigo'
              : textParts.isNotEmpty
              ? 'texto'
              : 'sin_datos',
    );
  }

  static Future<String> _scanText(String path) async {
    if (!Platform.isAndroid) return '';
    final response = await _ocrChannel.invokeMapMethod<String, dynamic>(
      'recognizeText',
      {'path': path},
    );
    return (response?['text'] ?? '').toString().trim();
  }

  static Map<String, String> _parseIne(String rawText) {
    final normalized = rawText.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    final compact = normalized.replaceAll(RegExp(r'[^A-Z0-9<]'), '');
    final mrz = _parseMrz(rawText);
    final curp = _findCurp(normalized, compact);
    final electorKey = _findElectorKey(normalized, compact);
    final name = _extractName(rawText);
    final cityBase = _extractCityBase(rawText);
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

    final fallbackName = _extractNameFallback(rawText);

    return {
      'raw': rawText,
      'curp': curp,
      'document_number': electorKey.isNotEmpty ? electorKey : curp,
      'cic': cic,
      'ocr': ocr,
      'name': name.isNotEmpty ? name : (mrz['name'] ?? fallbackName),
      'base': cityBase,
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
    if (singleYear != null) return '${singleYear.group(1)}-12-31';

    final standaloneDateMatches = RegExp(
      r'\b(20\d{2})[-/](\d{2})[-/](\d{2})\b',
    ).allMatches(text).toList();
    if (standaloneDateMatches.isNotEmpty) {
      final match = standaloneDateMatches.last;
      return '${match.group(1)}-${match.group(2)}-${match.group(3)}';
    }

    return '';
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
                r'DOMICILI[O0]|CLAVE|CURP|FECHA|SEXO|VIGENCIA|INSTITUTO',
              ).hasMatch(line),
        )
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _extractNameFallback(String rawText) {
    final lines =
        rawText
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim().toUpperCase())
            .where((line) => line.isNotEmpty)
            .toList();

    final nameCandidates =
        lines.where((line) {
          if (line.length < 6) return false;
          if (RegExp(r'\d').hasMatch(line)) return false;
          if (!RegExp(r'^[A-ZÁÉÍÓÚÑ ]+$').hasMatch(line)) return false;
          if (RegExp(
            r'CURP|CLAVE|DOMICILI[O0]|SEXO|VIGENCIA|FECHA|INSTITUTO|ESTADO|MUNICIPIO|COLONIA|LOCALIDAD',
          ).hasMatch(line)) {
            return false;
          }
          return true;
        }).toList();

    if (nameCandidates.isEmpty) return '';
    return nameCandidates.take(3).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _extractCityBase(String rawText) {
    final lines =
        rawText
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim().toUpperCase())
            .where((line) => line.isNotEmpty)
            .toList();

    final addressIndex = lines.indexWhere(
      (line) => RegExp(r'^DOMICILI[O0]$|^DOMICILI[O0]\b').hasMatch(line),
    );
    if (addressIndex < 0) return '';

    final addressLines =
        lines
            .skip(addressIndex + 1)
            .takeWhile(
              (line) => !RegExp(
                r'CLAVE|CURP|FECHA|SECCI[O0]N|A[ÑN]O|SEXO|VIGENCIA|ESTADO|MUNICIPIO',
              ).hasMatch(line),
            )
            .toList();

    for (final line in addressLines.reversed) {
      if (RegExp(r'^[A-ZÁÉÍÓÚÑ ]+,\s*[A-ZÁÉÍÓÚÑ. ]+$').hasMatch(line)) {
        return _toTitleCase(line);
      }
    }

    final fallback = addressLines.lastWhere(
      (line) => !RegExp(r'\d{4,}').hasMatch(line),
      orElse: () => '',
    );
    return fallback.isEmpty ? '' : _toTitleCase(fallback);
  }

  static String _toTitleCase(String value) {
    return value
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map(
          (word) =>
              word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
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
}
