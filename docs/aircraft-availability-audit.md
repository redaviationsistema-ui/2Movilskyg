# Aircraft Availability Audit

Esta batería agrega una ruta de auditoría real contra backend sin hardcodear aeropuertos, aeronaves, cotizaciones o reservas dentro de Flutter.

## Qué cubre

- lectura de aeropuertos reales por API
- cotización real con `ReservationProvider`
- preservación real de `is_available`, `availability_status` y `availability_reason`
- creación real de solicitud cuando la escritura está habilitada
- conflicto real `409` con `AIRCRAFT_NOT_AVAILABLE` o `AIRCRAFT_ALREADY_RESERVED`
- conflicto real durante contrato
- concurrencia real entre dos clientes si el backend expone el escenario

## Qué no hace por sí solo

- no siembra datos en backend
- no inventa aeropuertos ni aeronaves en Flutter
- no altera el código de producción

Los escenarios de conflicto y concurrencia dependen de datos preparados por backend o por el ambiente de QA.

## Requisitos

- backend accesible desde el dispositivo/simulador
- cuenta cliente real para lectura
- cuenta cliente real para escritura si se desea crear solicitud
- dos cuentas cliente si se desea validar concurrencia real
- escenarios sembrados en backend para conflicto de solicitud y conflicto de contrato

## Variables por `--dart-define`

Obligatorias para lectura:

- `AUDIT_API_BASE_URL`
- `AUDIT_CLIENT_EMAIL`
- `AUDIT_CLIENT_PASSWORD`

Opcionales para ruta principal:

- `AUDIT_ORIGIN_ICAO`
- `AUDIT_DESTINATION_ICAO`
- `AUDIT_DEPARTURE_ISO`
- `AUDIT_PASSENGERS`

Opcionales para escritura:

- `AUDIT_ALLOW_WRITES=true`

Opcionales para conflicto real en creación:

- `AUDIT_CONFLICT_ORIGIN_ICAO`
- `AUDIT_CONFLICT_DESTINATION_ICAO`
- `AUDIT_CONFLICT_DEPARTURE_ISO`
- `AUDIT_EXPECTED_CONFLICT_CODE`

Opcionales para conflicto real en contrato:

- `AUDIT_CONTRACT_RESERVATION_ID`
- `AUDIT_CONTRACT_FLIGHT_REQUEST_ID`
- `AUDIT_CONTRACT_ENTITY_ID`
- `AUDIT_EXPECTED_CONTRACT_CONFLICT_CODE`

Opcionales para concurrencia real:

- `AUDIT_SECOND_CLIENT_EMAIL`
- `AUDIT_SECOND_CLIENT_PASSWORD`

## Ejecución

Solo lectura real:

```bash
flutter test integration_test/aircraft_availability_real_backend_test.dart \
  --dart-define=AUDIT_API_BASE_URL=https://tu-backend/api/v1 \
  --dart-define=AUDIT_CLIENT_EMAIL=cliente1@example.com \
  --dart-define=AUDIT_CLIENT_PASSWORD=secreto \
  --dart-define=AUDIT_DEPARTURE_ISO=2026-08-19T10:00:00
```

Lectura + creación real:

```bash
flutter test integration_test/aircraft_availability_real_backend_test.dart \
  --dart-define=AUDIT_API_BASE_URL=https://tu-backend/api/v1 \
  --dart-define=AUDIT_CLIENT_EMAIL=cliente1@example.com \
  --dart-define=AUDIT_CLIENT_PASSWORD=secreto \
  --dart-define=AUDIT_ALLOW_WRITES=true \
  --dart-define=AUDIT_DEPARTURE_ISO=2026-08-19T10:00:00
```

Conflicto real en creación:

```bash
flutter test integration_test/aircraft_availability_real_backend_test.dart \
  --dart-define=AUDIT_API_BASE_URL=https://tu-backend/api/v1 \
  --dart-define=AUDIT_CLIENT_EMAIL=cliente1@example.com \
  --dart-define=AUDIT_CLIENT_PASSWORD=secreto \
  --dart-define=AUDIT_ALLOW_WRITES=true \
  --dart-define=AUDIT_CONFLICT_ORIGIN_ICAO=ORIGEN_DESDE_BACKEND \
  --dart-define=AUDIT_CONFLICT_DESTINATION_ICAO=DESTINO_DESDE_BACKEND \
  --dart-define=AUDIT_CONFLICT_DEPARTURE_ISO=2026-08-20T10:00:00 \
  --dart-define=AUDIT_EXPECTED_CONFLICT_CODE=AIRCRAFT_NOT_AVAILABLE
```

Conflicto real en contrato:

```bash
flutter test integration_test/aircraft_availability_real_backend_test.dart \
  --dart-define=AUDIT_API_BASE_URL=https://tu-backend/api/v1 \
  --dart-define=AUDIT_CLIENT_EMAIL=cliente1@example.com \
  --dart-define=AUDIT_CLIENT_PASSWORD=secreto \
  --dart-define=AUDIT_CONTRACT_RESERVATION_ID=desde_backend \
  --dart-define=AUDIT_CONTRACT_FLIGHT_REQUEST_ID=desde_backend \
  --dart-define=AUDIT_CONTRACT_ENTITY_ID=desde_backend \
  --dart-define=AUDIT_EXPECTED_CONTRACT_CONFLICT_CODE=AIRCRAFT_ALREADY_RESERVED
```

Concurrencia real:

```bash
flutter test integration_test/aircraft_availability_real_backend_test.dart \
  --dart-define=AUDIT_API_BASE_URL=https://tu-backend/api/v1 \
  --dart-define=AUDIT_CLIENT_EMAIL=cliente1@example.com \
  --dart-define=AUDIT_CLIENT_PASSWORD=secreto \
  --dart-define=AUDIT_SECOND_CLIENT_EMAIL=cliente2@example.com \
  --dart-define=AUDIT_SECOND_CLIENT_PASSWORD=secreto2 \
  --dart-define=AUDIT_ALLOW_WRITES=true \
  --dart-define=AUDIT_CONFLICT_ORIGIN_ICAO=ORIGEN_DESDE_BACKEND \
  --dart-define=AUDIT_CONFLICT_DESTINATION_ICAO=DESTINO_DESDE_BACKEND \
  --dart-define=AUDIT_CONFLICT_DEPARTURE_ISO=2026-08-20T10:00:00 \
  --dart-define=AUDIT_EXPECTED_CONFLICT_CODE=AIRCRAFT_NOT_AVAILABLE
```

## Criterio de interpretación

- Si faltan `dart-defines`, los casos correspondientes quedan `skip`.
- Si el backend no devuelve el escenario sembrado esperado, la prueba falla.
- Si la prueba pasa, el flujo se validó con datos reales del backend y no con fixtures manuales dentro de Flutter.
