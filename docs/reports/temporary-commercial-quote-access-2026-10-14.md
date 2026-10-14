CUANDO ESTE LISTO SE PODRA ACTIVAR Y PODER PAGAR 
# Temporary commercial quote access — 2026-10-14

This change temporarily removes subscription eligibility as a prerequisite for
generating a quote. It does not enable flight-request creation, reservations,
contracts, or flight payments.

## Flutter audit and change

| File / location | Finding | Change / status |
| --- | --- | --- |
| `lib/core/acceso_comercial_cliente.dart:3-5,55-63` | `CommercialAccessState.canQuote` combined the backend `can_quote` value, expiration, paid access, and free-quote balance. `canReserve` is a separate decision. | Added `temporaryCommercialQuoteAccessOverride`. It affects `canQuote` only; the original decision remains as the fallback expression and `canReserve` is unchanged. |
| `lib/screens/reservation/widgets/contenido_pantalla_reservacion.dart:83-89,108-143,614-718` | The expired-access state replaced the quote form with `_CommercialAccessBanner`, including its reactivation button. | The temporary override allows the existing quote form to render. The original banner and button implementation remain in place for restoration and are not rendered in this quote flow while the override is enabled. No replacement banner or spacer was added. |
| `lib/screens/reservation/pantalla_reservacion.dart:188-210,260-305` | `_performQuoteRequest` refreshes commercial status and calls `_blockQuoteIfAccessExpired` before quoting and after a failed preview. | The status refresh and guard remain. The guard sees the temporary `canQuote` result and therefore does not block an otherwise valid quote. Route/date/multicity validation and `previewCurrentSelection()` remain unchanged. |
| `lib/providers/proveedor_autenticacion.dart:429-440`; `lib/core/cliente_api.dart:1125-1129` | `AuthProvider.refreshCommercialAccessStatus()` fetches and stores the existing access snapshot through `getClientAccessStatus()`. | Left unchanged; the status remains available to other screens and workflows. |
| `lib/screens/cliente/views/pantalla_resultados_cliente.dart:51-52,183-214`; `lib/core/acceso_comercial_cliente.dart:65-69` | Creating a flight request is gated by `canReserve`, separately from quote eligibility. | Left unchanged. An expired client can generate a quote but still cannot create a request unless the existing reservation rules allow it. |

The identifier `TEMPORAL: ACCESO COMERCIAL DESACTIVADO — 2026-10-14` is
present beside the temporary Flutter changes. The original commercial-state
logic was retained behind the override instead of commenting out code needed
to compile and serve other screens.

## Laravel audit and change

| File / location | Finding | Change / status |
| --- | --- | --- |
| `routes/api_v1_red_aviation.php:24-28`; `app/Http/Controladores/RedAviation/ClienteControlador.php:319-338,1335-1339` | `POST /api/v1/client/quotes/preview` reaches `ClienteControlador::previewQuotes()` outside the `auth.token` group. It resolves an optional user; anonymous requests already reached validation and quote generation before this change. For authenticated clients, the method checked commercial eligibility and could return HTTP 402. | Only that 402 denial was commented and marked `TEMPORAL: ACCESO COMERCIAL DESACTIVADO — 2026-10-14`. Input validation and quote calculation remain active. Authentication was already optional for this route and was not changed; this change does not add or remove authentication. |
| `app/Http/Controladores/RedAviation/ClienteControlador.php:419-431` | Trial previews update `free_quotes_used` and trial status. | Left active. Previews that qualify for an existing trial still update its count. The temporary bypass does not consume additional trial balance for clients whose trial is exhausted. |
| `app/Http/Controladores/RedAviation/ClienteControlador.php:847-860,1292-1327`; `routes/api_v1_red_aviation.php:39,53` | `storeFlightRequest()` uses the shared commercial gate for flight-request creation. The route retains client/admin authentication and role middleware. | Left unchanged. |
| `routes/api_v1_cliente.php:50`; `app/Http/Intermediarios/AsegurarAccesoPremium.php:11-24` | Reservation creation remains behind the `premium` middleware. | Left unchanged. |
| `app/Http/Controladores/RedAviation/CotizacionControlador.php:50-65`; `FlightMembershipControlador.php:81-87`; `app/Services/FlightMembershipService.php:324-338` | Membership checks for saved-quote previews determine membership-benefit estimates, not access to base quote generation. | Left unchanged. |

No pricing, quote calculations, quote persistence, API contract, migrations, or
database data were changed. Trial quota accounting remains active. No deployment
was performed.

## Preserved controls

- Existing Flutter authentication and navigation shells.
- The separate reservation eligibility (`canReserve`) and flight-request gate.
- Request, contract, reservation, ownership, payment, Stripe, and operational
  checks.
- Laravel request validation, quote calculation, and trial accounting.
- Existing route middleware and optional-token behavior. In particular, anonymous
  preview access predated this change and remains unchanged; this task did not
  introduce or expand it.

## Restoration

1. In Flutter, set `temporaryCommercialQuoteAccessOverride` to `false` in
   `lib/core/acceso_comercial_cliente.dart`. The original `canQuote` and form
   eligibility expressions then take effect again.
2. In Laravel, restore the commented HTTP 402 denial in
   `ClienteControlador::previewQuotes()` and remove the temporary marker.
3. Re-run the focused Flutter and Laravel tests listed below.

## Verification

- `flutter test test/core/acceso_comercial_cliente_test.dart test/screens/reservation/reservation_screen_content_test.dart` — passed (7 tests).
- `flutter test` — passed (297 tests, 1 skipped).
- `flutter analyze` — no errors; two pre-existing warnings remain in
  `lib/core/app_theme.dart` (unused Cupertino import and undefined shown name).
- `php artisan test --filter=QuotePreviewAvailabilityBatchTest` — passed (4
  tests, 23 assertions).
- PHP syntax checks and `git diff --check` — passed.
- Device-level navigation was not performed. The application requires an
  authenticated session to reach the cotizador; widget and endpoint tests were
  used instead. No production deploy or real flight request was made.









-----------------------------------------------------------------------------------

# RESTAURAR SISTEMA DE ACCESO COMERCIAL — FLUTTER Y LARAVEL

## OBJETIVO

Restaurar completamente el funcionamiento original del acceso comercial que fue desactivado temporalmente el 14 de octubre de 2026.

Cuando el acceso comercial del cliente esté vencido, debe volver a restringirse la cotización y mostrarse el aviso correspondiente con la opción de reactivación.

No modificar las fórmulas, tarifas ni cálculos del cotizador.

## 1. UBICACIÓN DE LOS PROYECTOS

**FLUTTER**

`/Users/redaviation/Documents/SKYGRUP/UBERAVIONES/2Movilskyg`

**LARAVEL**

`/Users/redaviation/Documents/SKYGRUP/UBERAVIONES/BACKEND UBER AVIONES`

## 2. RESTAURAR FLUTTER

Abrir:

`lib/core/acceso_comercial_cliente.dart`

Localizar:

`temporaryCommercialQuoteAccessOverride`

Cambiar su valor de `true` a `false`.

Verificar que `CommercialAccessState.canQuote` vuelva a utilizar las reglas comerciales originales:

- Acceso comercial activo.
- Acceso comercial vencido.
- Suscripción pendiente de pago.
- Cotizaciones gratuitas disponibles.
- Límites de prueba agotados.

No modificar `canReserve` ni las autorizaciones de otras operaciones.

## 3. RESTAURAR BACKEND LARAVEL

Abrir:

`app/Http/Controladores/RedAviation/ClienteControlador.php`

Localizar el método:

`previewQuotes()`

Buscar el bloque comentado con el marcador:

`TEMPORAL: ACCESO COMERCIAL DESACTIVADO — 2026-10-14`

Restaurar la validación original que responde con HTTP 402 cuando el cliente autenticado no cumple con los requisitos comerciales para cotizar.

No reconstruir ni inventar una validación diferente.

Recuperar exactamente el comportamiento original documentado en el código.

Mantener la autenticación, permisos, validaciones y controles de seguridad existentes.

## 4. RESTAURAR EL AVISO VISUAL

Revisar:

`lib/screens/reservation/widgets/contenido_pantalla_reservacion.dart`

Y:

`lib/screens/cliente/pantalla_espacio_movil_cliente.dart`

Restaurar cualquier widget que haya sido comentado temporalmente para ocultar el aviso comercial.

El cliente con acceso vencido debe visualizar:

"Acceso comercial vencido"

Y el botón:

"Reactivar acceso comercial"

El cliente con acceso activo no debe visualizar avisos de vencimiento incorrectos.

## 5. CONSERVAR TODOS LOS CÁLCULOS

No modificar:

- Solo ida.
- Ida y vuelta.
- Multidestino.
- Precios de aeronaves.
- Velocidades Mach.
- Horas mínimas.
- Ascenso y descenso.
- Reposicionamiento.
- Pernoctas.
- Impuestos.
- Generación de cotizaciones.
- Stripe.
- Contratos.
- Reservas.

## 6. PRUEBAS

Verificar los siguientes escenarios:

1. Cliente con suscripción activa: puede cotizar.
2. Cliente con suscripción vencida y sin cotizaciones gratuitas: queda bloqueado.
3. Cliente con prueba gratuita disponible: conserva el permiso que establecen las reglas originales.
4. Cliente sin saldo de prueba y sin acceso pagado: recibe el bloqueo original.
5. Aparece la opción de reactivación cuando corresponde.
6. No se modifican cálculos ni precios.
7. Reservas, contratos y pagos conservan sus permisos originales.

Actualizar las pruebas que se modificaron durante la desactivación temporal.

Ejecutar:

- `flutter analyze`
- `flutter test`
- `php artisan test --filter=QuotePreviewAvailabilityBatchTest`

## 7. DOCUMENTACIÓN

Consultar el informe:

`docs/reports/temporary-commercial-quote-access-2026-10-14.md`

Identificar todos los cambios realizados durante la desactivación temporal.

Revertir exclusivamente esos cambios.

No utilizar `git reset --hard` ni restaurar archivos completos que puedan contener otras modificaciones importantes.

Entregar una tabla con:

| Proyecto | Archivo | Línea | Cambio restaurado | Resultado |
|---|---|---|---|---|

Confirmar que el acceso comercial funciona exactamente como antes de la desactivación.

No modificar la base de datos.

No ejecutar migraciones.

No realizar deploy a producción.

## RESULTADO ESPERADO

El acceso comercial vuelve a estar activo como mecanismo de autorización.

Los clientes con acceso vencido quedan sujetos nuevamente a la reactivación comercial para cotizar, respetando cualquier prueba gratuita permitida por las reglas originales.

El código y las funcionalidades ajenas a este cambio permanecen intactos.