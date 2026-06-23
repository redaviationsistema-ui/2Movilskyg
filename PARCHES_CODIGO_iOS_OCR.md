# Parches de Código: Correcciones iOS OCR

Este archivo contiene código listo para copiar/pegar que soluciona los problemas identificados.

## PARCHE 1: Corregir OCR Deshabilitado en iOS (CRÍTICO)

**Archivo:** `lib/services/servicio_ocr_registro.dart`
**Línea:** 82

### Antes:
```dart
  static Future<String> _scanText(String path) async {
    if (!Platform.isAndroid) return '';
    final response = await _ocrChannel.invokeMapMethod<String, dynamic>(
      'recognizeText',
      {'path': path},
    );
    return (response?['text'] ?? '').toString().trim();
  }
```

### Después:
```dart
  static Future<String> _scanText(String path) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('[_scanText] ❌ Plataforma no soportada: ${Platform.operatingSystem}');
      return '';
    }
    
    debugPrint('[_scanText] Iniciando OCR. Plataforma: ${Platform.operatingSystem}');
    debugPrint('[_scanText] Ruta: $path');
    
    try {
      final response = await _ocrChannel.invokeMapMethod<String, dynamic>(
        'recognizeText',
        {'path': path},
      );
      
      final text = (response?['text'] ?? '').toString().trim();
      debugPrint('[_scanText] ✅ OCR completado: ${text.length} caracteres');
      
      return text;
    } catch (e) {
      debugPrint('[_scanText] ❌ Error en OCR: $e');
      rethrow;
    }
  }
```

---

## PARCHE 2: Agregar Logs en scanIne() 

**Archivo:** `lib/services/servicio_ocr_registro.dart`
**Línea:** 27-70 (función scanIne)

### Reemplazar:
```dart
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
```

### Reemplazar con:
```dart
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
        
        debugPrint('[OCR] Procesando imagen $index: ${source.path}');
        
        try {
          debugPrint('[OCR] Iniciando barcode scan...');
          final capture = await scanner.analyzeImage(source.path);
          final barcodeCount = capture?.barcodes.length ?? 0;
          debugPrint('[OCR] Barcode scan completado. Encontrados: $barcodeCount');
          
          for (final barcode in capture?.barcodes ?? const <Barcode>[]) {
            final value = barcode.rawValue?.trim() ?? '';
            if (value.isNotEmpty) {
              debugPrint('[OCR] ✅ Barcode: $value');
              barcodeParts.add(value);
            }
          }
        } catch (e) {
          debugPrint('[OCR] ⚠️ Barcode scan falló: $e');
        }

        try {
          debugPrint('[OCR] Iniciando text scan (OCR)...');
          final text = await _scanText(source.path);
          if (text.isNotEmpty) {
            debugPrint('[OCR] ✅ Texto encontrado: ${text.length} caracteres');
            textParts.add(text);
          } else {
            debugPrint('[OCR] ⚠️ Text scan retornó vacío');
          }
        } catch (e) {
          debugPrint('[OCR] ⚠️ Text scan falló: $e');
        }
      }
    } finally {
      await scanner.dispose();
    }

    final rawText = [
      if (barcodeParts.isNotEmpty) barcodeParts.join('\n\n'),
      if (textParts.isNotEmpty) textParts.join('\n\n'),
    ].join('\n\n');

    final method = barcodeParts.isNotEmpty && textParts.isNotEmpty
        ? 'codigo_y_texto'
        : barcodeParts.isNotEmpty
        ? 'codigo'
        : textParts.isNotEmpty
        ? 'texto'
        : 'sin_datos';

    debugPrint('[OCR] Resultado final: method=$method total_chars=${rawText.length} barcodes=${barcodeParts.length} texts=${textParts.length}');

    return RegistrationOcrResult(
      rawText: rawText,
      fields: _parseIne(rawText),
      method: method,
    );
  }
```

---

## PARCHE 3: Agregar Logs en _pickIneFront()

**Archivo:** `lib/screens/auth/pantalla_registro_cliente.dart`
**Línea:** 92

### Reemplazar función completa:
```dart
  Future<void> _pickIneFront() async {
    final selected = await _selectDocumentImage('INE');
    if (selected == null) return;
    final optimized = await _optimizeImageForProcessing(selected);
    if (!mounted) return;

    debugPrint(
      '[INE] Archivo seleccionado: original=${selected.path} optimized=${optimized.path}',
    );

    setState(() {
      _ineFront = optimized;
      _documentScanMessage = 'Escaneando datos de la INE en el dispositivo...';
    });
    await _scanIneLocally();
  }
```

### Con:
```dart
  Future<void> _pickIneFront() async {
    final selected = await _selectDocumentImage('INE');
    if (selected == null) return;
    
    // Validar que existe
    final exists = await selected.exists();
    debugPrint('[INE-PICK] Archivo original existe: $exists');
    
    // Validar tamaño
    if (exists) {
      final size = await selected.length();
      final sizeMB = (size / 1024 / 1024).toStringAsFixed(2);
      final ext = selected.path.split('.').last.toLowerCase();
      debugPrint('[INE-PICK] Original: ext=$ext size=${size} bytes ($sizeMB MB)');
      
      if (ext == 'heic' || ext == 'heif') {
        debugPrint('[INE-PICK] ⚠️ HEIC/HEIF detectado. Será convertido a JPEG.');
      }
    }
    
    final optimized = await _optimizeImageForProcessing(selected);
    if (!mounted) return;
    
    // Validar que optimized existe
    final optimizedExists = await optimized.exists();
    debugPrint('[INE-PICK] Optimized existe: $optimizedExists');
    if (optimizedExists) {
      final size = await optimized.length();
      debugPrint('[INE-PICK] Optimized: ${optimized.path} size=${(size/1024).toStringAsFixed(2)} KB');
    }

    debugPrint(
      '[INE] Archivo seleccionado: original=${selected.path} → optimized=${optimized.path}',
    );

    setState(() {
      _ineFront = optimized;
      _documentScanMessage = 'Escaneando datos de la INE en el dispositivo...';
    });
    await _scanIneLocally();
  }
```

---

## PARCHE 4: Agregar Logs en _optimizeImageForProcessing()

**Archivo:** `lib/screens/auth/pantalla_registro_cliente.dart`
**Línea:** 530

### Reemplazar:
```dart
  Future<File> _optimizeImageForProcessing(File source) async {
    try {
      final bytes = await source.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return source;

      const maxDimension = 1600;
      final resized =
          decoded.width > maxDimension || decoded.height > maxDimension
              ? img.copyResize(
                decoded,
                width: decoded.width >= decoded.height ? maxDimension : null,
                height: decoded.height > decoded.width ? maxDimension : null,
                interpolation: img.Interpolation.average,
              )
              : decoded;

      final output = img.encodeJpg(resized, quality: 85);
      final tempDir = await getTemporaryDirectory();
      final fileName =
          '${path.basenameWithoutExtension(source.path)}_optimized.jpg';
      final optimizedFile = File(path.join(tempDir.path, fileName));
      await optimizedFile.writeAsBytes(output, flush: true);
      return optimizedFile;
    } catch (_) {
      return source;
    }
  }
```

### Con:
```dart
  Future<File> _optimizeImageForProcessing(File source) async {
    try {
      final ext = source.path.split('.').last.toLowerCase();
      debugPrint('[OPTIMIZE] Procesando: ext=$ext path=${source.path}');
      
      final bytes = await source.readAsBytes();
      debugPrint('[OPTIMIZE] Bytes leídos: ${bytes.length}');
      
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        debugPrint('[OPTIMIZE] ❌ No se pudo decodificar. Retornando original.');
        return source;
      }

      debugPrint('[OPTIMIZE] Decodificado: ${decoded.width}x${decoded.height}');

      const maxDimension = 1600;
      final resized =
          decoded.width > maxDimension || decoded.height > maxDimension
              ? img.copyResize(
                decoded,
                width: decoded.width >= decoded.height ? maxDimension : null,
                height: decoded.height > decoded.width ? maxDimension : null,
                interpolation: img.Interpolation.average,
              )
              : decoded;

      debugPrint('[OPTIMIZE] Redimensionado: ${resized.width}x${resized.height}');

      final output = img.encodeJpg(resized, quality: 85);
      debugPrint('[OPTIMIZE] JPEG encodificado: ${output.length} bytes');
      
      final tempDir = await getTemporaryDirectory();
      final fileName =
          '${path.basenameWithoutExtension(source.path)}_optimized.jpg';
      final optimizedFile = File(path.join(tempDir.path, fileName));
      
      await optimizedFile.writeAsBytes(output, flush: true);
      
      final written = await optimizedFile.length();
      debugPrint('[OPTIMIZE] ✅ Guardado: ${optimizedFile.path} (${written} bytes)');
      
      return optimizedFile;
    } catch (e) {
      debugPrint('[OPTIMIZE] ❌ Error: $e');
      return source;
    }
  }
```

---

## PARCHE 5: Agregar Logs en _scanIneInBackend()

**Archivo:** `lib/screens/auth/pantalla_registro_cliente.dart`
**Línea:** 280

### Reemplazar:
```dart
  Future<void> _scanIneInBackend(List<File> images) async {
    for (final image in images) {
      debugPrint('[INE] Enviando imagen al backend: ${image.path}');
      final response = await _api.scanRegistrationDocument(
        document: image,
        documentType: 'INE',
      );
      debugPrint('[INE] Respuesta backend cruda: $response');
      _applyBackendIneResponse(response);
      if (_hasUsefulIneData()) {
        debugPrint(
          '[INE] Backend detecto datos utiles: document=${_documentNumberController.text} curp=${_ineCurpController.text} name=${_nameController.text} expiration=${_documentExpirationController.text}',
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _applyIneFallback(images.first);
      _documentScanMessage = 'Se leyo parcialmente la INE. Completa los campos faltantes manualmente.';
    });
  }
```

### Con:
```dart
  Future<void> _scanIneInBackend(List<File> images) async {
    for (final image in images) {
      debugPrint('[INE-BACKEND] Enviando imagen al backend: ${image.path}');
      
      // Validar MIME type
      final ext = image.path.split('.').last.toLowerCase();
      final mimeType = ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 'image/${ext}';
      debugPrint('[INE-BACKEND] MIME type: $mimeType');
      
      // Validar tamaño
      final size = await image.length();
      debugPrint('[INE-BACKEND] Tamaño: ${(size / 1024).toStringAsFixed(2)} KB');
      
      try {
        final response = await _api.scanRegistrationDocument(
          document: image,
          documentType: 'INE',
        );
        debugPrint('[INE-BACKEND] ✅ Respuesta backend: $response');
        _applyBackendIneResponse(response);
        
        if (_hasUsefulIneData()) {
          debugPrint(
            '[INE-BACKEND] ✅ Datos útiles detectados: document=${_documentNumberController.text} curp=${_ineCurpController.text} name=${_nameController.text} expiration=${_documentExpirationController.text}',
          );
          return;
        } else {
          debugPrint('[INE-BACKEND] ⚠️ Respuesta sin datos útiles');
        }
      } on ApiException catch (apiError) {
        debugPrint('[INE-BACKEND] ❌ ApiException: code=${apiError.code} message=${apiError.message}');
        rethrow;
      } catch (error) {
        debugPrint('[INE-BACKEND] ❌ Error no tipificado: $error');
        rethrow;
      }
    }

    if (!mounted) return;
    setState(() {
      _applyIneFallback(images.first);
      _documentScanMessage = 'Se leyo parcialmente la INE. Completa los campos faltantes manualmente.';
    });
  }
```

---

## APLICACIÓN DE PARCHES

### Opción 1: Copiar/Pegar Manual
1. Abre cada archivo mencionado
2. Encuentra la sección indicada
3. Reemplaza con el código del parche

### Opción 2: Con VSCode Search & Replace
1. Ctrl+H (Cmd+H en Mac)
2. Habilita Regex: `.*` button
3. Busca el "Antes" y reemplaza con "Después"

### Opción 3: Usar `patch` command (si tienes Unix)
```bash
# Crear archivo .patch y aplicarlo
patch < parches.patch
```

---

## Verificación Post-Parches

1. **Ejecutar en simulador iOS:**
   ```bash
   flutter clean
   flutter pub get
   flutter run -v
   ```

2. **Abrir Console de Xcode:**
   ```
   View → Debug Area → Activate Console
   ```

3. **Reproducir flujo OCR:**
   - Ir a Registro
   - Capturar INE
   - Buscar logs `[INE]`, `[OCR]`, `[OPTIMIZE]`

4. **Verificar que NO veas:**
   ```
   [_scanText] ❌ Plataforma no soportada
   [OCR] ⚠️ Text scan retornó vacío
   ```

