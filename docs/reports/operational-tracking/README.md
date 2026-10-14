# Seguimiento operacional — implementación y auditoría

Fecha: 14 de octubre de 2026.

El seguimiento utiliza una portada compacta, resumen de la reserva seleccionada, timeline abierto con construcción diferida y un único módulo de próximo paso. Los datos se mantienen vinculados a la operación recibida por navegación. No se agregaron endpoints ni se modificó el backend.

## Archivos y resultados

| Archivo revisado | Modificado | Funcionalidad | Cambio aplicado | Prueba ejecutada | Resultado |
| --- | --- | --- | --- | --- | --- |
| `lib/screens/cliente/views/pantalla_seguimiento_cliente.dart` | Sí | Pantalla de seguimiento | Portada, resumen, timeline abierto y próximo paso; `ListView.builder` para historiales extensos | Estados reales, 100 eventos, scroll y accesibilidad | Correcto |
| `lib/screens/cliente/presentation/tracking_presentation.dart` | Nuevo | Presentación de estados y eventos | Traducción prudente, lectura de liberaciones, orden cronológico descendente y deduplicación exacta | Códigos conocidos/desconocidos, liberación sin despegue y eventos legítimos | Correcto |
| `lib/models/client_operation_tracking.dart` | Sí | DTO de lectura de la API | Conserva ID del evento, operación y firma del contenido original para distinguir copias | Parser y conservación del contenido | Correcto; no cambia persistencia ni contrato de API |
| `lib/screens/cliente/widgets/lista_vuelos_cliente.dart` | Sí | Reservas → Ver seguimiento | Pasa la fila seleccionada, nombre e imagen disponibles junto al mismo operation ID | Navegación desde lista real con vuelo destacado y reserva distinta | Correcto |
| `test/screens/cliente/views/pantalla_seguimiento_cliente_test.dart` | Sí | Pruebas de pantalla | Estados, navegación, polling, respuestas obsoletas, privacidad, foto desactualizada y responsive | Widget tests | Correcto |
| `test/screens/cliente/presentation/tracking_presentation_test.dart` | Nuevo | Pruebas de presentación | Duplicados, eventos repetidos, códigos y señales operativas independientes | Unit tests | Correcto |
| `test/models/client_operation_tracking_test.dart` | Sí | Pruebas del DTO | Verifica conservación del ID y contenido original | Unit tests | Correcto |
| `test/screens/cliente/widgets/lista_vuelos_cliente_test.dart` | Sí | Navegación desde Reservas | Comprueba que se abre la reserva pulsada, no el próximo vuelo destacado; comprueba regreso | Widget test de la lista real | Correcto |
| `integration_test/operational_tracking_presentation_test.dart` y `test/fixtures/operational_tracking.dart` | Nuevos | Prueba de presentación en dispositivo | Renderiza el flujo con datos exclusivos de test, texto normal/ampliado e itinerario completo | Ejecución nativa separada de la suite de widgets | Resultado documentado abajo |
| `lib/core/cliente_api.dart` | No | Consulta autenticada | Se conserva GET `/client/operations/{id}/tracking` | Revisión del servicio y pruebas de integración de pantalla con loaders de test | Sin cambios |
| Backend hermano: `app/Http/Controladores/RedAviation/ClienteControlador.php` | No | Consulta y autorización | Auditoría de `tracking`: comprueba propietario y devuelve el timeline de esa operación | Lectura del código local | Sin cambios |
| Backend hermano: `app/Http/Controladores/ProveedorControlador.php` | No | Liberaciones operativas | Auditoría de generación de eventos y normalización de estados | Lectura del código local | Causa identificada |

## Respuestas a la auditoría obligatoria

### 1. ¿Por qué aparecían cuatro eventos de liberación operativa?

El guardado de una liberación en `ProveedorControlador` ejecuta `$operation->timeline()->create(...)` con el mismo título en cada actualización. No exige que haya cambiado el estado. El endpoint de seguimiento devuelve esos registros mediante la relación de la operación, ordenada por fecha descendente.

Flutter reemplazaba `_tracking` al refrescar; no agregaba los resultados a una lista acumulativa ni creaba eventos al reconstruir. Los cuatro horarios distintos de la captura son compatibles con cuatro guardados de liberación. No son una evidencia de cuatro hitos diferentes ni de despegues.

Límite de la comprobación: se revisaron el código local y la captura, no los IDs originales de esas cuatro filas en una base de datos o respuesta del servidor. La captura no contiene IDs y el DTO anterior los descartaba. No se afirma haber verificado retrospectivamente los cuatro IDs ni haber distinguido reintentos de acciones humanas en esos registros concretos.

Ahora el DTO conserva los identificadores. Solo se omiten copias con el mismo ID y el mismo contenido recibido; si el ID es distinto, falta el ID o el contenido difiere, el registro permanece. Igualdad de título nunca elimina un evento. No se borró ningún registro del backend.

### 2. ¿Qué significa `operational_ready`?

En el código de liberaciones significa preparación/liberación operativa: se mapea a operación `confirmada` y a evento `lista` cuando ese es el estado normalizado de la liberación. No constituye evidencia de despegue.

La presentación usa «Listo para operar». Solo comunica que existe una liberación confirmada cuando el evento real de liberación contiene `Estado: operational_ready`. Una liberación histórica no convierte un estado general desconocido o pendiente en listo.

### 3. ¿Qué significa `tracking_live`?

Es una etapa de workflow de seguimiento operativo habilitado. La aplicación la define como «En operación», e incluye actividades previas como briefing o abordaje. Por sí sola no confirma que el avión esté en el aire.

El backend de liberaciones, sin embargo, la transforma en `en_vuelo` y también puede asignar `started_at` por ese workflow. Por eso incluso `en_vuelo` puede proceder de una liberación y ser ambiguo en este flujo.

La nueva presentación distingue «Seguimiento operativo activo», «Listo para operar» y un vuelo explícitamente reportado en curso. Un evento independiente de vuelo puede corroborar el valor ambiguo; un evento de liberación no se utiliza como prueba de despegue. No se afirma que estos eventos sean una posición GPS.

### 4. ¿Por qué se mostraba «Tu vuelo está en curso»?

`ClientTrackingStatus.fromValue` convertía directamente `en_vuelo` en ese título. El valor podía haber sido generado por el mapeo de `tracking_live` durante el guardado de una liberación. La interfaz interpretaba esa normalización como inicio de vuelo.

La portada ahora considera el origen del evento y usa una descripción prudente cuando no hay evidencia independiente.

### 5. ¿Por qué los eventos mostraban «Pendiente»?

El traductor anterior de eventos reconocía `in_flight`, pero no `en_vuelo`, `lista` ni `confirmada`. Los valores no reconocidos caían en «Pendiente», aunque ese no fuera el estado semántico del evento.

La nueva capa distingue un estado explícitamente pendiente de un código desconocido («Estado por confirmar»). Los campos técnicos de la descripción se traducen para el cliente y la etiqueta aclara que corresponde a la actualización, no necesariamente al estado general de la operación.

### 6. ¿Se modificó algún contrato del backend?

No. No se editaron endpoints, controladores, autenticación, autorizaciones, base de datos, modelos de persistencia ni claves del backend. El DTO de Flutter únicamente conserva metadatos que la API ya entrega. Se mantuvo la comprobación de propiedad del endpoint.

Si el servidor devuelve otra operación, la pantalla rechaza la respuesta. Si devuelve 401, 403 o 404, retira el contenido previamente visible; un error transitorio conserva el último contenido válido y ofrece reintentar.

### 7. ¿Se conservaron todos los eventos legítimos?

Sí. Las pruebas conservan IDs distintos con títulos iguales, registros sin ID y registros con contenido distinto aunque compartan ID. Se filtran eventos cuyo `operation_id` explícito pertenece a otra operación. Solo las copias identificadas e idénticas se deduplican en presentación.

Los eventos se ordenan por fecha descendente. Los que no tienen fecha se conservan sin inventar una, al final y en su orden de recepción.

### 8. ¿Se mantuvo la navegación desde Reservas?

Sí. Se conserva `resolveClientTrackingOperationId`, la condición de disponibilidad y `MaterialPageRoute`. La prueba de navegación real abre una reserva distinta del próximo vuelo destacado y verifica su operation ID, origen, destino, pasajeros y aeronave. También verifica el regreso a la lista.

El endpoint de seguimiento no proporciona ruta, pasajeros ni foto. Esos datos se presentan desde la fila seleccionada, vinculada al mismo ID de operación. Si no están disponibles, se muestran faltantes; no se consulta ni se reutiliza otro vuelo. Si la liberación más reciente identifica una aeronave diferente de la foto de la reserva, se muestra el nombre de esa liberación y se omite la fotografía anterior.

## Ciclo de vida y rendimiento

Se mantiene la consulta inicial, el refresco manual, el retorno al primer plano y el intervalo existente de 20 segundos. Se conserva la protección frente a consultas simultáneas, respuestas obsoletas y widgets desmontados. Los timers se cancelan al salir y para estados terminales; al cambiar de operación se restablece el polling correspondiente. No se agregaron suscripciones ni consultas de imágenes durante cada build.

El timeline utiliza construcción diferida. Las pruebas recorren un historial de 100 eventos y verifican que no se construyan todos simultáneamente. El itinerario completo de una operación con varios tramos puede consultarse en el resumen desplegable.

La pantalla acepta una respuesta únicamente cuando su `operation.id` coincide exactamente con el ID solicitado; una respuesta sin ID también se rechaza. Si la pantalla se abre sin una operación identificable, no mantiene el polling periódico activo.

## Validación técnica

- `dart format` ejecutado sobre los diez archivos Dart del cambio.
- `flutter test`: **295 pruebas correctas y 1 omitida**. La prueba nativa de `integration_test/` se ejecuta por separado.
- `flutter analyze`: únicamente las dos advertencias preexistentes en `lib/core/app_theme.dart:1`, relacionadas con el import de `CupertinoPageTransitionsBuilder`. Sin incidencias nuevas.
- `git diff --check`: correcto.
- `flutter test integration_test/operational_tracking_presentation_test.dart -d 1971D3C6-F654-4200-9199-35CCF54C68B0`: correcto en el simulador iPhone 17 Pro.
- `flutter test integration_test/operational_tracking_presentation_test.dart -d emulator-5554`: correcto en el emulador Android.
- Anchos 320, 360, 375, 390 y 430 px; escalas de texto 1 y 2; temas iOS y Android; insets superior/inferior de 59/34 px. Sin desbordamientos en el scroll.
- Se verificaron estado confirmado, liberación sin despegue, seguimiento habilitado, vuelo explícito, finalizado, cancelado, estado desconocido, lista vacía, datos parciales, error inicial/transitorio, denegación de acceso, respuestas de otra operación o sin ID y cambios de operación sin consultas superpuestas.
- No se modificaron cotización, precios, pagos, Stripe, creación de solicitudes, cancelaciones ni los rediseños anteriores.

## Evidencia visual

Se capturó la versión anterior del simulador iPhone en [before.png](before.png). El proceso activo no aplicó la recarga; no se presenta esa imagen como resultado final.

El usuario indicó **continuar sin captura final** cuando se solicitó reabrir el seguimiento actualizado. Por ello no se adjunta una captura final del simulador. La nueva validación nativa iOS/Android se ejecutó en ambos destinos indicados arriba.
