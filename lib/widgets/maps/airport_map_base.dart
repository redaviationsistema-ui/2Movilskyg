import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';

import '../../core/config/map_config.dart';

typedef VectorStyleLoader = Future<vt.Style> Function();

class AirportMapBase extends StatefulWidget {
  const AirportMapBase({
    super.key,
    this.height = MapConfig.fallbackMapHeight,
    this.mapController,
    this.overlayLayers = const [],
    this.enableVectorProvider = true,
    this.styleLoader,
    this.center = MapConfig.initialCenter,
    this.initialZoom = MapConfig.initialZoom,
    this.minZoom = MapConfig.minZoom,
    this.maxZoom = MapConfig.maxZoom,
    this.fallbackMessage = MapConfig.unavailableMessage,
    this.onMapReady,
    this.onStyleDisposed,
  });

  final double height;
  final MapController? mapController;
  final List<Widget> overlayLayers;
  final bool enableVectorProvider;
  final VectorStyleLoader? styleLoader;
  final LatLng center;
  final double initialZoom;
  final double minZoom;
  final double maxZoom;
  final String fallbackMessage;
  final VoidCallback? onMapReady;
  final VoidCallback? onStyleDisposed;

  @override
  State<AirportMapBase> createState() => _AirportMapBaseState();
}

class _AirportMapBaseState extends State<AirportMapBase> {
  Future<vt.Style>? _styleFuture;
  vt.Style? _loadedStyle;

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  @override
  void didUpdateWidget(covariant AirportMapBase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableVectorProvider != widget.enableVectorProvider ||
        oldWidget.styleLoader != widget.styleLoader) {
      _disposeLoadedStyle();
      _loadStyle();
    }
  }

  @override
  void dispose() {
    _disposeLoadedStyle();
    super.dispose();
  }

  void _loadStyle() {
    if (!widget.enableVectorProvider || !MapConfig.provider.isVectorAvailable) {
      _styleFuture = null;
      return;
    }
    _styleFuture = (widget.styleLoader ?? _defaultStyleLoader)();
  }

  Future<vt.Style> _defaultStyleLoader() {
    return vt.StyleReader(
      uri: MapConfig.provider.vectorStyleUrl!,
      logger: const vt.Logger.console(),
    ).read();
  }

  void _retry() {
    setState(() {
      _disposeLoadedStyle();
      _loadStyle();
    });
  }

  void _disposeLoadedStyle() {
    _loadedStyle?.dispose();
    if (_loadedStyle != null) widget.onStyleDisposed?.call();
    _loadedStyle = null;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: MapConfig.borderRadius,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child:
            _styleFuture == null && !widget.enableVectorProvider
                ? _VectorMapShell(
                  mapController: widget.mapController,
                  center: widget.center,
                  initialZoom: widget.initialZoom,
                  minZoom: widget.minZoom,
                  maxZoom: widget.maxZoom,
                  overlayLayers: widget.overlayLayers,
                  onMapReady: widget.onMapReady,
                  attributions: MapConfig.provider.attribution,
                )
                : _styleFuture == null
                ? _MapFallback(message: widget.fallbackMessage, onRetry: null)
                : FutureBuilder<vt.Style>(
                  future: _styleFuture,
                  builder: (context, snapshot) {
                    final style = snapshot.data;
                    if (style == null) {
                      if (snapshot.hasError) {
                        return _MapFallback(
                          message: widget.fallbackMessage,
                          onRetry: _retry,
                        );
                      }
                      return const _MapFallback(
                        message: MapConfig.loadingMessage,
                        isLoading: true,
                      );
                    }
                    _loadedStyle ??= style;
                    return _VectorMapShell(
                      mapController: widget.mapController,
                      style: style,
                      center: widget.center,
                      initialZoom: widget.initialZoom,
                      minZoom: widget.minZoom,
                      maxZoom: widget.maxZoom,
                      overlayLayers: widget.overlayLayers,
                      onMapReady: widget.onMapReady,
                      attributions: MapConfig.provider.attribution,
                    );
                  },
                ),
      ),
    );
  }
}

class _VectorMapShell extends StatelessWidget {
  const _VectorMapShell({
    required this.center,
    required this.initialZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.overlayLayers,
    required this.attributions,
    this.style,
    this.mapController,
    this.onMapReady,
  });

  final vt.Style? style;
  final MapController? mapController;
  final LatLng center;
  final double initialZoom;
  final double minZoom;
  final double maxZoom;
  final List<Widget> overlayLayers;
  final String attributions;
  final VoidCallback? onMapReady;

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style;
    final resolvedAttributions =
        resolvedStyle == null || resolvedStyle.attributions.isEmpty
            ? attributions
            : resolvedStyle.attributions.map((item) => item.text).join(' · ');

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: resolvedStyle?.center ?? center,
            initialZoom: resolvedStyle?.zoom ?? initialZoom,
            minZoom: minZoom,
            maxZoom: maxZoom,
            backgroundColor: MapConfig.fallbackBackgroundColor,
            onMapReady: onMapReady,
          ),
          children: [
            if (resolvedStyle == null)
              const ColoredBox(color: MapConfig.fallbackBackgroundColor)
            else
              vt.VectorTileLayer(
                theme: resolvedStyle.theme,
                tileProviders: resolvedStyle.providers,
                rasterSources: resolvedStyle.rasterSources,
                sprites: resolvedStyle.sprites,
                logger: const vt.Logger.console(),
              ),
            ...overlayLayers,
          ],
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: MapAttributionBadge(attributions: resolvedAttributions),
        ),
      ],
    );
  }
}

class _MapFallback extends StatelessWidget {
  const _MapFallback({
    required this.message,
    this.isLoading = false,
    this.onRetry,
  });

  final String message;
  final bool isLoading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: MapConfig.fallbackBackgroundColor),
      child: Padding(
        padding: MapConfig.mapPadding,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MapConfig.markerColor.withValues(alpha: .14),
                      border: Border.all(
                        color: MapConfig.markerColor.withValues(alpha: .42),
                      ),
                    ),
                    child: const Icon(
                      Icons.map_outlined,
                      color: MapConfig.markerColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isLoading) ...[
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MapConfig.markerColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MapConfig.markerColor,
                        side: BorderSide(
                          color: MapConfig.markerColor.withValues(alpha: .55),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: MapAttributionBadge(
                attributions: MapConfig.provider.attribution,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MapAttributionBadge extends StatelessWidget {
  const MapAttributionBadge({super.key, required this.attributions});

  final String attributions;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MapConfig.attributionBackgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Text(
            '© ${MapConfig.openStreetMapAttribution} | '
            '$attributions',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: MapConfig.attributionTextColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
