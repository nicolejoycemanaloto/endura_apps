import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:endura/core/maps/stadia_map_config.dart';
import 'package:endura/core/maps/stadia_tile_urls.dart';

/// Reusable map widget wrapping flutter_map with Stadia Maps tiles.
class EnduraMap extends StatelessWidget {
  final LatLng? center;
  final double? zoom;
  final List<Polyline> polylines;
  final List<Marker> markers;
  final bool interactive;
  final MapController? mapController;
  final CameraFit? initialCameraFit;

  const EnduraMap({
    super.key,
    this.center,
    this.zoom,
    this.polylines = const [],
    this.markers = const [],
    this.interactive = true,
    this.mapController,
    this.initialCameraFit,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness;
    final tileUrl = brightness == Brightness.dark
        ? StadiaTileUrls.alidadeSmoothDark
        : StadiaTileUrls.alidadeSmooth;

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center ?? StadiaMapConfig.defaultCenter,
        initialZoom: zoom ?? StadiaMapConfig.defaultZoom,
        minZoom: StadiaMapConfig.minZoom,
        maxZoom: StadiaMapConfig.maxZoom,
        initialCameraFit: initialCameraFit,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: tileUrl,
          userAgentPackageName: 'com.endura.app',
          maxZoom: StadiaMapConfig.maxZoom,
        ),
        if (polylines.isNotEmpty)
          PolylineLayer(
            polylines: polylines,
            // Disable point simplification so the polyline follows every
            // recorded GPS point exactly and doesn't cut through buildings.
            simplificationTolerance: 0,
          ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }
}



