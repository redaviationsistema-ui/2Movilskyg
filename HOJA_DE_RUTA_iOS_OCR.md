# Hoja de Ruta: Solución OCR en iOS

## 🎯 Resumen Ejecutivo

**Problema:** En iOS, la INE se carga pero los datos no se extraen. Muestra error backend.

**Causa Raíz:** Hay un **BUG CRÍTICO** que deshabilita completamente el OCR de texto en iOS.

**Solución:** 5 parches de código + activar logs de debugging.

**Tiempo Estimado:** 30-45 minutos (incluida testing)

---

## 📋 Los 7 Problemas Identificados

| # | Problema | Severidad | ¿Causa error? | Solución |
|---|----------|-----------|---------------|----------|
| 1 | OCR texto deshabilitado en iOS | 🔴 CRÍTICO | **SÍ** | Parche 1 |
| 2 | HEIC/HEIF no detectado | 🟠 ALTO | Parcialmente | Parche 3 |
| 3 | Logs insuficientes | 🟡 MEDIO | No, pero impide debug | Parches 2-5 |
| 4 | Rotación EXIF | 🟡 MEDIO | Probablemente no | Investigar con logs |
| 5 | MIME type incorrecto | 🟡 MEDIO | Posible | Parche 5 + validar |
| 6 | Permisos archivos temp | 🟢 BAJO | Unlikely | Monitoria |
| 7 | Compresión imagen | 🟢 BAJO | No | Ya se hace bien |

---

## 🚀 Plan de Acción (Paso a Paso)

### Fase 1: Diagnóstico (10 min)
- [ ] Lee `DEBUG_iOS_OCR.md` sección "Plan de Debugging Paso a Paso"
- [ ] Implementa Parches 1-5 en tus archivos
- [ ] Ejecuta: `flutter clean && flutter pub get`

### Fase 2: Testing Simulador (15 min)
- [ ] Ejecuta en iOS Simulator: `flutter run -v`
- [ ] Abre Xcode Console
- [ ] Captura INE y verifica logs:
  - ✅ `[INE-PICK]` logs aparecen
  - ✅ `[OPTIMIZE]` logs aparecen
  - ✅ `[_scanText]` dice "iOS" (no "Plataforma no soportada")
  - ✅ `[OCR]` logs de barcode y texto
  - ✅ `[INE-BACKEND]` logs

### Fase 3: Análisis de Logs (10 min)
Usa el "Árbol de Decisión" en `DEBUG_iOS_OCR.md` para diagnosticar

### Fase 4: Testing Device Real (5 min)
- [ ] Si funciona en simulador, prueba en iPhone real
- [ ] Repetir captura de INE
- [ ] Verificar mismos logs

### Fase 5: Si Aún Falla (Escalación)
- [ ] Reúne todos los logs
- [ ] Abre issue técnico con:
  - Logs completos
  - Captura de pantalla de INE
  - Versión iOS/iPhone modelo
  - Respuesta backend (si llega)

---

## 📝 Checklist de Implementación

### Pre-Parches
- [ ] Backup de archivos (git commit)
- [ ] Descarga `DEBUG_iOS_OCR.md` y `PARCHES_CODIGO_iOS_OCR.md`

### Aplicar Parches (En Orden)
1. [ ] **Parche 1:** `servicio_ocr_registro.dart` línea 82 (CRÍTICO)
   - Cambia: `if (!Platform.isAndroid) return '';`
   - A: `if (!Platform.isAndroid && !Platform.isIOS) return '';`

2. [ ] **Parche 2:** `servicio_ocr_registro.dart` función `scanIne()`
   - Agrega logs en barcode y text scan

3. [ ] **Parche 3:** `pantalla_registro_cliente.dart` función `_pickIneFront()`
   - Valida archivo original
   - Valida optimizado
   - Detecta HEIC

4. [ ] **Parche 4:** `pantalla_registro_cliente.dart` función `_optimizeImageForProcessing()`
   - Logs de cada paso de procesamiento
   - Validación de escritura

5. [ ] **Parche 5:** `pantalla_registro_cliente.dart` función `_scanIneInBackend()`
   - Logs de MIME type
   - Logs de tamaño
   - Logs de respuesta backend

### Post-Parches
- [ ] `flutter analyze` (verificar no hay errores)
- [ ] `flutter pub get`
- [ ] Compilar para iOS: `flutter build ios --simulator -v`

---

## 🧪 Testing Workflow

### Captura de Referencia (Primero)
```
iPhone Simulator:
1. Abre la app
2. Ve a Registro → Capturar INE
3. Elige una INE de ejemplo (o toma foto de pantalla)
4. Abre Xcode Console
5. Copia TODO lo que aparezca desde [INE] hasta el final
```

### Verificaciones Clave
```
✅ Debe ver:
   [INE-PICK] Archivo original existe: true
   [OPTIMIZE] Decodificado: 1080x1920 (ej)
   [_scanText] Iniciando OCR. Plataforma: iOS ✓
   [OCR] Barcode scan completado. Encontrados: 1
   [OCR] Texto encontrado: 2843 caracteres
   [OCR] Resultado final: method=codigo_y_texto

❌ NO debe ver:
   [_scanText] ❌ Plataforma no soportada
   [OPTIMIZE] ❌ No se pudo decodificar
   [OCR] ⚠️ Text scan retornó vacío
```

---

## 📊 Matriz de Decisión (Qué Ver en Logs)

```
¿Qué apareció?                          → Qué significa

[_scanText] Plataforma: iOS ✓           → ✅ BUG CORREGIDO
[_scanText] Plataforma no soportada     → ❌ BUG NO CORREGIDO, revisa Parche 1

[OCR] Texto encontrado: 2843 chars      → ✅ OCR LOCAL FUNCIONA
[OCR] Text scan retornó vacío           → ❌ Vision no extrae texto

[OPTIMIZE] ✅ Guardado: ... KB          → ✅ Imagen se procesa bien
[OPTIMIZE] ❌ No se pudo decodificar    → ❌ Formato incompatible (HEIC?)

[INE-BACKEND] ✅ Respuesta backend: ... → ✅ Backend recibe imagen
[INE-BACKEND] ApiException: ...         → ❌ Backend rechaza imagen

[INE-BACKEND] ✅ Datos útiles: curp=... → ✅ ÉXITO COMPLETO
[INE-BACKEND] ⚠️ Respuesta sin datos    → ⚠️ Backend no reconoce INE
```

---

## 📞 Soporte: Qué hacer si falla

### Si ves: "Plataforma no soportada"
→ No aplicaste Parche 1 correctamente
→ Revisa línea 82 de `servicio_ocr_registro.dart`

### Si ves: "Text scan retornó vacío"
→ Vision framework de iOS no extrae texto
→ Posibles causas:
   - INE está rotada
   - INE está borrosa
   - INE tiene reflejos
   - Vision no soporta ese idioma

### Si ves: "No se pudo decodificar"
→ Problema con formato HEIC
→ Verifica que image_picker devuelve JPEG en iOS
→ Solución temporal: Fuerza JPEG en image_picker

### Si ves: "Backend rechaza imagen"
→ MIME type incorrecto
→ Tamaño de imagen fuera de rango
→ Backend requiere formato diferente

---

## 🔍 Debugging Avanzado (Si Aún Falla)

### Habilitar Logs Nativos en Xcode
```
Product → Scheme → Edit Scheme → Run (Debug)
Arguments Passed On Launch:
    -com.apple.CoreML.verbose 1
    -com.apple.Vision.verbose 1
```

### Ver Todos los Logs de la App
```bash
# En Terminal
log stream --predicate 'process == "RedSkyApp"' --level debug

# O en Xcode Console, filtrar por:
com.example.skygmovil
```

### Validar Archivo Temporal en Simulator
```bash
# Encuentra dónde se guardan archivos temp en simulador
cd ~/Library/Developer/CoreSimulator/Devices/[DEVICE_ID]/data/Containers/Data/Library/Caches

# Busca archivos _optimized.jpg
find . -name "*_optimized.jpg" -exec file {} \;
```

---

## 📱 Diferencias Android vs iOS

| Aspecto | Android | iOS |
|--------|---------|-----|
| OCR Local | ML Kit TextRecognition | Vision framework |
| Idiomas | DEFAULT (detección automática) | es-MX, es-419, en-US |
| Formato Imagen | Casi siempre JPEG | HEIC en cámara reciente |
| Rotación EXIF | Se maneja automático | Requiere validación |
| Temp Directory | `/data/data/app/cache` | `/Caches` privado |
| Image Picker | Devuelve JPEG | Puede devolver HEIC |

---

## ✅ Checklist Final de Validación

```
ANTES DE DECLARAR ÉXITO:

[ ] En iOS Simulator:
    ✅ Captura INE
    ✅ Aparecen logs [INE-PICK]
    ✅ Aparecen logs [OPTIMIZE]
    ✅ Aparecen logs [_scanText] Plataforma: iOS
    ✅ Aparecen logs [OCR] con texto extraído
    ✅ Datos se rellenan en formulario

[ ] En iOS Device Real:
    ✅ Mismo flujo que simulador
    ✅ Con INE real (no de pantalla)
    ✅ Con diferentes ángulos
    ✅ Con diferentes iluminaciones

[ ] Comparar con Android:
    ✅ Ambos tienen OCR local
    ✅ Ambos pueden usar backend
    ✅ Tiempo similar de procesamiento

[ ] Documentación:
    ✅ Agregar comentarios en código
    ✅ Documentar qué cambió
    ✅ Guardar logs de prueba exitosa
```

---

## 🎓 Lecciones Aprendidas (Para Futuro)

1. **Plataforma Check:** Siempre valida `Platform.isAndroid && Platform.isIOS` juntos
2. **HEIC en iOS:** Image Picker puede devolver HEIC, hay que convertir
3. **Logs es Debugging:** Los logs que agregaste son CRÍTICOS para iOS
4. **Testing Cross-Platform:** Android ≠ iOS, requiere testing en ambos
5. **Vision Framework:** Soporta Spanish, pero hay que especificarlo

---

## 📞 Contacto para Escalación

Si después de todos estos pasos aún falla:
1. Recopila **todos los logs desde inicio hasta error**
2. Captura de pantalla del INE que usaste
3. Versión de iOS e iPhone modelo
4. Respuesta completa del backend (si llega)
5. Envía a equipo técnico backend para revisar endpoint

---

## 📚 Referencias en el Código

**AppDelegate.swift** - Implementación iOS Vision:
- Vision framework está bien configurado ✓
- Soporta idiomas es-MX y es-419 ✓
- Accuracy es "accurate" ✓

**MainActivity.kt** - Implementación Android ML Kit:
- Android funciona correctamente ✓

**servicio_ocr_registro.dart** - El problema:
- Línea 82 tiene el BUG ❌
- Necesita fix inmediato ✓

---

## 🎯 Meta Final

**Cuando termines, deberías ver en iOS:**
```
[OCR] Resultado final: method=codigo_y_texto total_chars=8472 barcodes=1 texts=1
[INE-BACKEND] ✅ Datos útiles detectados: document=XXXXX curp=XXXXX name=...
```

Sin eso, el flujo no funciona en iOS. Con eso, tienes paridad con Android.

