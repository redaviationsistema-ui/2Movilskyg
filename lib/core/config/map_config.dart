import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class MapProviderConfig {
  const MapProviderConfig({
    required this.name,
    required this.tileUrlTemplate,
    required this.vectorStyleUrl,
    required this.attribution,
    required this.documentationUrl,
    required this.isRasterTileLayerCompatible,
    required this.isVectorStyleCompatible,
  });

  final String name;
  final String? tileUrlTemplate;
  final String? vectorStyleUrl;
  final String attribution;
  final String documentationUrl;
  final bool isRasterTileLayerCompatible;
  final bool isVectorStyleCompatible;

  bool get isAvailable =>
      isRasterTileLayerCompatible &&
      tileUrlTemplate != null &&
      tileUrlTemplate!.trim().isNotEmpty;

  bool get isVectorAvailable =>
      isVectorStyleCompatible &&
      vectorStyleUrl != null &&
      vectorStyleUrl!.trim().isNotEmpty;
}

class MapConfig {
  const MapConfig._();

  static const Color routeColor = Color(0xFFE53935);
  static const Color markerColor = Color(0xFFD6B477);
  static const Color fallbackBackgroundColor = Color(0xFF071321);
  static const Color surfaceColor = Color(0xFF101C2D);
  static const Color attributionBackgroundColor = Color(0xE6FFFFFF);
  static const Color attributionTextColor = Color(0xFF1B2430);

  static const double initialZoom = 4.6;
  static const double minZoom = 2;
  static const double maxZoom = 21;
  static const double maxFitZoom = 12;
  static const double routeStrokeWidth = 4;
  static const double fallbackMapHeight = 236;
  static const EdgeInsets mapPadding = EdgeInsets.all(14);
  static const EdgeInsets cameraFitPadding = EdgeInsets.all(42);
  static const BorderRadius borderRadius = BorderRadius.all(
    Radius.circular(18),
  );

  static const LatLng initialCenter = LatLng(23.6345, -102.5528);

  static const String openStreetMapAttribution = 'OpenStreetMap contributors';

  static const MapProviderConfig provider = MapProviderConfig(
    name: 'OpenFreeMap',
    tileUrlTemplate: null,
    vectorStyleUrl: 'https://tiles.openfreemap.org/styles/liberty',
    attribution: 'OpenFreeMap, OpenMapTiles, OpenStreetMap contributors',
    documentationUrl: 'https://openfreemap.org/',
    isRasterTileLayerCompatible: false,
    isVectorStyleCompatible: true,
  );

  static const String unavailableMessage =
      'Mapa no disponible. Revisa tu conexion e intenta nuevamente.';
  static const String loadingMessage = 'Cargando mapa...';
  static const String illustrativeRouteNotice =
      'Recorrido ilustrativo. No representa una ruta aérea autorizada.';
}
