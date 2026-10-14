# Catálogo de aeronaves — reporte de implementación

Fecha: 14 de octubre de 2026.

El catálogo utiliza filas abiertas sobre el fondo de la pantalla: fotografía al 40 % del ancho disponible, nombre y especificaciones, valores comerciales sin recuadros, acción textual con flecha y separadores finos. No se modificaron los proveedores ni el motor de cotización.

| Archivo modificado | Componente anterior | Componente actualizado | Funcionalidad conservada | Prueba realizada | Resultado |
| --- | --- | --- | --- | --- | --- |
| `lib/screens/cliente/views/pantalla_resultados_cliente.dart` | `_QuoteMatchCard`, altura fija y borde exterior | `_AircraftCatalogRow`, altura según contenido y separador | Resultados y fotos dinámicos, selección, reposicionamiento, estados | Pruebas de resultados y revisión visual en iPhone 17 Pro | Correcto |
| Mismo archivo | `_AircraftDataBox` | `_AircraftCatalogMetric`, valores sin cajas | Formateadores existentes de precio y tiempo | Precio recibido del backend y conservación de resultados al ordenar | Correcto |
| Mismo archivo | Botón rectangular de ancho completo | Acción textual dorada con flecha y descripción accesible por aeronave | Mismo callback, validación de acceso, carga, creación y navegación | Éxito, error, indisponibilidad y doble pulsación | Correcto |
| Mismo archivo | Encabezado e imagen de respaldo con desbordamientos en tamaños pequeños | Marca flexible e imagen de respaldo ajustada al espacio | Branding, URLs, placeholder y manejo de errores | 320, 360, 375, 390 y 430 px; escalas 1 y 2; temas iOS y Android; scroll | Sin desbordamientos |
| `test/screens/cliente/views/pantalla_resultados_cliente_test.dart` | 9 pruebas de resultados | 11 pruebas, con adaptación y ordenamiento | Pruebas de flujo comercial existentes | `flutter test test/screens/cliente/views/pantalla_resultados_cliente_test.dart` | 11 correctas |
| `docs/reports/aircraft-catalog/iphone-catalog.png` | Sin evidencia visual | Captura del catálogo en el simulador activo | Fotografías y datos visibles de la aplicación | Inspección visual del listado | Filas abiertas, sin cards exteriores |

Validación final:

- `dart format` aplicado a los dos archivos Dart modificados en este trabajo.
- `flutter test`: 273 pruebas correctas, 1 omitida.
- `flutter analyze`: dos advertencias preexistentes en `lib/core/app_theme.dart:1`, relacionadas con el import de `CupertinoPageTransitionsBuilder`. Sin advertencias en los archivos de este rediseño.
- `git diff --check`: correcto.
- iPhone: revisión visual y captura del simulador activo. El intento de conectar con `flutter attach` no estableció conexión; no se ejecutó el flujo comercial manualmente en el simulador.
- Android: adaptación comprobada mediante widget tests con tema Android; no hubo dispositivo Android autorizado para una prueba nativa.

Confirmaciones y límites:

1. Se eliminaron las cards individuales y las cajas de precio y tiempo.
2. Se mantienen los datos dinámicos, las imágenes y los formateadores existentes; no se añadieron resultados ficticios a la aplicación.
3. No se alteraron precios, tiempos ni cálculos. La autonomía conserva el formato recibido porque el campo actual no declara una unidad; no se inventó una.
4. Se conservan los criterios de ordenamiento. La prueba de mejor precio comprueba el orden sin mutar los resultados del proveedor.
5. Favoritos: el corazón ya era decorativo (`IgnorePointer`), sin callback, almacenamiento ni persistencia. Se conserva el icono y se identifica como no disponible. No se puede afirmar que favoritos esté operativo; implementarlo requiere trabajo funcional adicional fuera de este rediseño visual.
6. Crear solicitud mantiene el callback y el flujo original, incluida la prevención de duplicados. Tocar la fila conserva la selección y no crea una solicitud.
7. El motor de cotización, autenticación, Stripe, modelos y base de datos no se modificaron.
8. Recomendación: se conserva el criterio anterior, primer resultado en el orden recibido cuando está activo «Recomendado». No se añadió un algoritmo ni una señal de recomendación ficticia; el distintivo ahora es dorado y no rodea la aeronave.
9. El mapa opcional de resultados continúa retirado por la instrucción anterior del usuario. No se modificaron los mapas de otras pantallas en este trabajo.
10. Los cambios previos del resumen de itinerario y de sus pruebas se conservaron.


