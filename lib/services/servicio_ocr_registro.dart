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
  static final RegExp _curpStrictPattern = RegExp(
    r'^[A-Z][AEIOUX][A-Z]{2}\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])[HM](AS|BC|BS|CC|CL|CM|CS|CH|DF|DG|GT|GR|HG|JC|MC|MN|MS|NT|NL|OC|PL|QT|QR|SP|SL|SR|TC|TS|TL|VZ|YN|ZS|NE)[B-DF-HJ-NP-TV-Z]{3}[A-Z0-9]\d$',
  );
  static final RegExp _electorKeyPattern = RegExp(r'^[A-Z]{6}\d{8}[A-Z]\d{3}$');

  static String _previewText(String value, {int max = 160}) {
    final normalizedWhitespace = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalizedWhitespace.length <= max) return normalizedWhitespace;
    return '${normalizedWhitespace.substring(0, max)}...';
  }

  static Map<String, String> parseIneText(String rawText) {
    return _parseIne(rawText);
  }

  static bool isValidCurp(String value) {
    final compact = _normalizeOcrText(
      value,
    ).replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.length != 18) return false;
    final normalized = _normalizeCurpCandidate(compact);
    return _curpStrictPattern.hasMatch(normalized);
  }

  static bool isValidElectorKey(String value) {
    final compact = _normalizeOcrText(
      value,
    ).replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.length < 18) return false;
    final normalized = _normalizeElectorKey(compact.substring(0, 18));
    return _electorKeyPattern.hasMatch(normalized);
  }

  static Future<String> scanTextFile(File image) async {
    debugPrint(
      '[DOC OCR] scanTextFile path=${image.path} platform=${Platform.operatingSystem}',
    );
    return _scanText(image.path);
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
    debugPrint(
      '[INE OCR] scanIne summary barcodeParts=${barcodeParts.length} textParts=${textParts.length} rawTextLength=${rawText.length} parsedKeys=${parsed.keys.toList()}',
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
    final text = (response?['text'] ?? '').toString().trim();
    debugPrint(
      '[INE OCR] text summary length=${text.length} preview="${_previewText(text)}"',
    );
    return text;
  }

  static Map<String, String> _parseIne(String rawText) {
    final normalized = _normalizeOcrText(rawText);
    final compact = normalized.replaceAll(RegExp(r'[^A-Z0-9<]'), '');
    final normalizedLines = _normalizedLines(rawText);
    debugPrint(
      '[INE PARSE] rawLength=${rawText.length} normalizedLength=${normalized.length} lineCount=${normalizedLines.length}',
    );
    debugPrint('[INE PARSE] rawPreview=${_previewText(rawText)}');
    debugPrint('[INE PARSE] normalizedPreview=${_previewText(normalized)}');
    debugPrint(
      '[INE PARSE] normalizedLinesPreview=${_previewText(normalizedLines.take(8).join(' | '))}',
    );

    final mrz = _parseMrz(rawText);
    final rawCurp = _findCurp(normalized, compact);
    final rawElectorKey = _findElectorKey(normalized, compact);
    final rawNameSegments = _extractNameSegments(rawText);
    final rawName = _extractName(rawText, segments: rawNameSegments);
    final rawLastName = _extractLastName(rawNameSegments);
    final fallbackName = _extractNameFallback(rawText);
    final rawAddress = _extractAddress(rawText);
    final rawCityBase = _extractCityBase(
      rawText,
      precomputedAddress: rawAddress,
    );
    final rawBirthDate = _extractBirthDate(normalized, rawCurp);
    final rawExpiration = _extractExpiration(normalized);
    final rawCic = _extractCic(normalized, compact);
    final rawOcr = _extractOcr(normalized, compact);

    final curp = _validateCurp(rawCurp);
    final birthDate =
        rawBirthDate.isNotEmpty
            ? rawBirthDate
            : (curp.isNotEmpty ? _birthDateFromCurp(curp) : '');
    final electorKey = _validateElectorKey(rawElectorKey, curp: curp);
    final resolvedName = _validateName(
      rawName.isNotEmpty
          ? rawName
          : (mrz['name']?.trim().isNotEmpty ?? false)
          ? mrz['name']!
          : fallbackName,
    );
    final resolvedLastName = _validateLastName(rawLastName);
    final address = _validateAddress(rawAddress);
    final cityBase = _validateBase(
      rawCityBase.isNotEmpty ? rawCityBase : _extractCityBase(address),
    );
    final resolvedBirthDate = _validateBirthDate(birthDate, curp: curp);
    final resolvedExpiration = _validateExpiration(
      rawExpiration.isNotEmpty
          ? rawExpiration
          : mrz['document_expiration'] ?? '',
      birthDate: resolvedBirthDate,
    );
    final cic = _validateCic(rawCic, birthDate: resolvedBirthDate);
    final ocr = _validateOcr(rawOcr, birthDate: resolvedBirthDate);

    debugPrint(
      '[INE PARSE] extracted flags curp=${curp.isNotEmpty} electorKey=${electorKey.isNotEmpty} ocr=${ocr.isNotEmpty} cic=${cic.isNotEmpty} birthDate=${resolvedBirthDate.isNotEmpty} expiration=${resolvedExpiration.isNotEmpty}',
    );
    debugPrint(
      '[INE PARSE] extracted fields name=${resolvedName.isNotEmpty} base=${cityBase.isNotEmpty} address=${address.isNotEmpty} mrzKeys=${mrz.keys.toList()}',
    );

    return {
      'raw': rawText,
      'curp': curp,
      'document_number': electorKey,
      'cic': cic,
      'ocr': ocr,
      'name': resolvedName,
      'last_name': resolvedLastName,
      'address': address,
      'domicilio': address,
      'base': cityBase,
      'birth_date': resolvedBirthDate,
      'document_expiration': resolvedExpiration,
      if (curp.isNotEmpty || mrz.isNotEmpty) 'nationality': 'Mexicana',
    };
  }

  static String _findCurp(String normalized, String compact) {
    final strictSearch = _findStrictCurpInText(normalized);
    if (strictSearch.isNotEmpty) return strictSearch;

    final lineSearch = _findCurpInNearbyLines(normalized);
    if (lineSearch.isNotEmpty) return lineSearch;

    final labeled = _extractFlexibleCurp(normalized);
    if (labeled.isNotEmpty) return labeled;

    final tokenSearch = _findCurpInAllTokens(normalized);
    if (tokenSearch.isNotEmpty) return tokenSearch;

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

  static String _findStrictCurpInText(String normalized) {
    for (final match in RegExp(r'[A-Z0-9]{18}').allMatches(normalized)) {
      final candidate = _normalizeCurpCandidate(match.group(0)!);
      if (_curpStrictPattern.hasMatch(candidate) &&
          !_electorKeyPattern.hasMatch(candidate)) {
        return candidate;
      }
    }
    return '';
  }

  static String _findCurpInNearbyLines(String normalized) {
    final lines =
        normalized
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
    final curpIndex = lines.indexWhere(
      (line) => RegExp(_spacedKeywordPattern('CURP')).hasMatch(line),
    );
    if (curpIndex < 0) return '';

    final windowEnd = (curpIndex + 4).clamp(0, lines.length - 1);
    for (var index = curpIndex; index <= windowEnd; index++) {
      final line = lines[index];
      if (RegExp(_spacedKeywordPattern('ANO DE REGISTRO')).hasMatch(line)) {
        continue;
      }
      final cleanedLine =
          line
              .replaceAll(RegExp(_spacedKeywordPattern('CURP')), ' ')
              .replaceAll(RegExp(r'[^A-Z0-9]'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
      for (final token in cleanedLine.split(' ')) {
        if (token.length != 18) continue;
        final candidate = _normalizeCurpCandidate(token);
        if (_curpStrictPattern.hasMatch(candidate)) {
          return candidate;
        }
      }
    }
    return '';
  }

  static String _findCurpInAllTokens(String normalized) {
    final tokens =
        normalized
            .replaceAll(RegExp(r'[^A-Z0-9\n ]'), ' ')
            .split(RegExp(r'\s+'))
            .where((token) => token.length >= 18)
            .toList();
    for (final token in tokens) {
      final compact = token.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (compact.length != 18) continue;
      final candidate = _normalizeCurpCandidate(compact);
      if (_curpStrictPattern.hasMatch(candidate) &&
          !_electorKeyPattern.hasMatch(candidate)) {
        return candidate;
      }
    }
    return '';
  }

  static String _findElectorKey(String normalized, String compact) {
    final labeled = _extractLabeledAlnum(
      normalized,
      labelPattern:
          '${_spacedKeywordPattern("CLAVE")}(?:\\s*${_spacedKeywordPattern("DE")})?\\s*${_spacedKeywordPattern("ELECTOR")}',
      minLength: 17,
      maxLength: 26,
    );
    final candidates = <String>[
      if (labeled != null) labeled.replaceAll(RegExp(r'[^A-Z0-9]'), ''),
    ];

    for (final value in candidates) {
      if (value.length < 18) continue;
      final candidate = _normalizeElectorKey(value.substring(0, 18));
      if (_electorKeyPattern.hasMatch(candidate)) {
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
    final labelPattern =
        '(?:${_spacedKeywordPattern("FECHA")}(?:\\s+${_spacedKeywordPattern("DE")})?\\s+${_spacedKeywordPattern("NACIMIENTO")}|${_spacedKeywordPattern("NACIMIENTO")})';
    for (final pattern in [
      '$labelPattern[^0-9]*(\\d{2})[\\-/. ]+(\\d{2})[\\-/. ]+(\\d{4})',
      '$labelPattern[^0-9]*(\\d{4})[\\-/. ]+(\\d{2})[\\-/. ]+(\\d{2})',
    ]) {
      final match = RegExp(pattern).firstMatch(text);
      if (match == null) continue;
      final candidate =
          match.groupCount == 3 && match.group(1)!.length == 4
              ? '${match.group(1)}-${match.group(2)}-${match.group(3)}'
              : '${match.group(3)}-${match.group(2)}-${match.group(1)}';
      if (_isPlausibleDate(
        candidate,
        minYear: 1900,
        maxYear: DateTime.now().year,
      )) {
        return candidate;
      }
    }

    for (final match in RegExp(
      r'\b(\d{2})[\/\-. ](\d{2})[\/\-. ](\d{4})\b',
    ).allMatches(text)) {
      final candidate = '${match.group(3)}-${match.group(2)}-${match.group(1)}';
      if (_isPlausibleDate(
        candidate,
        minYear: 1900,
        maxYear: DateTime.now().year,
      )) {
        return candidate;
      }
    }

    return _birthDateFromCurp(curp);
  }

  static String _extractExpiration(String text) {
    final labelPattern = _spacedKeywordPattern("VIGENCIA");

    final fullDate = RegExp(
      '$labelPattern[:\\s-]*(\\d{4})[-/](\\d{2})[-/](\\d{2})',
    ).firstMatch(text);
    if (fullDate != null) {
      final candidate =
          '${fullDate.group(1)}-${fullDate.group(2)}-${fullDate.group(3)}';
      if (_isPlausibleDate(candidate, minYear: 2010, maxYear: 2100)) {
        return candidate;
      }
    }

    final labeledDmy = RegExp(
      '$labelPattern[:\\s-]*(\\d{2})[-/. ](\\d{2})[-/. ](\\d{4})',
    ).firstMatch(text);
    if (labeledDmy != null) {
      final candidate =
          '${labeledDmy.group(3)}-${labeledDmy.group(2)}-${labeledDmy.group(1)}';
      if (_isPlausibleDate(candidate, minYear: 2010, maxYear: 2100)) {
        return candidate;
      }
    }

    final yearRange = RegExp(
      '$labelPattern[:\\s-]*(20\\d{2})\\s*[-/A ]+\\s*(20\\d{2})',
    ).firstMatch(text);
    if (yearRange != null) return '${yearRange.group(2)}-12-31';

    final nearbyRange = RegExp(
      '(?:$labelPattern|${_spacedKeywordPattern("SECCION")})[^\\n]*\\n(?:[^\\n]*\\n)?\\s*(20\\d{2})\\s*[-/ ]+\\s*(20\\d{2})',
      multiLine: true,
    ).firstMatch(text);
    if (nearbyRange != null) return '${nearbyRange.group(2)}-12-31';

    for (final match in RegExp(
      r'\b(20\d{2})\s*[-/ ]+\s*(20\d{2})\b',
    ).allMatches(text)) {
      final startYear = int.tryParse(match.group(1)!);
      final endYear = int.tryParse(match.group(2)!);
      if (startYear == null || endYear == null) continue;
      if (endYear < startYear) continue;
      if (endYear < 2010 || endYear > 2100) continue;
      return '$endYear-12-31';
    }

    final singleYear = RegExp(
      '$labelPattern[:\\s-]*(20\\d{2})',
    ).firstMatch(text);
    if (singleYear != null) return '${singleYear.group(1)}-12-31';

    final standaloneDateMatches =
        RegExp(
          r'\b(20\d{2})[-/](\d{2})[-/](\d{2})\b',
        ).allMatches(text).toList();
    for (final match in standaloneDateMatches.reversed) {
      final candidate = '${match.group(1)}-${match.group(2)}-${match.group(3)}';
      if (_isPlausibleDate(candidate, minYear: 2010, maxYear: 2100)) {
        return candidate;
      }
    }

    return '';
  }

  static List<String> _extractNameSegments(String rawText) {
    final lines = _normalizedLines(rawText);
    final index = lines.indexWhere((line) {
      return RegExp('^${_spacedKeywordPattern("NOMBRE")}').hasMatch(line);
    });
    final collected = <String>[];

    if (index < 0) return const <String>[];

    final inlineCandidate = _cleanupInlineLabelNoise(lines[index]);
    if (_isLikelyIneNameSegment(inlineCandidate)) {
      collected.add(inlineCandidate);
    }

    final windowEnd = index + 5 >= lines.length ? lines.length - 1 : index + 5;
    for (var lineIndex = index + 1; lineIndex <= windowEnd; lineIndex++) {
      final line = lines[lineIndex];
      if (_isNameStopLine(line)) break;
      if (_shouldSkipNameLine(line)) continue;
      final cleaned = _cleanupInlineLabelNoise(line);
      if (_isLikelyIneNameSegment(cleaned)) {
        collected.add(cleaned);
        if (collected.length >= 4) break;
      }
    }

    return collected
        .map(_dedupeWords)
        .where((segment) => segment.isNotEmpty)
        .toList();
  }

  static String _extractName(String rawText, {List<String>? segments}) {
    final collected = segments ?? _extractNameSegments(rawText);
    if (collected.isEmpty) return '';
    final candidate = _dedupeWords(
      collected.length == 1 ? collected.first : collected.last,
    );
    final wordCount =
        candidate.split(' ').where((word) => word.isNotEmpty).length;
    return wordCount >= 1 ? candidate : '';
  }

  static String _extractLastName(List<String> segments) {
    if (segments.length < 2) return '';
    return _dedupeWords(segments.take(segments.length - 1).join(' '));
  }

  static String _extractNameFallback(String rawText) {
    final lines = _normalizedLines(rawText);
    final nameCandidates =
        lines.where((line) {
          final cleaned = _cleanupInlineLabelNoise(line);
          return _isLikelyNameLine(cleaned);
        }).toList();

    if (nameCandidates.isEmpty) return '';
    return _dedupeWords(nameCandidates.take(3).join(' '));
  }

  static String _extractCityBase(String rawText, {String? precomputedAddress}) {
    final rawLines = _normalizedLines(rawText);
    for (final line in rawLines.reversed) {
      if (_looksLikeCityBaseLine(line)) {
        return _toTitleCase(line);
      }
    }

    final address =
        precomputedAddress?.trim().isNotEmpty == true
            ? precomputedAddress!.trim()
            : _extractAddress(rawText);
    if (address.isEmpty) return '';

    final normalizedAddress = _normalizeOcrText(address);
    final parts =
        normalizedAddress
            .split(RegExp(r'[,;\n]+'))
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();

    for (final part in parts.reversed) {
      if (_looksLikeCityBaseLine(part)) return _toTitleCase(part);
    }

    return '';
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

  static List<String> _normalizedLines(String rawText) {
    return _normalizeOcrText(rawText)
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static String _spacedKeywordPattern(String keyword) {
    final normalized = _normalizeOcrText(keyword).replaceAll(' ', '');
    return normalized.split('').map(RegExp.escape).join(r'[\s.:;-]*');
  }

  static String _cleanupInlineLabelNoise(String value) {
    return value
        .replaceAll(
          RegExp(
            '${_spacedKeywordPattern("NOMBRE")}|${_spacedKeywordPattern("APELLIDO")}|${_spacedKeywordPattern("PATERNO")}|${_spacedKeywordPattern("MATERNO")}|${_spacedKeywordPattern("DOMICILIO")}|${_spacedKeywordPattern("DIRECCION")}',
          ),
          '',
        )
        .replaceAll(RegExp(r'[:;,\-]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _extractFlexibleCurp(String text) {
    final labeled = _extractLabeledAlnum(
      text,
      labelPattern: _spacedKeywordPattern('CURP'),
      minLength: 18,
      maxLength: 30,
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
      '$labelPattern[:\\s-]*([A-Z0-9<\\s]{$minLength,$maxLength})',
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

  static String _extractAddress(String rawText) {
    final lines = _normalizedLines(rawText);
    final addressIndex = lines.indexWhere(
      (line) => RegExp(
        '^${_spacedKeywordPattern("DOMICILIO")}\\b|^${_spacedKeywordPattern("DIRECCION")}\\b',
      ).hasMatch(line),
    );
    if (addressIndex < 0) return '';

    final addressLines = <String>[];
    final currentLine = _cleanupInlineLabelNoise(lines[addressIndex]);
    if (_looksLikeAddressLine(currentLine)) {
      addressLines.add(currentLine);
    }

    for (final line in lines.skip(addressIndex + 1).take(6)) {
      if (_isBoundaryLine(line)) break;
      final cleaned = _cleanupInlineLabelNoise(line);
      if (_looksLikeAddressLine(cleaned)) {
        addressLines.add(cleaned);
      }
    }

    if (addressLines.isEmpty) return '';
    return _toTitleCase(
      addressLines.join(', ').replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
  }

  static String _extractCic(String normalized, String compact) {
    final labelCandidates = [
      '(?:${_spacedKeywordPattern("CIC")}|ID\\s*${_spacedKeywordPattern("CIC")}|${_spacedKeywordPattern("IDCIC")})',
      _spacedKeywordPattern("IDENTIFICADOR"),
    ];
    for (final label in labelCandidates) {
      final value = _extractLabeledDigits(
        normalized,
        labelPattern: label,
        minLength: 8,
        maxLength: 12,
      );
      if (value != null && value.isNotEmpty) return value;
    }

    final plain = compact.replaceAll('<', '');
    for (final match in RegExp(r'\d{8,12}').allMatches(plain)) {
      final value = match.group(0) ?? '';
      if (value.length >= 8 && value.length <= 12) return value;
    }
    return '';
  }

  static String _extractOcr(String normalized, String compact) {
    final labelCandidates = [
      '(?:${_spacedKeywordPattern("OCR")}|${_spacedKeywordPattern("IDENTIFICADOR")}|${_spacedKeywordPattern("ANO DE REGISTRO")})',
    ];
    for (final label in labelCandidates) {
      final value = _extractLabeledDigits(
        normalized,
        labelPattern: label,
        minLength: 10,
        maxLength: 14,
      );
      if (value != null && value.isNotEmpty) return value;
    }

    final plain = compact.replaceAll('<', '');
    final candidates = RegExp(
      r'\d{10,14}',
    ).allMatches(plain).map((m) => m.group(0) ?? '');
    return candidates.isEmpty ? '' : candidates.last;
  }

  static bool _isBoundaryLine(String line) {
    return RegExp(
      '${_spacedKeywordPattern("DOMICILIO")}|${_spacedKeywordPattern("DIRECCION")}|${_spacedKeywordPattern("CLAVE")}|${_spacedKeywordPattern("CURP")}|${_spacedKeywordPattern("FECHA")}|${_spacedKeywordPattern("SEXO")}|${_spacedKeywordPattern("VIGENCIA")}|${_spacedKeywordPattern("INSTITUTO")}|${_spacedKeywordPattern("ESTADO")}|${_spacedKeywordPattern("MUNICIPIO")}|${_spacedKeywordPattern("LOCALIDAD")}|${_spacedKeywordPattern("COLONIA")}|SECCI[O0]N|A[ÑN]O',
    ).hasMatch(line);
  }

  static bool _shouldSkipNameLine(String line) {
    return RegExp(
      '${_spacedKeywordPattern("SEXO")}|${_spacedKeywordPattern("DOMICILIO")}|${_spacedKeywordPattern("CLAVE")}|${_spacedKeywordPattern("CURP")}|${_spacedKeywordPattern("FECHA")}|${_spacedKeywordPattern("VIGENCIA")}|SECCI[O0]N',
    ).hasMatch(line);
  }

  static bool _isNameStopLine(String line) {
    return RegExp(
      '${_spacedKeywordPattern("DOMICILIO")}|${_spacedKeywordPattern("CLAVE")}|${_spacedKeywordPattern("CURP")}|${_spacedKeywordPattern("FECHA")}|${_spacedKeywordPattern("VIGENCIA")}|SECCI[O0]N|${_spacedKeywordPattern("INSTITUTO")}',
    ).hasMatch(line);
  }

  static bool _isLikelyNameLine(String line) {
    return _isLikelyIneNameSegment(line, allowSingleWord: false);
  }

  static bool _isLikelyIneNameSegment(
    String line, {
    bool allowSingleWord = true,
  }) {
    if (line.length < 4) return false;
    if (RegExp(r'\d{2,}').hasMatch(line)) return false;
    if (_isBoundaryLine(line)) return false;
    if (_containsAddressKeyword(line)) return false;
    final cleaned =
        line
            .replaceAll(RegExp(r'[^A-Z ,.]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    if (cleaned.isEmpty) return false;
    if (!RegExp(r'^[A-Z ,.]+$').hasMatch(cleaned)) return false;
    if (_containsIneHeaderNoise(cleaned)) return false;
    final words = cleaned.split(' ').where((word) => word.isNotEmpty).toList();
    return allowSingleWord ? words.isNotEmpty : words.length >= 2;
  }

  static bool _containsIneHeaderNoise(String value) {
    return RegExp(
      r'\b(CREDENCIAL|VOTAR|INSTITUTO|NACIONAL|ELECTORAL|REPUBLICA|MEXICANA|IDENTIDAD)\b',
    ).hasMatch(value);
  }

  static bool _containsAddressKeyword(String value) {
    return RegExp(
      r'\b(AV|AVENIDA|CALLE|COL|COLONIA|CP|C\.P\.|NUM|NO|NRO|MANZANA|LOTE|DOMICILIO|INDEPENDENCIA)\b',
    ).hasMatch(value);
  }

  static bool _looksLikeAddressLine(String line) {
    if (line.isEmpty) return false;
    if (_isBoundaryLine(line)) return false;
    if (line.length < 4) return false;
    if (RegExp(
      r'(CURP|OCR|CIC|CLAVE|VIGENCIA|SECCI[O0]N|REGISTRO)',
    ).hasMatch(line)) {
      return false;
    }
    if (_looksLikeOcrGarbage(line)) return false;
    final letters = RegExp(r'[A-Z]').allMatches(line).length;
    final digits = RegExp(r'\d').allMatches(line).length;
    if (letters < 3) return false;
    if (digits > 0 && digits >= letters) return false;
    return RegExp(r'[A-Z]').hasMatch(line);
  }

  static bool _looksLikeOcrGarbage(String line) {
    if (RegExp(r'[()<>]').hasMatch(line)) return true;
    final letters = RegExp(r'[A-Z]').allMatches(line).length;
    final digits = RegExp(r'\d').allMatches(line).length;
    if (digits >= 3 && digits >= letters) return true;
    if (digits >= 2 && RegExp(r'[A-Z]\d[A-Z]|\d[A-Z]\d').hasMatch(line)) {
      return true;
    }
    if (RegExp(r'[A-Z]{2,}\d{2,}[A-Z0-9]{2,}').hasMatch(line)) return true;
    return false;
  }

  static bool _looksLikeCityBaseLine(String line) {
    final normalized = _normalizeOcrText(line).trim();
    if (normalized.length < 4) return false;
    if (RegExp(r'\d').hasMatch(normalized)) return false;
    if (RegExp(r'[^A-Z ,.]').hasMatch(normalized)) return false;
    if (RegExp(
      r'\b(DOMICILIO|COLONIA|LOCALIDAD|SECCI[O0]N|CURP|CLAVE|FECHA|VIGENCIA|NOMBRE|SEXO)\b',
    ).hasMatch(normalized)) {
      return false;
    }
    return RegExp(r'^[A-Z]+(?: [A-Z]+)*, [A-Z]{2,4}\.?$').hasMatch(normalized);
  }

  static String _dedupeWords(String value) {
    final words =
        value
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim()
            .split(' ')
            .where((word) => word.isNotEmpty)
            .toList();
    final deduped = <String>[];
    for (final word in words) {
      if (deduped.isEmpty || deduped.last != word) {
        deduped.add(word);
      }
    }
    return deduped.join(' ').trim();
  }

  static bool _isPlausibleDate(
    String value, {
    required int minYear,
    required int maxYear,
  }) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return false;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return false;
    if (year < minYear || year > maxYear) return false;
    try {
      final parsed = DateTime(year, month, day);
      return parsed.year == year && parsed.month == month && parsed.day == day;
    } catch (_) {
      return false;
    }
  }

  static String _validateCurp(String value) {
    final compact = _normalizeOcrText(
      value,
    ).replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.length != 18) {
      if (compact.isNotEmpty) {
        debugPrint('[INE VALIDATION] rejected curp=$compact reason=length');
      }
      return '';
    }
    final normalized = _normalizeCurpCandidate(compact);
    if (!_curpStrictPattern.hasMatch(normalized)) {
      debugPrint('[INE VALIDATION] rejected curp=$normalized reason=format');
      return '';
    }
    return normalized;
  }

  static String _validateElectorKey(String value, {required String curp}) {
    final compact = _normalizeOcrText(
      value,
    ).replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.length != 18) {
      if (compact.isNotEmpty) {
        debugPrint(
          '[INE VALIDATION] rejected document_number=$compact reason=length',
        );
      }
      return '';
    }
    final normalized = _normalizeElectorKey(compact);
    if (!_electorKeyPattern.hasMatch(normalized)) {
      debugPrint(
        '[INE VALIDATION] rejected document_number=$normalized reason=format',
      );
      return '';
    }
    if (curp.isNotEmpty && normalized == curp) {
      debugPrint(
        '[INE VALIDATION] rejected document_number=$normalized reason=same_as_curp',
      );
      return '';
    }
    return normalized;
  }

  static String _validateBirthDate(String value, {required String curp}) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '';
    if (!_isPlausibleDate(
      normalized,
      minYear: 1900,
      maxYear: DateTime.now().year,
    )) {
      debugPrint(
        '[INE VALIDATION] rejected birth_date=$normalized reason=invalid_date',
      );
      return '';
    }
    if (curp.isNotEmpty) {
      final expected = _birthDateFromCurp(curp);
      if (expected.isNotEmpty && expected != normalized) {
        debugPrint(
          '[INE VALIDATION] rejected birth_date=$normalized reason=curp_mismatch expected=$expected',
        );
        return '';
      }
    }
    return normalized;
  }

  static String _validateExpiration(String value, {required String birthDate}) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '';
    if (!_isPlausibleDate(normalized, minYear: 2010, maxYear: 2100)) {
      debugPrint(
        '[INE VALIDATION] rejected expiration=$normalized reason=invalid_date',
      );
      return '';
    }
    if (birthDate.isNotEmpty && normalized == birthDate) {
      debugPrint(
        '[INE VALIDATION] rejected expiration=$normalized reason=matches_birth_date',
      );
      return '';
    }
    final expirationDate = DateTime.tryParse(normalized);
    if (expirationDate != null &&
        expirationDate.year < DateTime.now().year - 15) {
      debugPrint(
        '[INE VALIDATION] rejected expiration=$normalized reason=too_old',
      );
      return '';
    }
    return normalized;
  }

  static String _validateName(String value) {
    return _validatePersonName(value, allowSingleWord: false);
  }

  static String _validateLastName(String value) {
    return _validatePersonName(value, allowSingleWord: true);
  }

  static String _validatePersonName(
    String value, {
    required bool allowSingleWord,
  }) {
    final normalized = _dedupeWords(_normalizeOcrText(value));
    if (normalized.isEmpty) return '';
    if (!_isLikelyIneNameSegment(
      normalized,
      allowSingleWord: allowSingleWord,
    )) {
      debugPrint(
        '[INE VALIDATION] rejected name=$normalized reason=invalid_name',
      );
      return '';
    }
    if (RegExp(
      r'\b(MEX|MEX\.|LERMA|DOMICILIO|SECCI[O0]N|VIGENCIA|FECHA|CURP|CLAVE)\b',
    ).hasMatch(normalized)) {
      debugPrint(
        '[INE VALIDATION] rejected name=$normalized reason=keyword_noise',
      );
      return '';
    }
    if (_containsAddressKeyword(normalized)) {
      debugPrint(
        '[INE VALIDATION] rejected name=$normalized reason=address_noise',
      );
      return '';
    }
    return normalized;
  }

  static String _validateBase(String value) {
    final normalized = _normalizeOcrText(value).trim();
    if (normalized.isEmpty) return '';
    if (_looksLikeOcrGarbage(normalized)) {
      debugPrint(
        '[INE VALIDATION] rejected base=$normalized reason=ocr_garbage',
      );
      return '';
    }
    if (RegExp(r'[0-9/\\]').hasMatch(normalized)) {
      debugPrint(
        '[INE VALIDATION] rejected base=$normalized reason=invalid_chars',
      );
      return '';
    }
    if (RegExp(
      r'\b(CURP|OCR|CIC|CLAVE|VIGENCIA|SECCI[O0]N|DOMICILIO)\b',
    ).hasMatch(normalized)) {
      debugPrint(
        '[INE VALIDATION] rejected base=$normalized reason=keyword_noise',
      );
      return '';
    }
    if (RegExp(r'\bMEX\.?\b').hasMatch(normalized) &&
        !RegExp(r'^[A-Z]+(?: [A-Z]+)*, [A-Z]{2,4}\.?$').hasMatch(normalized)) {
      debugPrint(
        '[INE VALIDATION] rejected base=$normalized reason=too_generic',
      );
      return '';
    }
    if (!RegExp(r'^[A-Z .,-]{4,40}$').hasMatch(normalized)) {
      debugPrint('[INE VALIDATION] rejected base=$normalized reason=format');
      return '';
    }
    return _toTitleCase(normalized);
  }

  static String _validateAddress(String value) {
    final normalized = _normalizeOcrText(value).trim();
    if (normalized.isEmpty) return '';
    if (RegExp(
      r'\b(CURP|OCR|CIC|CLAVE|VIGENCIA|SECCI[O0]N|REGISTRO)\b',
    ).hasMatch(normalized)) {
      debugPrint(
        '[INE VALIDATION] rejected address=$normalized reason=keyword_noise',
      );
      return '';
    }
    final digits = RegExp(r'\d').allMatches(normalized).length;
    final letters = RegExp(r'[A-Z]').allMatches(normalized).length;
    if (letters < 4 || digits > letters) {
      debugPrint(
        '[INE VALIDATION] rejected address=$normalized reason=poor_quality',
      );
      return '';
    }
    return _toTitleCase(normalized);
  }

  static String _validateCic(String value, {required String birthDate}) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.length < 8 || digits.length > 12) {
      debugPrint('[INE VALIDATION] rejected cic=$digits reason=length');
      return '';
    }
    final birthDmy = _dateDigitsDmy(birthDate);
    if (birthDmy.isNotEmpty && digits == birthDmy) {
      debugPrint(
        '[INE VALIDATION] rejected cic=$digits reason=matches_birth_date',
      );
      return '';
    }
    return digits;
  }

  static String _validateOcr(String value, {required String birthDate}) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.length < 10 || digits.length > 14) {
      debugPrint('[INE VALIDATION] rejected ocr=$digits reason=length');
      return '';
    }
    final birthDmy = _dateDigitsDmy(birthDate);
    if (birthDmy.isNotEmpty && digits.startsWith(birthDmy)) {
      debugPrint(
        '[INE VALIDATION] rejected ocr=$digits reason=starts_with_birth_date',
      );
      return '';
    }
    return digits;
  }

  static String _dateDigitsDmy(String isoDate) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(isoDate);
    if (match == null) return '';
    return '${match.group(3)}${match.group(2)}${match.group(1)}';
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
