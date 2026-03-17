import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:endura/core/storage/hive_boxes.dart';
import 'package:endura/core/maps/stadia_tile_urls.dart';

/// A selectable map tile source used by [EnduraMap].
class MapTileSource {
  final String id;
  final String label;
  final String Function(Brightness brightness) urlBuilder;
  final List<String> subdomains;
  final String attribution;
  final double maxZoom;

  const MapTileSource({
    required this.id,
    required this.label,
    required this.urlBuilder,
    this.subdomains = const [],
    this.attribution = '',
    this.maxZoom = 20,
  });

  String urlTemplate(Brightness brightness) => urlBuilder(brightness);
}

class MapTileSources {
  MapTileSources._();

  static const String defaultSourceId = 'stadia_default';
  static const String _selectedSourceKey = 'tracking_map_source';

  static final List<MapTileSource> all = [
    MapTileSource(
      id: defaultSourceId,
      label: 'Default',
      urlBuilder: (brightness) => brightness == Brightness.dark
          ? StadiaTileUrls.alidadeSmoothDark
          : StadiaTileUrls.alidadeSmooth,
      attribution: '© Stadia Maps • © OpenMapTiles • © OpenStreetMap contributors',
    ),
    MapTileSource(
      id: 'osm_standard',
      label: 'OpenStreetMap',
      urlBuilder: (_) => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap contributors',
      maxZoom: 19,
    ),
    MapTileSource(
      id: 'carto_dark',
      label: 'Carto Dark',
      urlBuilder: (_) => 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      attribution: '© OpenStreetMap contributors • © CARTO',
    ),
    MapTileSource(
      id: 'carto_light',
      label: 'Carto Light',
      urlBuilder: (_) => 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
      subdomains: ['a', 'b', 'c', 'd'],
      attribution: '© OpenStreetMap contributors • © CARTO',
    ),
  ];

  static MapTileSource byId(String? id) {
    return all.where((source) => source.id == id).firstOrNull ?? all.first;
  }

  static Future<MapTileSource> loadSelected() async {
    final box = Hive.box(HiveBoxes.database);
    final id = box.get(_selectedSourceKey) as String?;
    return byId(id);
  }

  static Future<void> saveSelected(String id) async {
    final box = Hive.box(HiveBoxes.database);
    await box.put(_selectedSourceKey, id);
  }
}
