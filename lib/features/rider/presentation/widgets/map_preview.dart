// Interactive custom painted map preview widget for route displays
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_mode_provider.dart';
import '../../../../core/utils/web_helper.dart';
import '../../models/ride_model.dart';

// Projections boundaries for rural town coordinates
const double minLat = 12.9400;
const double maxLat = 13.0000;
const double minLng = 77.5500;
const double maxLng = 77.6200;

class AppMapWidget extends ConsumerStatefulWidget {
  final LocationPoint? pickup;
  final LocationPoint? destination;
  final List<LocationPoint>? routePoints;
  final LocationPoint? driverPosition;
  final double? driverHeading;
  final Function(LocationPoint)? onPointSelected;
  final bool isSelectingPickup;
  final bool isSelectingDestination;

  const AppMapWidget({
    super.key,
    this.pickup,
    this.destination,
    this.routePoints,
    this.driverPosition,
    this.driverHeading,
    this.onPointSelected,
    this.isSelectingPickup = false,
    this.isSelectingDestination = false,
  });

  @override
  ConsumerState<AppMapWidget> createState() => _AppMapWidgetState();
}

class _AppMapWidgetState extends ConsumerState<AppMapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Center the map view initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _transformationController.value = Matrix4.identity()
        ..translate(-150.0, -150.0) // Shift slightly to center of town
        ..scale(1.5);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  // Convert raw local coordinates from tap to Lat/Lng
  void _handleTap(TapUpDetails details, Size size) {
    if (widget.onPointSelected == null) return;

    final x = details.localPosition.dx / size.width;
    final y = details.localPosition.dy / size.height;

    final double lng = minLng + x * (maxLng - minLng);
    final double lat = maxLat - y * (maxLat - minLat); // Invert y since Canvas goes down

    String resolvedName = widget.isSelectingPickup
        ? "Selected Pickup Location"
        : "Selected Destination";

    if (x < 0.4 && y < 0.4) {
      resolvedName = "North Junction Road";
    } else if (x > 0.6 && y < 0.4) {
      resolvedName = "East Farm Lane";
    } else if (x < 0.4 && y > 0.6) {
      resolvedName = "Green Valleys Link Road";
    } else if (x > 0.6 && y > 0.6) {
      resolvedName = "South Bypass Road";
    } else {
      resolvedName = "Market Main Street";
    }

    widget.onPointSelected!(
      LocationPoint(latitude: lat, longitude: lng, name: resolvedName),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isGoogleMapsInitialized()) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final activeColors = ref.watch(appModeColorsProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          // Canvas Interactive Map
          GestureDetector(
            onTapUp: (details) {
              final renderBox = context.findRenderObject() as RenderBox?;
              if (renderBox != null) {
                _handleTap(details, renderBox.size);
              }
            },
            child: InteractiveViewer(
              transformationController: _transformationController,
              boundaryMargin: const EdgeInsets.all(500),
              minScale: 0.8,
              maxScale: 4.0,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(800, 800),
                    painter: SimulatedMapPainter(
                      pickup: widget.pickup,
                      destination: widget.destination,
                      routePoints: widget.routePoints,
                      driverPosition: widget.driverPosition,
                      driverHeading: widget.driverHeading ?? 0.0,
                      pulseValue: _pulseController.value,
                      primaryColor: activeColors.primary,
                      secondaryColor: activeColors.secondary,
                    ),
                  );
                },
              ),
            ),
          ),

          // Map Mode Indicators
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: activeColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "DropGo Live Map",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Mode Instruction Overlays
          if (widget.isSelectingPickup || widget.isSelectingDestination)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: activeColors.primary.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.isSelectingPickup
                              ? "Tap on the map to set your Pickup Location"
                              : "Tap on the map to set your Destination Location",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Custom Painter mapping rural layout coordinates with vector mock details
class SimulatedMapPainter extends CustomPainter {
  final LocationPoint? pickup;
  final LocationPoint? destination;
  final List<LocationPoint>? routePoints;
  final LocationPoint? driverPosition;
  final double driverHeading;
  final double pulseValue;
  final Color primaryColor;
  final Color secondaryColor;

  SimulatedMapPainter({
    required this.pickup,
    required this.destination,
    required this.routePoints,
    required this.driverPosition,
    required this.driverHeading,
    required this.pulseValue,
    required this.primaryColor,
    required this.secondaryColor,
  });

  // Convert projections coordinate coordinates to screen coordinates
  Offset _toOffset(LocationPoint point, Size size) {
    final double x = (point.longitude - minLng) / (maxLng - minLng);
    final double y = 1.0 - (point.latitude - minLat) / (maxLat - minLat); // Invert y for canvas
    return Offset(x * size.width, y * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw rural background grids/fields
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), gridPaint);

    final greenFieldPaint = Paint()
      ..color = const Color(0xFFECFDF5)
      ..style = PaintingStyle.fill;
    // Draw fields
    canvas.drawRect(Rect.fromLTWH(size.width * 0.1, size.height * 0.1, size.width * 0.35, size.height * 0.25), greenFieldPaint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.6, size.height * 0.5, size.width * 0.3, size.height * 0.4), greenFieldPaint);

    // 2. Draw mock secondary roads lines
    final Paint roadBacking = Paint()
      ..color = Colors.white
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint roadCenterLine = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final List<Path> roads = [];
    // Horizontal highway
    roads.add(Path()..moveTo(0, size.height * 0.3)..lineTo(size.width, size.height * 0.3));
    roads.add(Path()..moveTo(0, size.height * 0.65)..lineTo(size.width, size.height * 0.65));
    // Vertical highway
    roads.add(Path()..moveTo(size.width * 0.25, 0)..lineTo(size.width * 0.25, size.height));
    roads.add(Path()..moveTo(size.width * 0.5, 0)..lineTo(size.width * 0.5, size.height));
    roads.add(Path()..moveTo(size.width * 0.75, 0)..lineTo(size.width * 0.75, size.height));

    // Diagonal bypass
    roads.add(Path()..moveTo(0, 0)..lineTo(size.width, size.height));

    for (final road in roads) {
      canvas.drawPath(road, roadBacking);
      canvas.drawPath(road, roadCenterLine);
    }

    // Static text labels
    final textStyle = TextStyle(
      color: AppColors.textSecondary.withOpacity(0.5),
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    _drawLandmarkText(canvas, "Green Hills Village", const Offset(120, 160), textStyle);
    _drawLandmarkText(canvas, "Town Center Market", const Offset(430, 380), textStyle);
    _drawLandmarkText(canvas, "Railway Station Hub", const Offset(230, 580), textStyle);
    _drawLandmarkText(canvas, "Rural Health Clinic", const Offset(620, 200), textStyle);
    _drawLandmarkText(canvas, "Agri Cooperative", const Offset(600, 680), textStyle);

    // Active route line in premium blue
    if (routePoints != null && routePoints!.length >= 2) {
      final Paint routePaint = Paint()
        ..color = primaryColor.withOpacity(0.8)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final Path routePath = Path();
      final startOffset = _toOffset(routePoints!.first, size);
      routePath.moveTo(startOffset.dx, startOffset.dy);

      for (int i = 1; i < routePoints!.length; i++) {
        final offset = _toOffset(routePoints![i], size);
        routePath.lineTo(offset.dx, offset.dy);
      }

      canvas.drawPath(routePath, routePaint);
    }

    // Pickup Pin
    if (pickup != null) {
      final pickupOffset = _toOffset(pickup!, size);

      final Paint pulsePaint = Paint()
        ..color = primaryColor.withOpacity(0.3 * (1 - pulseValue))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pickupOffset, 24 * pulseValue, pulsePaint);

      canvas.drawCircle(pickupOffset, 8, Paint()..color = Colors.black12);

      final Paint pinPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pickupOffset, 6, pinPaint);
      canvas.drawCircle(
        pickupOffset,
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Destination Pin
    if (destination != null) {
      final destOffset = _toOffset(destination!, size);

      canvas.drawCircle(destOffset, 8, Paint()..color = Colors.black12);

      final Paint pinPaint = Paint()
        ..color = secondaryColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(destOffset, 6, pinPaint);
      canvas.drawCircle(
        destOffset,
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Driver car position
    if (driverPosition != null) {
      final driverOffset = _toOffset(driverPosition!, size);

      final Paint pulsePaint = Paint()
        ..color = primaryColor.withOpacity(0.2 * (1 - pulseValue))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(driverOffset, 20 * pulseValue, pulsePaint);

      canvas.save();
      canvas.translate(driverOffset.dx, driverOffset.dy);
      canvas.rotate(driverHeading);

      final Path carPath = Path();
      carPath.moveTo(0, -9);
      carPath.lineTo(7, 9);
      carPath.lineTo(0, 5);
      carPath.lineTo(-7, 9);
      carPath.close();

      final Paint carPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(carPath, carPaint);

      final Paint nosePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(0, -5), 2.5, nosePaint);

      canvas.restore();
    }
  }

  void _drawLandmarkText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        offset.dx - textPainter.width / 2,
        offset.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant SimulatedMapPainter oldDelegate) {
    return oldDelegate.pickup != pickup ||
        oldDelegate.destination != destination ||
        oldDelegate.routePoints != routePoints ||
        oldDelegate.driverPosition != driverPosition ||
        oldDelegate.driverHeading != driverHeading ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
