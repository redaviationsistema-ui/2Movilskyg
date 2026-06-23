import 'dart:io';

import 'package:flutter/foundation.dart';
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
        debugPrint(
          '[INE OCR] scanIne imageIndex=$index total=${images.length} path=${source.path} platform=${Platform.operatingSystem}',
        );
        try {
          final capture = await scanner.analyzeImage(source.path);
          debugPrint(
            '[INE OCR] barcode capture imageIndex=$index count=${capture?.barcodes.length ?? 0}',
          );
          for (final barcode in capture?.barcodes ?? const <Barcode>[]) {
            final value = barcode.rawValue?.trim() ?? '';
            if (value.isNotEmpty) barcodeParts.add(value);
          }
        } catch (error) {
          debugPrint(
            '[INE OCR] barcode analyze failed imageIndex=$index path=${source.path} error=$error',
          );
          // El OCR sigue funcionando aunque el documento no exponga codigo.
        }

        try {
          final text = await _scanText(source.path);
          if (text.isNotEmpty) {
            textParts.add(text);
          }
        } catch (error) {
          debugPrint(
            '[INE OCR] text scan failed imageIndex=$index path=${source.path} error=$error',
          );
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
    final parsed = _parseIne(rawText);
    debugPrint('[INE OCR] OCR TEXT: $rawText');
    debugPrint('[INE OCR] DATOS EXTRAIDOS: $parsed');
    debugPrint(
      '[INE OCR] scanIne summary barcodeParts=${barcodeParts.length} textParts=${textParts.length} rawTextLength=${rawText.length}',
    );

    return RegistrationOcrResult(
      rawText: rawText,
      fields: parsed,
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
    if (!Platform.isAndroid && !Platform.isIOS) return '';
    debugPrint('[INE OCR] PATH IMAGEN: $path');
    final response = await _ocrChannel.invokeMapMethod<String, dynamic>(
      'recognizeText',
      {'path': path},
    );
    debugPrint('[INE OCR] OCR RESPONSE: $response');
    final text = (response?['text'] ?? '').toString().trim();
    debugPrint('[INE OCR] OCR TEXT: $text');
    return text;
  }

  static Map<String, String> _parseIne(String rawText) {
    final normalized = _normalizeOcrText(rawText);
    final compact = normalized.replaceAll(RegExp(r'[^A-Z0-9<]'), '');
    final mrz = _parseMrz(rawText);
    final curp = _findCurp(normalized, compact);
    final electorKey = _findElectorKey(normalized, compact);
    final name = _extractName(rawText);
    final cityBase = _extractCityBase(rawText);
    final birthDate = _extractBirthDate(normalized, curp);
    final expiration = _extractExpiration(normalized);
    final cic =
        _extractLabeledDigits(
          normalized,
          labelPattern:
              '(?:${_spacedKeywordPattern("CIC")}|ID\\s*${_spacedKeywordPattern("CIC")})',
          minLength: 8,
          maxLength: 12,
        ) ??
        '';
    final ocr =
        _extractLabeledDigits(
          normalized,
          labelPattern:
              '(?:${_spacedKeywordPattern("OCR")}|${_spacedKeywordPattern("IDENTIFICADOR")})',
          minLength: 10,
          maxLength: 14,
        ) ??
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
    final labeled = _extractFlexibleCurp(normalized);
    if (labeled.isNotEmpty) return labeled;

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
    final labeled = _extractLabeledAlnum(
      normalized,
      labelPattern:
          '${_spacedKeywordPattern("CLAVE")}(?:\\s+${_spacedKeywordPattern("DE")})?\\s+${_spacedKeywordPattern("ELECTOR")}',
      minLength: 17,
      maxLength: 26,
    );
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

  static String _extractBirthDate(String text, String curp) {
    final labeled = RegExp(
      '${_spacedKeywordPattern("FECHA")}(?:\\s+${_spacedKeywordPattern("DE")})?\\s+${_spacedKeywordPattern("NACIMIENTO")}[^0-9]*(\\d{2})[\\-/ ](\\d{2})[\\-/ ](\\d{4})',
    ).firstMatch(text);
    if (labeled != null) {
      return '${labeled.group(3)}-${labeled.group(2)}-${labeled.group(1)}';
    }

    final labeledIso = RegExp(
      '${_spacedKeywordPattern("FECHA")}(?:\\s+${_spacedKeywordPattern("DE")})?\\s+${_spacedKeywordPattern("NACIMIENTO")}[^0-9]*(\\d{4})[\\-/ ](\\d{2})[\\-/ ](\\d{2})',
    ).firstMatch(text);
    if (labeledIso != null) {
      return '${labeledIso.group(1)}-${labeledIso.group(2)}-${labeledIso.group(3)}';
    }

    return _birthDateFromCurp(curp);
  }

  static String _extractExpiration(String text) {
    final fullDate = RegExp(
      '${_spacedKeywordPattern("VIGENCIA")}[:\\s-]*(\\d{4})[-/](\\d{2})[-/](\\d{2})',
    ).firstMatch(text);
    if (fullDate != null) {
      return '${fullDate.group(1)}-${fullDate.group(2)}-${fullDate.group(3)}';
    }

    final yearRange = RegExp(
      '${_spacedKeywordPattern("VIGENCIA")}[:\\s-]*(20\\d{2})\\s*[-/A ]+\\s*(20\\d{2})',
    ).firstMatch(text);
    if (yearRange != null) return '${yearRange.group(2)}-12-31';

    final singleYear = RegExp(
      '${_spacedKeywordPattern("VIGENCIA")}[:\\s-]*(20\\d{2})',
    ).firstMatch(text);
    if (singleYear != null) return '${singleYear.group(1)}-12-31';

    final standaloneDateMatches =
        RegExp(
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
        _normalizeOcrText(rawText)
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
    final index = lines.indexWhere((line) {
      return RegExp('^${_spacedKeywordPattern("NOMBRE")}').hasMatch(line);
    });
    if (index < 0) return '';

    return lines
        .skip(index + 1)
        .take(6)
        .where(
          (line) =>
              !RegExp(
                '${_spacedKeywordPattern("DOMICILIO")}|${_spacedKeywordPattern("CLAVE")}|${_spacedKeywordPattern("CURP")}|${_spacedKeywordPattern("FECHA")}|${_spacedKeywordPattern("SEXO")}|${_spacedKeywordPattern("VIGENCIA")}|${_spacedKeywordPattern("INSTITUTO")}',
              ).hasMatch(line),
        )
        .map(_cleanupInlineLabelNoise)
        .where((line) => line.isNotEmpty)
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _extractNameFallback(String rawText) {
    final lines =
        _normalizeOcrText(rawText)
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();

    final nameCandidates =
        lines.where((line) {
          if (line.length < 6) return false;
          if (RegExp(r'\d').hasMatch(line)) return false;
          if (!RegExp(r'^[A-Z ]+$').hasMatch(line)) return false;
          if (RegExp(
            '${_spacedKeywordPattern("CURP")}|${_spacedKeywordPattern("CLAVE")}|${_spacedKeywordPattern("DOMICILIO")}|${_spacedKeywordPattern("SEXO")}|${_spacedKeywordPattern("VIGENCIA")}|${_spacedKeywordPattern("FECHA")}|${_spacedKeywordPattern("INSTITUTO")}|${_spacedKeywordPattern("ESTADO")}|${_spacedKeywordPattern("MUNICIPIO")}|${_spacedKeywordPattern("COLONIA")}|${_spacedKeywordPattern("LOCALIDAD")}',
          ).hasMatch(line)) {
            return false;
          }
          return true;
        }).toList();

    if (nameCandidates.isEmpty) return '';
    return nameCandidates
        .take(3)
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _extractCityBase(String rawText) {
    final lines =
        _normalizeOcrText(rawText)
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();

    final addressIndex = lines.indexWhere(
      (line) => RegExp(
        '^${_spacedKeywordPattern("DOMICILIO")}\$|^${_spacedKeywordPattern("DOMICILIO")}\\b',
      ).hasMatch(line),
    );
    if (addressIndex < 0) return '';

    final addressLines =
        lines
            .skip(addressIndex + 1)
            .takeWhile(
              (line) =>
                  !RegExp(
                    '${_spacedKeywordPattern("CLAVE")}|${_spacedKeywordPattern("CURP")}|${_spacedKeywordPattern("FECHA")}|SECCI[O0]N|A[ÑN]O|${_spacedKeywordPattern("SEXO")}|${_spacedKeywordPattern("VIGENCIA")}|${_spacedKeywordPattern("ESTADO")}|${_spacedKeywordPattern("MUNICIPIO")}',
                  ).hasMatch(line),
            )
            .toList();

    for (final line in addressLines.reversed) {
      if (RegExp(r'^[A-Z ]+,\s*[A-Z. ]+$').hasMatch(line)) {
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

  static String _normalizeOcrText(String value) {
    return value
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .trim();
  }

  static String _spacedKeywordPattern(String keyword) {
    final normalized = _normalizeOcrText(keyword).replaceAll(' ', '');
    return normalized.split('').map(RegExp.escape).join(r'[\s.:;-]*');
  }

  static String _cleanupInlineLabelNoise(String value) {
    return value
        .replaceAll(
          RegExp(
            '${_spacedKeywordPattern("NOMBRE")}|${_spacedKeywordPattern("APELLIDO")}|${_spacedKeywordPattern("PATERNO")}|${_spacedKeywordPattern("MATERNO")}',
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _extractFlexibleCurp(String text) {
    final labeled = _extractLabeledAlnum(
      text,
      labelPattern: _spacedKeywordPattern('CURP'),
      minLength: 18,
      maxLength: 24,
    );
    if (labeled == null || labeled.isEmpty) return '';

    final compact = labeled.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.length < 18) return '';
    return _normalizeCurpCandidate(compact.substring(0, 18));
  }

  static String? _extractLabeledAlnum(
    String text, {
    required String labelPattern,
    required int minLength,
    required int maxLength,
  }) {
    final match = RegExp(
      '$labelPattern[:\\s-]*([A-Z0-9\\s]{${minLength},${maxLength}})',
    ).firstMatch(text);
    return match?.group(1)?.trim();
  }

  static String? _extractLabeledDigits(
    String text, {
    required String labelPattern,
    required int minLength,
    required int maxLength,
  }) {
    final raw = _extractLabeledAlnum(
      text,
      labelPattern: labelPattern,
      minLength: minLength,
      maxLength: maxLength + 8,
    );
    if (raw == null || raw.isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < minLength) return null;
    return digits.substring(
      0,
      digits.length > maxLength ? maxLength : digits.length,
    );
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
