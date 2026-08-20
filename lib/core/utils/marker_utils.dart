import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerUtils {
  static Future<BitmapDescriptor> getPickupMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 90.0;
    
    // Draw shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 3.2, shadowPaint);

    // Draw outer green circle
    final Paint outerPaint = Paint()
      ..color = const Color(0xFF22C55E) // Emerald green
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 3.4, outerPaint);

    // Draw inner white circle
    final Paint innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 6.0, innerPaint);

    // Draw small green center dot
    final Paint dotPaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 12.0, dotPaint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> getDestinationMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 95.0;

    // Draw shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(const Offset(size / 2, size * 0.8), size / 7.5, shadowPaint);

    // Draw Google Pin Path (Red)
    final Paint pinPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;
      
    final Path path = Path();
    path.moveTo(size / 2, size * 0.15);
    path.cubicTo(size * 0.25, size * 0.15, size * 0.25, size * 0.55, size / 2, size * 0.85);
    path.cubicTo(size * 0.75, size * 0.55, size * 0.75, size * 0.15, size / 2, size * 0.15);
    path.close();
    canvas.drawPath(path, pinPaint);

    // Draw inner white center hole
    final Paint innerWhitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size * 0.42), size / 8.0, innerWhitePaint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> getBikeDriverMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 80.0;
    
    // Draw shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.5, shadowPaint);

    // Draw outer dark blue circular border
    final Paint outerPaint = Paint()
      ..color = const Color(0xFF1565FF) // Primary ride blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.7, outerPaint);

    // Draw inner white circle
    final Paint innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 3.4, innerPaint);

    // Draw a small bike-like silhouette (e.g. two wheels and a connecting line)
    final Paint linePaint = Paint()
      ..color = const Color(0xFF1565FF)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;
    
    // Wheels
    final Paint wheelPaint = Paint()
      ..color = const Color(0xFF1F2937) // Dark gray
      ..style = PaintingStyle.fill;
      
    // Left wheel
    canvas.drawCircle(const Offset(size * 0.38, size * 0.58), size / 14, wheelPaint);
    // Right wheel
    canvas.drawCircle(const Offset(size * 0.62, size * 0.58), size / 14, wheelPaint);

    // Chassis / frame lines
    final Path framePath = Path()
      ..moveTo(size * 0.38, size * 0.58)
      ..lineTo(size * 0.50, size * 0.45)
      ..lineTo(size * 0.62, size * 0.58)
      ..moveTo(size * 0.50, size * 0.45)
      ..lineTo(size * 0.50, size * 0.35)
      ..lineTo(size * 0.45, size * 0.35);
    canvas.drawPath(framePath, linePaint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }
}
