import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/map_config.dart';
import '../../models/aeropuerto.dart';
import '../../models/modelo_ruta.dart';
import 'airport_map_base.dart';
import 'itinerary_map_models.dart';

class ItineraryAirportMap extends StatefulWidget {
  const ItineraryAirportMap({
    super.key,
    required this.routes,
    this.airportCatalog = const [],
    this.height = MapConfig.fallbackMapHeight,
    this.enableVectorProvider = true,
    this.styleLoader,
    this.showControls = false,
  });

  final List<RouteModel> routes;
  final List<Airport> airportCatalog;
  final double height;
  final bool enableVectorProvider;
  final VectorStyleLoader? styleLoader;
  final bool showControls;

  @override
  State<ItineraryAirportMap> createState() => _ItineraryAirportMapState();
}

class _ItineraryAirportMapState extends State<ItineraryAirportMap> {
  final MapController _controller = MapController();
  late final _mapEventSubscription = _controller.mapEventStream.listen((_) {
    _syncZoomFromCamera();
  });
  String _geometrySignature = '';
  String? _inputSignature;
  ItineraryMapData? _cachedData;
  bool _mapReady = false;
  double _currentZoom = MapConfig.initialZoom;

  ItineraryMapData get _data {
    _refreshCachedData();
    return _cachedData!;
  }

  void _refreshCachedData() {
    final signature = _inputGeometrySignature();
    if (_cachedData == null || signature != _inputSignature) {
      _inputSignature = signature;
      _cachedData = ItineraryMapData.fromRoutes(
        widget.routes,
        airportCatalog: widget.airportCatalog,
      );
    }
  }

  @override
  void didUpdateWidget(covariant ItineraryAirportMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshCachedData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitIfNeeded());
  }

  @override
  void dispose() {
    _mapReady = false;
    _mapEventSubscription.cancel();
    super.dispose();
  }

  void _handleMapReady() {
    if (!mounted) return;
    _mapReady = true;
    _currentZoom = _controller.camera.zoom;
    _fitIfNeeded(force: true);
    if (mounted) {
      setState(() => _currentZoom = _controller.camera.zoom);
    }
  }

  String _inputGeometrySignature() {
    String airportSignature(Airport? airport) {
      if (airport == null) return '-';
      return '${airport.id}:${airport.iata}:${airport.icao}:'
          '${airport.lat}:${airport.lng}:${airport.name}:${airport.city}';
    }

    final routesSignature = widget.routes
        .map(
          (route) =>
              '${airportSignature(route.fromAirport)}>'
              '${airportSignature(route.toAirport)}',
        )
        .join('|');
    return '${identityHashCode(widget.airportCatalog)}:'
        '${widget.airportCatalog.length}:$routesSignature';
  }

  void _fitIfNeeded({bool force = false}) {
    if (!_mapReady || !mounted) return;
    final data = _data;
    final signature = _signature(data);
    if (!force && signature == _geometrySignature) return;
    _geometrySignature = signature;
    final points = data.allPositions;
    if (points.isEmpty) return;
    if (points.length == 1) {
      _controller.move(
        points.first,
        8.0.clamp(MapConfig.minZoom, MapConfig.maxZoom),
      );
      _syncZoomFromCamera();
      return;
    }
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: MapConfig.cameraFitPadding,
        maxZoom: MapConfig.maxFitZoom,
      ),
    );
    _syncZoomFromCamera();
  }

  void _zoomBy(double delta) {
    if (!_mapReady || !mounted) return;
    final camera = _controller.camera;
    final nextZoom =
        (camera.zoom + delta)
            .clamp(MapConfig.minZoom, MapConfig.maxZoom)
            .toDouble();
    if (nextZoom == camera.zoom) return;
    if (_controller.move(camera.center, nextZoom) && mounted) {
      setState(() => _currentZoom = _controller.camera.zoom);
    }
  }

  void _syncZoomFromCamera() {
    if (!_mapReady || !mounted) return;
    final zoom = _controller.camera.zoom;
    if (zoom == _currentZoom) return;
    setState(() => _currentZoom = zoom);
  }

  String _signature(ItineraryMapData data) {
    return data.legs
        .map(
          (leg) =>
              '${leg.origin.identity}>${leg.destination.identity}:${leg.origin.position.latitude},${leg.origin.position.longitude}:${leg.destination.position.latitude},${leg.destination.position.longitude}',
        )
        .join('|');
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final overlays = <Widget>[
      if (data.legs.isNotEmpty) _ItineraryPolylineLayer(legs: data.legs),
      if (data.legs.isNotEmpty) _DirectionMarkerLayer(legs: data.legs),
      if (data.airports.isNotEmpty)
        _AirportMarkerLayer(airports: data.airports),
    ];

    return Stack(
      children: [
        AirportMapBase(
          height: widget.height,
          mapController: _controller,
          overlayLayers: overlays,
          enableVectorProvider: widget.enableVectorProvider,
          styleLoader: widget.styleLoader,
          onMapReady: _handleMapReady,
        ),
        if (data.invalidLegCount > 0)
          Positioned(
            left: 10,
            top: 10,
            child: _MapWarningPill(
              label:
                  '${data.invalidLegCount} tramo${data.invalidLegCount == 1 ? '' : 's'} sin coordenadas',
            ),
          ),
        if (widget.showControls)
          Positioned(
            top: 10,
            right: 10,
            child: _MapControlDock(
              mapReady: _mapReady,
              zoom: _currentZoom,
              horizontal: widget.height < 260,
              onZoomIn: () => _zoomBy(1),
              onZoomOut: () => _zoomBy(-1),
              onCenter: () => _fitIfNeeded(force: true),
            ),
          ),
        if (!data.hasGeometry)
          const Positioned.fill(child: _IncompleteItineraryOverlay()),
      ],
    );
  }
}

class _MapControlDock extends StatelessWidget {
  const _MapControlDock({
    required this.mapReady,
    required this.zoom,
    required this.horizontal,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onCenter,
  });

  final bool mapReady;
  final double zoom;
  final bool horizontal;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onCenter;

  @override
  Widget build(BuildContext context) {
    final controls = [
      _MapControlButton(
        key: const ValueKey('map-zoom-in'),
        tooltip: 'Acercar mapa',
        icon: Icons.add_rounded,
        onPressed: mapReady && zoom < MapConfig.maxZoom ? onZoomIn : null,
      ),
      _MapControlButton(
        key: const ValueKey('map-zoom-out'),
        tooltip: 'Alejar mapa',
        icon: Icons.remove_rounded,
        onPressed: mapReady && zoom > MapConfig.minZoom ? onZoomOut : null,
      ),
      _MapControlButton(
        key: const ValueKey('map-center-route'),
        tooltip: 'Centrar recorrido',
        icon: Icons.my_location_rounded,
        onPressed: mapReady ? onCenter : null,
      ),
    ];

    return Semantics(
      container: true,
      label: 'Controles del mapa',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF20B1726),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .16)),
        ),
        child:
            horizontal
                ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    controls[0],
                    const _MapControlSeparator(vertical: true),
                    controls[1],
                    const _MapControlSeparator(vertical: true),
                    controls[2],
                  ],
                )
                : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    controls[0],
                    const _MapControlSeparator(vertical: false),
                    controls[1],
                    const _MapControlSeparator(vertical: false),
                    controls[2],
                  ],
                ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        color: Colors.white,
        disabledColor: Colors.white38,
        icon: Icon(icon, size: 21),
      ),
    );
  }
}

class _MapControlSeparator extends StatelessWidget {
  const _MapControlSeparator({required this.vertical});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: vertical ? 1 : 0,
      height: vertical ? 0 : 1,
      child:
          vertical
              ? VerticalDivider(
                width: 1,
                thickness: 1,
                indent: 8,
                endIndent: 8,
                color: Colors.white.withValues(alpha: .14),
              )
              : Divider(
                height: 1,
                thickness: 1,
                indent: 8,
                endIndent: 8,
                color: Colors.white.withValues(alpha: .14),
              ),
    );
  }
}

class _IncompleteItineraryOverlay extends StatelessWidget {
  const _IncompleteItineraryOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF071321).withValues(alpha: .84),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Selecciona tus aeropuertos para visualizar el recorrido.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFFFF8E7),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItineraryPolylineLayer extends StatelessWidget {
  const _ItineraryPolylineLayer({required this.legs});

  final List<ItineraryMapLeg> legs;

  @override
  Widget build(BuildContext context) {
    return PolylineLayer(
      polylines:
          legs
              .map(
                (leg) => Polyline(
                  points: leg.points,
                  strokeWidth:
                      leg.isReverseDuplicate ? 4.8 : MapConfig.routeStrokeWidth,
                  color: MapConfig.routeColor.withValues(alpha: .9),
                  borderStrokeWidth: 1.2,
                  borderColor: Colors.white.withValues(alpha: .68),
                ),
              )
              .toList(),
    );
  }
}

class _AirportMarkerLayer extends StatelessWidget {
  const _AirportMarkerLayer({required this.airports});

  final List<ItineraryAirportPoint> airports;

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers:
          airports
              .map(
                (airport) => Marker(
                  point: airport.position,
                  width: 76,
                  height: 44,
                  child: Tooltip(
                    message: airport.label,
                    child: Container(
                      key: ValueKey('airport-marker-${airport.identity}'),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF101C2D).withValues(alpha: .94),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: MapConfig.markerColor,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .24),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: MapConfig.markerColor,
                            size: 15,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              airport.code,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFFFF8E7),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _DirectionMarkerLayer extends StatelessWidget {
  const _DirectionMarkerLayer({required this.legs});

  final List<ItineraryMapLeg> legs;

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers:
          legs
              .map(
                (leg) => Marker(
                  point: _directionPoint(leg),
                  width: 28,
                  height: 28,
                  child: Transform.rotate(
                    angle: _bearingRadians(
                      leg.origin.position,
                      leg.destination.position,
                    ),
                    child: Container(
                      key: ValueKey('direction-marker-${leg.index}'),
                      decoration: BoxDecoration(
                        color: MapConfig.routeColor.withValues(alpha: .92),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }

  LatLng _directionPoint(ItineraryMapLeg leg) {
    final points = leg.points;
    if (!leg.isReverseDuplicate || points.length < 3) {
      if (points.length >= 3) return points[1];
      return LatLng(
        (points.first.latitude + points.last.latitude) / 2,
        (points.first.longitude + points.last.longitude) / 2,
      );
    }

    final first = points.first;
    final control = points[1];
    final firstLength = _distance(first, control);
    final secondLength = _distance(control, points.last);
    final target = (firstLength + secondLength) * .35;
    final alongFirst = target / firstLength;
    return LatLng(
      first.latitude + (control.latitude - first.latitude) * alongFirst,
      first.longitude + (control.longitude - first.longitude) * alongFirst,
    );
  }

  double _distance(LatLng first, LatLng second) {
    final latitudeDelta = second.latitude - first.latitude;
    final longitudeDelta = second.longitude - first.longitude;
    return math.sqrt(
      latitudeDelta * latitudeDelta + longitudeDelta * longitudeDelta,
    );
  }

  double _bearingRadians(LatLng from, LatLng to) {
    final lat1 = _rad(from.latitude);
    final lat2 = _rad(to.latitude);
    final dLon = _rad(to.longitude - from.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return math.atan2(y, x);
  }

  double _rad(double degrees) => degrees * math.pi / 180;
}

class _MapWarningPill extends StatelessWidget {
  const _MapWarningPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF101C2D).withValues(alpha: .94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MapConfig.markerColor.withValues(alpha: .65)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFFF8E7),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
