import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const Color _red = Color(0xFFD94C4C);
const Color _green = Color(0xFF16865B);
const Color _navy = Color(0xFF17243A);
const Color _muted = Color(0xFF8290A5);
const Color _amber = Color(0xFFE39B35);

const List<Color> _zoneColors = [
  Color(0xFF3867D6),
  Color(0xFF9B59B6),
  Color(0xFFE39B35),
  Color(0xFF16865B),
];

class MapScreen extends StatelessWidget {
  final List<dynamic> trackers;
  final List<dynamic> zones;

  const MapScreen({
    super.key,
    required this.trackers,
    required this.zones,
  });

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  @override
  Widget build(BuildContext context) {
        const distance = Distance();
    final zoneAreas = <({LatLng center, double radius})>[];
    for (final zone in zones) {
      final zl = _toDouble(zone['center_lat']);
      final zo = _toDouble(zone['center_lon']);
      if (zl == null || zo == null) continue;
      zoneAreas.add((
        center: LatLng(zl, zo),
        radius: _toDouble(zone['radius_m']) ?? 150,
      ));
    }
    final markers = <Marker>[];
    final circles = <CircleMarker>[];
    final points = <LatLng>[];

    // Display animal positions.
    for (final tracker in trackers) {
      final lat = _toDouble(tracker['lat']);
      final lon = _toDouble(tracker['lon']);

      if (lat == null || lon == null) continue;

      final point = LatLng(lat, lon);
      points.add(point);

      final isAnomaly = tracker['is_anomaly'] == true;
      final outsideZones = zoneAreas.isNotEmpty &&
          zoneAreas.every(
            (z) => distance.as(LengthUnit.Meter, point, z.center) > z.radius,
          );
      final color = isAnomaly ? _red : (outsideZones ? _amber : _green);

      markers.add(
        Marker(
          point: point,
          width: 85,
          height: 65,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pets, size: 30, color: color),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  '${tracker['tracker_id'] ?? 'Unknown'}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _navy,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Display DBSCAN habitual grazing zones.
    for (final zone in zones) {
      final lat = _toDouble(zone['center_lat']);
      final lon = _toDouble(zone['center_lon']);

      if (lat == null || lon == null) continue;

      final point = LatLng(lat, lon);
      points.add(point);

      final clusterId = zone['cluster_id'] is num
          ? (zone['cluster_id'] as num).toInt()
          : 0;

      final color =
          _zoneColors[clusterId.abs() % _zoneColors.length];

      final pointCount = zone['point_count'] ?? 0;
      final label = zone['label'] ?? 'Grazing Zone';
      final zoneRadius = _toDouble(zone['radius_m']) ?? 150;

      // Approximate 150-metre circle around the DBSCAN centre.
      circles.add(
        CircleMarker(
          point: point,
          radius: zoneRadius,
          useRadiusInMeter: true,
          color: color.withValues(alpha: 0.12),
          borderColor: color,
          borderStrokeWidth: 2,
        ),
      );

      // Label displayed at the centre of the zone.
      markers.add(
        Marker(
          point: point,
          width: 160,
          height: 75,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, size: 34, color: color),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$pointCount GPS points',
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate map centre.
    LatLng center = const LatLng(36.9553, 8.7597);

    if (points.isNotEmpty) {
      final averageLat =
          points.map((p) => p.latitude).reduce((a, b) => a + b) /
              points.length;

      final averageLon =
          points.map((p) => p.longitude).reduce((a, b) => a + b) /
              points.length;

      center = LatLng(averageLat, averageLon);
    }

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.livestock_app',
            ),

            // Zones are drawn underneath the animal markers.
            CircleLayer(circles: circles),

            MarkerLayer(markers: markers),
          ],
        ),

        // Number of discovered zones.
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.hub,
                  color: Color(0xFF3867D6),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '${zones.length} habitual zones detected',
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Map legend.
        Positioned(
          bottom: 20,
          left: 16,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'MAP LEGEND',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                _legendItem(_green, 'Normal tracker'),
                _legendItem(_red, 'Anomaly detected'),
                _legendItem(_amber, 'Outside habitual zones'),

                _legendItem(
                  const Color(0xFF3867D6),
                  'Habitual grazing zone',
                  isCircle: true,
                ),

                const SizedBox(height: 8),

                const Text(
                  'Zone circles are approximate 150m visuals.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendItem(
    Color color,
    String label, {
    bool isCircle = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isCircle
                  ? color.withValues(alpha: 0.2)
                  : color,
              shape: isCircle
                  ? BoxShape.circle
                  : BoxShape.rectangle,
              border: isCircle
                  ? Border.all(color: color, width: 1.5)
                  : null,
              borderRadius:
                  isCircle ? null : BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: _navy,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}