# Guía de Debug: OCR de INE en iOS

## Resumen Ejecutivo

He identificado **un BUG CRÍTICO** y varias vulnerabilidades en el flujo de OCR para iOS:

| # | Problema | Severidad | Ubicación |
|---|----------|-----------|-----------|
| 1 | **OCR de texto deshabilitado en iOS** | 🔴 CRÍTICO | `servicio_ocr_registro.dart:82` |
| 2 | Formato HEIC/HEIF no detectado | 🟠 ALTO | Image Picker → `_optimizeImageForProcessing` |
| 3 | Rotación EXIF podría no corregirse | 🟠 ALTO | `_optimizeImageForProcessing` en iOS |
| 4 | Logs insuficientes para diagnosticar | 🟡 MEDIO | Múltiples puntos |
| 5 | MIME type podría ser incorrecto | 🟡 MEDIO | Backend multipart upload |

---

## 1. El BUG CRÍTICO: OCR Deshabilitado en iOS

### Ubicación
**Archivo:** `lib/services/servicio_ocr_registro.dart`, línea 82

```dart
static Future<String> _scanText(String path) async {
    if (!Platform.isAndroid) return '';  // ❌ BUG: iOS siempre devuelve vacío
    final response = await _ocrChannel.invokeMapMethod<String, dynamic>(
      'recognizeText',
      {'path': path},
    );
    return (response?['text'] ?? '').toString().trim();
}
```

### El Problema
- Esta condición hace que **en iOS nunca se intente OCR de texto**
- Solo intenta barcode (PDF417, QR, etc.)
- Si el INE no tiene código legible o está mal orientado, falla
- Luego intenta backend, pero si backend también falla → error

### Prueba Rápida: ¿Es esto el problema?
```dart
// Log antes de la condición
debugPrint('[OCR] Platform check: isAndroid=${Platform.isAndroid} isIOS=${Platform.isIOS}');
if (!Platform.isAndroid) return '';
```

---

## 2. Plan de Debugging Paso a Paso

### PASO 1: Validar Que la Imagen Se Carga Correctamente

**Agregar estos logs en `_pickIneFront()`** (`pantalla_registro_cliente.dart:92`):

```dart
Future<void> _pickIneFront() async {
    final selected = await _selectDocumentImage('INE');
    if (selected == null) return;
    
    // ✅ VALIDACIÓN 1: Archivo existe
    final exists = await selected.exists();
    debugPrint('[INE-DEBUG] Archivo existe: $exists path=${selected.path}');
    
    // ✅ VALIDACIÓN 2: Tamaño
    final size = await selected.length();
    debugPrint('[INE-DEBUG] Tamaño original: ${size} bytes (${(size/1024/1024).toStringAsFixed(2)} MB)');
    
    // ✅ VALIDACIÓN 3: Formato/Extensión
    final ext = selected.path.split('.').last.toLowerCase();
    debugPrint('[INE-DEBUG] Extensión: $ext (formato de cámara iOS usa .jpg, pero revisa si es HEIC)');
    
    final optimized = await _optimizeImageForProcessing(selected);
    if (!mounted) return;

    // ✅ VALIDACIÓN 4: Imagen optimizada existe
    final optimizedExists = await optimized.exists();
    final optimizedSize = optimizedExists ? await optimized.length() : 0;
    debugPrint('[INE-DEBUG] Optimizada existe: $optimizedExists size=${optimizedSize} bytes');
    
    debugPrint('[INE] Archivo: original=${selected.path} → optimized=${optimized.path}');

    setState(() {
      _ineFront = optimized;
      _documentScanMessage = 'Escaneando datos de la INE en el dispositivo...';
    });
    await _scanIneLocally();
}
```

### PASO 2: Validar OCR Local en iOS (CRÍTICO)

**Modificar `servicio_ocr_registro.dart:75-95`**:

```dart
static Future<RegistrationOcrResult> scanIne(List<File> images) async {
    final scanner = MobileScannerController(formats: [...]);
    final barcodeParts = <String>[];
    final textParts = <String>[];

    try {
      for (var index = 0; index < images.length; index++) {
        final source = images[index];
        
        // ✅ LOG: Validar que archivo existe
        debugPrint('[OCR] Intentando escanear imagen $index: ${source.path}');
        final exists = await source.exists();
        debugPrint('[OCR] Archivo existe: $exists');
        
        try {
          debugPrint('[OCR] Intentando barcode scan...');
          final capture = await scanner.analyzeImage(source.path);
          for (final barcode in capture?.barcodes ?? const <Barcode>[]) {
            final value = barcode.rawValue?.trim() ?? '';
            if (value.isNotEmpty) {
              debugPrint('[OCR] ✅ Barcode encontrado: $value');
              barcodeParts.add(value);
            }
          }
          debugPrint('[OCR] Barcode scan completado. Encontrados: ${barcodeParts.length}');
        } catch (e) {
          debugPrint('[OCR] ❌ Error en barcode: $e');
        }

        try {
          debugPrint('[OCR] Intentando text scan... Platform=${Platform.operatingSystem}');
          
          // ✅ LOG: Validar qué plataforma se detecta
          if (Platform.isAndroid) {
            debugPrint('[OCR] Plataforma: Android ✓');
          } else if (Platform.isIOS) {
            debugPrint('[OCR] Plataforma: iOS ✓');
          } else {
            debugPrint('[OCR] ⚠️ Plataforma desconocida: ${Platform.operatingSystem}');
          }
          
          final text = await _scanText(source.path);
          if (text.isNotEmpty) {
            debugPrint('[OCR] ✅ Texto encontrado (${text.length} chars): ${text.substring(0, 100.clamp(0, text.length))}...');
            textParts.add(text);
          } else {
            debugPrint('[OCR] ⚠️ OCR retornó texto vacío');
          }
        } catch (e) {
          debugPrint('[OCR] ❌ Error en OCR de texto: $e');
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

    debugPrint('[OCR] Resultado final: method=$method rawTextLength=${rawText.length} barcodes=${barcodeParts.length} texts=${textParts.length}');

    return RegistrationOcrResult(
      rawText: rawText,
      fields: _parseIne(rawText),
      method: method,
    );
}

static Future<String> _scanText(String path) async {
    // ✅ NUEVA VALIDACIÓN: Log de intento y plataforma
    debugPrint('[_scanText] Iniciando OCR de texto. Plataforma=${Platform.operatingSystem}');
    debugPrint('[_scanText] Ruta: $path');
    
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('[_scanText] ⚠️ Plataforma no soportada');
      return '';
    }
    
    if (Platform.isAndroid) {
      debugPrint('[_scanText] Android: procediendo con OCR nativo');
    } else if (Platform.isIOS) {
      debugPrint('[_scanText] iOS: procediendo con OCR nativo (Vision framework)');
    }
    
    try {
      debugPrint('[_scanText] Llamando método nativo: recognizeText');
      final response = await _ocrChannel.invokeMapMethod<String, dynamic>(
        'recognizeText',
        {'path': path},
      );
      debugPrint('[_scanText] Respuesta nativa: $response');
      
      final text = (response?['text'] ?? '').toString().trim();
      debugPrint('[_scanText] Texto extraído (${text.length} chars)');
      
      return text;
    } catch (e) {
      debugPrint('[_scanText] ❌ Error en llamada nativa: $e');
      rethrow;
    }
}
```

### PASO 3: Validar Backend Response

**En `pantalla_registro_cliente.dart`, función `_scanIneInBackend`** (línea 280):

```dart
Future<void> _scanIneInBackend(List<File> images) async {
    for (final image in images) {
      debugPrint('[INE-BACKEND] Enviando imagen al backend: ${image.path}');
      
      // ✅ Validar MIME type antes de enviar
      final ext = image.path.split('.').last.toLowerCase();
      final mimeType = ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 'image/${ext}';
      debugPrint('[INE-BACKEND] MIME type: $mimeType');
      
      // ✅ Validar tamaño antes de enviar
      final size = await image.length();
      debugPrint('[INE-BACKEND] Tamaño: ${(size/1024).toStringAsFixed(2)} KB');
      
      try {
        final response = await _api.scanRegistrationDocument(
          document: image,
          documentType: 'INE',
        );
        debugPrint('[INE-BACKEND] Respuesta backend: $response');
        _applyBackendIneResponse(response);
        
        if (_hasUsefulIneData()) {
          debugPrint('[INE-BACKEND] ✅ Backend detecto datos útiles');
          return;
        }
      } on ApiException catch (apiError) {
        debugPrint('[INE-BACKEND] ❌ ApiException: code=${apiError.code} message=${apiError.message} details=${apiError.details}');
        rethrow;
      } catch (error) {
        debugPrint('[INE-BACKEND] ❌ Error desconocido: $error');
        rethrow;
      }
    }
}
```

### PASO 4: Validar Formato HEIC/HEIF

**Agregar en `_optimizeImageForProcessing`** (línea 535):

```dart
Future<File> _optimizeImageForProcessing(File source) async {
    try {
      final ext = source.path.split('.').last.toLowerCase();
      debugPrint('[OPTIMIZE] Extensión original: $ext');
      
      // ⚠️ ADVERTENCIA: En iOS, si es HEIC, debugPrint lo
      if (ext == 'heic' || ext == 'heif') {
        debugPrint('[OPTIMIZE] ⚠️ ADVERTENCIA: Imagen en formato HEIC/HEIF en iOS. Convertiendo a JPEG...');
      }
      
      final bytes = await source.readAsBytes();
      final decoded = img.decodeImage(bytes);
      
      if (decoded == null) {
        debugPrint('[OPTIMIZE] ❌ No se pudo decodificar imagen. Retornando original.');
        return source;
      }
      
      debugPrint('[OPTIMIZE] Imagen decodificada: ${decoded.width}x${decoded.height}');

      const maxDimension = 1600;
      final resized = decoded.width > maxDimension || decoded.height > maxDimension
          ? img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? maxDimension : null,
              height: decoded.height > decoded.width ? maxDimension : null,
              interpolation: img.Interpolation.average,
            )
          : decoded;

      debugPrint('[OPTIMIZE] Redimensionada a: ${resized.width}x${resized.height}');

      final output = img.encodeJpg(resized, quality: 85);
      debugPrint('[OPTIMIZE] JPEG codificado: ${output.length} bytes');
      
      final tempDir = await getTemporaryDirectory();
      debugPrint('[OPTIMIZE] Directorio temporal: ${tempDir.path}');
      
      final fileName = '${path.basenameWithoutExtension(source.path)}_optimized.jpg';
      final optimizedFile = File(path.join(tempDir.path, fileName));
      
      await optimizedFile.writeAsBytes(output, flush: true);
      
      // ✅ Validar que se escribió correctamente
      final written = await optimizedFile.length();
      debugPrint('[OPTIMIZE] ✅ Archivo optimizado guardado: ${optimizedFile.path} (${written} bytes)');
      
      return optimizedFile;
    } catch (e) {
      debugPrint('[OPTIMIZE] ❌ Error: $e');
      debugPrint('[OPTIMIZE] Retornando archivo original sin procesar');
      return source;
    }
}
```

---

## 3. Árbol de Decisión para Diagnosticar

```
┌─ Imagen se carga? ──────────────────────────────┐
│                                                   │
├─ SÍ: ¿HEIC/HEIF?                                │
│      ├─ SÍ: log dice "HEIC/HEIF" ✓             │
│      │    ¿Se convierte a JPEG?                 │
│      │    └─ Buscar "[OPTIMIZE] ✅ JPEG"       │
│      │                                           │
│      └─ NO: Continúa con JPEG/PNG normal ✓     │
│                                                   │
├─ OCR LOCAL iOS                                   │
│  ├─ ¿Log "[_scanText] iOS: procediendo"?        │
│  │   ├─ NO: El iOS NO llama a OCR (BUG 1)      │
│  │   └─ SÍ: Continúa...                         │
│  │                                               │
│  ├─ ¿Log "[OCR] ✅ Texto encontrado"?          │
│  │   ├─ NO: Vision framework falla en iOS       │
│  │   └─ SÍ: OCR local funciona ✓               │
│  │                                               │
│  └─ ¿Backend intenta?                           │
│      ├─ NO: No llega a backend                   │
│      └─ SÍ: Continúa...                         │
│                                                   │
├─ BACKEND RESPONSE                               │
│  └─ ¿Log "[INE-BACKEND] Respuesta"?            │
│      ├─ Error: Ver "[INE-BACKEND] ❌"          │
│      └─ Success: Revisar qué campos retorna    │
│                                                   │
└──────────────────────────────────────────────────┘
```

---

## 4. Checklist de Validaciones Manuales

### En Xcode/Console de iOS

1. **¿Aparecen logs nativos de Vision?**
   ```
   [iOS OCR] recognizeText path=...
   [iOS OCR] Vision success observations=...
   ```

2. **¿Se cargan imágenes en `temp` correctamente?**
   ```bash
   # En simulator
   log stream --predicate 'process == "com.example.skygmovil"' --level debug
   ```

3. **¿AppDelegate.swift recibe la ruta?**
   - Agregar breakpoint en `recognizeText()`
   - Verificar que `imagePath` no está vacío

### En Device (iPhone Real)

1. Conectar iPhone
2. Xcode → Window → Devices and Simulators
3. Seleccionar device → Console
4. Reproducir flujo
5. Buscar logs `[iOS OCR]` y `[INE]`

---

## 5. Soluciones por Severidad

### 🔴 CRÍTICO - Arreglar Inmediatamente

**Modificar `servicio_ocr_registro.dart:82`:**

```dart
// ❌ ANTES:
static Future<String> _scanText(String path) async {
    if (!Platform.isAndroid) return '';  // iOS nunca OCR
    
// ✅ DESPUÉS:
static Future<String> _scanText(String path) async {
    if (!Platform.isAndroid && !Platform.isIOS) return '';  // Solo si NO es Android NI iOS
    
    final response = await _ocrChannel.invokeMapMethod<String, dynamic>(
      'recognizeText',
      {'path': path},
    );
    return (response?['text'] ?? '').toString().trim();
}
```

### 🟠 ALTO - Prioridad Alta

**Validar formato HEIC en Image Picker:**

```dart
// En _selectDocumentImage() después de pickImage:
if (picked != null && Platform.isIOS) {
    final ext = picked.path.split('.').last.toLowerCase();
    if (ext == 'heic' || ext == 'heif') {
        debugPrint('[WARNING] Image Picker devolvió HEIC en iOS. Asegúrate que _optimizeImageForProcessing() lo convierte.');
    }
}
```

### 🟡 MEDIO - Agregar Logs

Ver PASO 1-4 arriba (logs recomendados).

---

## 6. Secuencia de Testing Recomendada

1. **Implementar logs de PASO 1-4**
2. **Corregir BUG CRÍTICO** en `servicio_ocr_registro.dart:82`
3. **Ejecutar en iOS Simulator primero:**
   - Tomar foto con cámara
   - Verificar que imagen se optimiza
   - Ver logs en Xcode console
4. **Ejecutar en Device iOS real:**
   - Repetir con imagen real
   - Verificar Vision framework logs
5. **Comparar con Android** (que funciona)

---

## 7. Referencias de Código

### iOS Vision Framework (AppDelegate.swift)
- Usa `VNRecognizeTextRequest`
- Idiomas: es-MX, es-419, en-US ✓
- Level: accurate ✓
- **Está bien configurado**, pero iOS nunca lo llama desde Dart

### Android ML Kit (MainActivity.kt)
- Usa `TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)`
- **Funciona correctamente**

### Image Processing (pantalla_registro_cliente.dart)
- `_optimizeImageForProcessing()` convierte a JPEG
- Redimensiona a máx 1600px
- Comprime a 85% quality
- **Está bien**, pero validar flujo en iOS

---

## 8. Pasos Finales de Verificación

Después de implementar logs y corregir el BUG:

```bash
# 1. Compilar para iOS
flutter clean
flutter pub get
flutter build ios --simulator -v

# 2. Ejecutar
flutter run -v

# 3. En otra terminal, ver logs
log stream --predicate 'process == "com.example.skygmovil"' --level debug

# 4. Ejecutar OCR de INE
# - Capturar imagen
# - Verificar logs
```

---

## Información de Contacto para Debugging

Si después de implementar estos logs aún falla, recopila:
1. Completos logs desde `[INE]` inicial hasta final
2. Screenshot de la INE capturada
3. Device: iPhone modelo/iOS versión
4. Respuesta completa del backend (si llega)

