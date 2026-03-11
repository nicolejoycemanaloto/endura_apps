import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

/// Renders a route polyline on a dark background without map tiles.
/// Used in share cards, feed cards, and activity history.
class PolylineOnlyPreview extends StatelessWidget {
  final List<LatLng> routePoints;
  final Color backgroundColor;
  final Color lineColor;
  final double lineWidth;
  final bool showGlow;
  final bool showEndpoints;

  const PolylineOnlyPreview({
    super.key,
    required this.routePoints,
    this.backgroundColor = Colors.transparent,
    this.lineColor = const Color(0xFF6F2DA8),
    this.lineWidth = 3,
    this.showGlow = true,
    this.showEndpoints = true,
  });

  @override
  Widget build(BuildContext context) {
    if (routePoints.length < 2) {
      return const SizedBox.shrink();
    }
    return Container(
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _RouteLinePainter(
              routePoints: routePoints,
              lineColor: lineColor,
              lineWidth: lineWidth,
              showGlow: showGlow,
              showEndpoints: showEndpoints,
            ),
          );
        },
      ),
    );
  }
}

class _RouteLinePainter extends CustomPainter {
  final List<LatLng> routePoints;
  final Color lineColor;
  final double lineWidth;
  final bool showGlow;
  final bool showEndpoints;

  _RouteLinePainter({
    required this.routePoints,
    required this.lineColor,
    required this.lineWidth,
    required this.showGlow,
    required this.showEndpoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (routePoints.length < 2) return;

    double minLat = routePoints.first.latitude;
    double maxLat = routePoints.first.latitude;
    double minLng = routePoints.first.longitude;
    double maxLng = routePoints.first.longitude;

    for (final p in routePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final latRange = (maxLat - minLat) == 0 ? 0.001 : (maxLat - minLat);
    final lngRange = (maxLng - minLng) == 0 ? 0.001 : (maxLng - minLng);
    const padding = 20.0;
    final drawW = size.width - padding * 2;
    final drawH = size.height - padding * 2;

    final scaleX = drawW / lngRange;
    final scaleY = drawH / latRange;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final offsetX = padding + (drawW - lngRange * scale) / 2;
    final offsetY = padding + (drawH - latRange * scale) / 2;

    Offset toCanvas(LatLng p) {
      return Offset(
        offsetX + (p.longitude - minLng) * scale,
        offsetY + (maxLat - p.latitude) * scale,
      );
    }

    final path = Path();
    path.moveTo(
        toCanvas(routePoints.first).dx, toCanvas(routePoints.first).dy);
    for (int i = 1; i < routePoints.length; i++) {
      final pt = toCanvas(routePoints[i]);
      path.lineTo(pt.dx, pt.dy);
    }

    if (showGlow) {
      // Glow
      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor.withValues(alpha: 0.3)
          ..strokeWidth = lineWidth + 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Main line
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = lineWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (showEndpoints) {
      // Start dot — light purple (primaryLight shade)
      final startPt = toCanvas(routePoints.first);
      canvas.drawCircle(startPt, 6, Paint()..color = const Color(0xFF8E44AD));
      canvas.drawCircle(startPt, 6,
          Paint()
            ..color = const Color(0x556F2DA8)
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke);

      // End dot — white with purple border
      final endPt = toCanvas(routePoints.last);
      canvas.drawCircle(endPt, 6, Paint()..color = const Color(0xFF6F2DA8));
      canvas.drawCircle(endPt, 6,
          Paint()
            ..color = const Color(0x556F2DA8)
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _RouteLinePainter oldDelegate) {
    return oldDelegate.routePoints != routePoints ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.lineWidth != lineWidth ||
        oldDelegate.showGlow != showGlow ||
        oldDelegate.showEndpoints != showEndpoints;
  }
}
