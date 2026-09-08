# Auditoría de orden en “Mi vuelo” — 2026-09-07

## Conclusión y alcance

**PUEDE MOVER LOS CAMPOS.** Se reprodujo una variación del orden al actualizar un pendiente usando la relación Eloquent y el serializador reales sobre SQLite en memoria. Flutter no ordena por estado: reproduce el orden del GET, agrupado por categoría. El GET no establece ORDER BY. Por tanto, **NO es correcto garantizar “NO MUEVE LOS CAMPOS”**.

Esto confirma el defecto de garantía de orden en el código local, no el comportamiento observado de una operación concreta del servidor desplegado. No se ejecutaron PUT/GET autenticados contra un vuelo real, no se inspeccionó la base desplegada ni se hizo una prueba visual en dispositivo. Las pruebas aquí distinguen explícitamente código, fixtures y tráfico real pendiente. No se modificaron reglas de orden ni comportamiento operativo; solo logs temporales de diagnóstico.

## Flujo completo

1. `lib/screens/sobrecargo/pantalla_espacio_sobrecargo.dart` incluye como `part` `operacion_sobrecargo.dart`. La vista es `CrewOperationView`, no la lista de vuelos del cliente abierta en el IDE.
2. `CrewAssignment`, en `modelos_sobrecargo.dart`, aporta `resolvedOperationId`. Aunque contiene checklists del listado, la vista consulta de nuevo el workflow.
3. `ApiClient.getCrewOperationWorkflow`, `lib/core/cliente_api.dart`: GET `/api/v1/sobrecargo/operations/{operation}/workflow` (prefijo según base URL configurada).
4. Ruta en `../BACKEND UBER AVIONES/routes/api_v1_red_aviation.php`; controlador `app/Http/Controladores/RedAviation/SobrecargoControlador.php::workflow`.
5. `app/Servicios/Sobrecargo/CrewOperationWorkflowService.php::loadOperationWorkflow` carga `checklists.items` sin ordenar. `buildWorkflowPayload` y `serializeChecklist` usan `map(...)->values()`, preservando el orden de la relación.
6. Modelos `app/Modelos/Operacion.php::checklists`, `ChecklistOperacion.php::items` y `ChecklistItem.php`. Ninguna de estas relaciones declara un orden.
7. Flutter `_load` desenvuelve `data` y reemplaza `_workflow` mediante `setState`. No existe DTO tipado ni provider específico para ordenar estos items; son `Map<String, dynamic>`. `_list` filtra entradas que no son mapas y copia las restantes conservando su secuencia.
8. `_checklistsOfType` filtra por tipo normalizado. `_mergedChecklistOfType` concatena items de todos los checklists coincidentes. No deduplica ni ordena.
9. `_groupedChecklist` agrupa por `category`, con fallback `group`, usando un mapa por inserción. El orden de las secciones es el de la primera aparición de cada categoría; el de sus items es el del payload.
10. `_friendlyChecklistCategory`: `service` → Servicio; `operation` → Información del vuelo; `passengers` → Pasajeros; también `personal`, `logistics`, `cabin`, `safety`. No existe entidad section con `section_id` en este payload.
11. `_checklistStep` renderiza `_groupedChecklist(checklist).map(...)`; `_checklistGroupCard` renderiza `items.map(...)`; `_checklistItemCard` muestra estado y detalle.

## Origen y campos reales

Las plantillas están en `SobrecargoControlador::checklistTemplates`; `ensureOperationChecklist` crea tipos/items faltantes. Tipos: `preparation`, `preflight`, `postflight`. Al crearlos usa la secuencia de la plantilla y luego lee items por `id`. En postflight, la plantilla declara Catering sobrante **antes** de Faltantes. El orden inicial indicado por el usuario no es el orden de inserción normal de esa plantilla.

| Campo | Base/modelo | Payload de item |
|---|---|---|
| `id` | Sí, identidad | Sí |
| `checklist_id` | Sí, FK | No; se obtiene del checklist padre `id` |
| `checklist_item_id` | Referencia en auditoría/eventos | No, aquí se llama `id` |
| `section_id`, `step_id` | No en item | No; categoría y fase derivada del tipo |
| `code`, `category`, `label` | Sí | Sí |
| `description` | Derivado de label | Sí |
| `status`, `is_completed` | Sí | Sí |
| `is_required`, `is_critical`, `notes`, `evidence_files` | Sí | Sí |
| `completed_at` | Sí | Sí |
| `completed_by` | Sí | No |
| `created_at`, `updated_at` | Timestamps Eloquent | No |
| `order`, `position`, `sort_order`, `sequence`, `display_order` | No en migraciones/modelo de estos items | No |

El checklist padre serializa `id`, `type`, `status`, `submitted_at`, `items`.

## Ordenamiento y actualización

PUT `/api/v1/sobrecargo/operations/{operation}/checklists/{type}/items/{item}`.

Flutter envía exclusivamente `status` y `notes`. `SobrecargoControlador::updateChecklistItem` actualiza `status`, `notes`, `is_completed`, `completed_at`, `completed_by`; Eloquent también actualiza `updated_at`. No cambia `id`, `checklist_id`, `category`, `code`, `created_at` ni un campo de orden. Puede completar el checklist padre, cambiar `crew_status` y agregar un evento de timeline.

**La respuesta PUT sí tiene `orderBy('id')`. El GET workflow posterior NO.** Flutter descartaba el contenido de la respuesta PUT y ejecuta `await _load()`. Los logs ahora lo inspeccionan, pero sigue usando exclusivamente el GET para el estado visible. No hay modificación optimista del item local.

No se encontró `sort`, `sorted`, `compareTo`, concatenación de pendientes/completados ni filtrado por estado de los items renderizados. Los `where` por estado calculan contadores/completitud; `firstWhere` elige expansión o fase. En backend, `sortByDesc('id')` selecciona un checklist para cálculos de completitud, y los ordenamientos de timeline/incidentes no ordenan los items de la pantalla. El listado de asignaciones tiene carga por `id`; no es el GET workflow.

La migración `2026_07_18_230000_expand_crew_operational_workflow.php` agrega el índice `(checklist_id, status)`. Una consulta sin ORDER BY puede recorrer ese índice y producir un orden afectado por status. **No existe regla funcional “pendientes primero” ni “completados primero”; tampoco un orden SQL garantizado.** No se encontraron observers registrados para estos modelos ni triggers de checklist en las migraciones revisadas; esto no inspecciona posibles triggers externos del servidor.

## Casos ejecutados y evidencia

`helpers_order.dart` contiene copias extraídas de los helpers reales; prueba agrupación y secuencia, no monta el widget ni llama HTTP. Casos: Servicio (2), Información del vuelo (2), Cabina (4). Primer item pendiente, restantes completados. Cambia el primero a completed:

| Caso | Antes | Después | Refresh, mismo payload | Refresh, payload invertido |
|---|---|---|---|---|
| Servicio | 1,2 | 1,2 | 1,2 | 2,1 |
| Información del vuelo | 1,2 | 1,2 | 1,2 | 2,1 |
| Cabina | 1,2,3,4 | 1,2,3,4 | 1,2,3,4 | 4,3,2,1 |

**Caso obligatorio en Flutter: A**, siempre que el GET conserve el orden inicial. Faltantes sigue primero y ambos muestran Registrado. No se puede prometer A para el flujo completo con un GET sin orden definido.

`backend_relation.php` usa Eloquent, modelos y serializador GET reales, con tablas mínimas en memoria. Aplica los campos de actualización del controlador, pero **no ejecuta el controlador, middleware ni endpoint HTTP**. Los IDs son sintéticos; `section` en el resultado representa category y no un campo section_id. Ningún fixture contiene position/order porque no existen.

Resultados completos en `backend_with_index.jsonl` y `backend_without_index.jsonl`:

- Sin índice compuesto: Servicio empieza Faltantes pendiente (id 1), Catering completado (id 2). Tras completar: 1,2; tras refresh: 1,2. Resultado A. Información del vuelo y Cabina también conservan orden.
- Con el índice definido en el proyecto: Servicio GET inicial retorna Catering completado (id 2), Faltantes pendiente (id 1). Tras completar Faltantes, GET retorna 1,2; refresh siguiente conserva 1,2. **Cambio efectivo de posición, en sentido inverso al ejemplo B.** No se presenta como una reproducción exacta de B.
- Información del vuelo con índice: antes 4,3; después y refresh 3,4.
- Cabina con índice: antes 6,7,8,5; después y refresh 5,6,7,8.

La consulta real de la relación: `select * from checklist_items where checklist_items.checklist_id = ? and checklist_items.checklist_id is not null`. No hay ORDER BY. El motor/plan/datos desplegados pueden producir otro resultado; el fixture prueba que la implementación admite movimiento, no que siempre ocurra.

## Ocultación, estado local y refresh

Completar no elimina el item ni cambia su categoría. Los grupos solo renderizan sus hijos si están expandidos y el detalle depende de expansión. `_syncSelections` prefiere pendientes para expansión inicial, sin reordenar. `_load` reinicia `_selectedStepId` y `_selectedTrackingId`; la fase activa se recalcula, respetando `initialStepId` cuando corresponde. Al terminar un checklist, `_saveChecklistItem` puede seleccionar la fase actual y desplazar el scroll. Por ello puede desaparecer la lista de una fase y aparecer otra, aunque ningún item haya migrado de sección.

Guardar ya incluye refresh: PUT → GET → reemplazo de `_workflow`. Pull-to-refresh llama `_load`; reabrir crea estado nuevo y `initState` llama `_load`. Los tres usan la misma consulta sin garantía de orden. Si cambia la primera aparición de una categoría en el payload, también puede cambiar la posición de toda la sección. La categoría del item no cambia por completar.

## Logs temporales y validación

Se añadió `_debugChecklistOrder` en `operacion_sobrecargo.dart`, ejecutado dentro de assert (debug). Fases `BEFORE`, `AFTER_PUT`, `GET`, `AFTER`. Registra operación/checklist/tipo, categoría/sección, índice de sección, id/status/completed_at, campos de orden ausentes como null, índice dentro del grupo e índice del payload (base cero). No registra notas, pasajeros ni evidencias.

El GET se registra al abrir/refrescar/guardar; BEFORE y AFTER rodean el guardado normal. El log AFTER_PUT no reemplaza el estado. Si falla GET, `_load` conserva datos previos y AFTER puede mostrar ese estado anterior: debe verificarse que existe un GET exitoso antes de interpretarlo como confirmación del servidor. El flujo alternativo de falla y subida de evidencia también recarga mediante GET, pero no incluye los cuatro marcadores del guardado normal.

Validación: 11 tests de contrato API y workflow aprobados; análisis de los dos archivos Flutter sin incidencias; tres casos de helpers aprobados; seis escenarios de relación/serializador ejecutados (con/sin índice). No equivalen a prueba de render en dispositivo.

Para cerrar la confirmación sobre el vuelo concreto falta capturar BEFORE → AFTER_PUT → GET → AFTER, refrescar y reabrir en una sesión debug autenticada de prueba, con operación identificada y fase editable. No hay una operación de prueba identificada en la solicitud. No se afirma haber observado tráfico real ni cambios de posición en el teléfono.
