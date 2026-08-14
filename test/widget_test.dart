import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxitown/services/fake_location_service.dart';
import 'package:taxitown/features/rider/models/ride_model.dart';
import 'package:taxitown/features/rider/providers/ride_provider.dart';
import 'package:taxitown/features/auth/providers/auth_provider.dart';
import 'package:taxitown/features/rider/presentation/screens/confirm_ride_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationService Tests', () {
    final locationService = LocationService();

    test('Distance Calculation (Haversine)', () {
      final distance = locationService.calculateDistance(
        12.9716, 77.5946, // Town Center
        12.9783, 77.5724, // Railway Hub
      );
      expect(distance, greaterThan(1.0));
      expect(distance, lessThan(4.0));
    });

    test('Pricing Estimation', () {
      const start = LocationPoint(latitude: 12.9716, longitude: 77.5946, name: "Start");
      const end = LocationPoint(latitude: 12.9783, longitude: 77.5724, name: "End");

      final price = locationService.estimatePrice(start, end);
      expect(price, greaterThanOrEqualTo(30));
    });
  });

  group('Rider Booking State Machine Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Transitions from idle to fareEstimated and searching', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final notifier = container.read(rideBookingNotifierProvider.notifier);
      
      // 1. Initial State
      expect(container.read(rideBookingNotifierProvider).status, equals(RiderStatus.idle));

      // 2. Select Route state
      notifier.startSelectingRoute();
      expect(container.read(rideBookingNotifierProvider).status, equals(RiderStatus.selectingRoute));

      // 3. Set locations
      const pickup = LocationPoint(latitude: 12.9716, longitude: 77.5946, name: "Pickup");
      const dest = LocationPoint(latitude: 12.9783, longitude: 77.5724, name: "Dest");
      
      notifier.selectPickup(pickup);
      notifier.selectDestination(dest);

      expect(container.read(rideBookingNotifierProvider).status, equals(RiderStatus.fareEstimated));
      expect(container.read(rideBookingNotifierProvider).price, greaterThan(0));

      // 4. Confirm Fare -> starts searching
      notifier.confirmFare();
      expect(container.read(rideBookingNotifierProvider).status, equals(RiderStatus.searching));
    });

    test('Simulated driver match auto-transition', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final notifier = container.read(rideBookingNotifierProvider.notifier);
      
      const pickup = LocationPoint(latitude: 12.9716, longitude: 77.5946, name: "Pickup");
      const dest = LocationPoint(latitude: 12.9783, longitude: 77.5724, name: "Dest");
      
      notifier.selectPickup(pickup);
      notifier.selectDestination(dest);
      notifier.confirmFare();

      expect(container.read(rideBookingNotifierProvider).status, equals(RiderStatus.searching));

      // Wait for simulator Timer (3 seconds matching)
      await Future.delayed(const Duration(milliseconds: 3200));

      // Should auto transition to Accepted
      expect(container.read(rideBookingNotifierProvider).status, equals(RiderStatus.accepted));
      expect(container.read(rideBookingNotifierProvider).activeRide, isNotNull);
      expect(container.read(rideBookingNotifierProvider).activeRide!.otp.length, equals(4));
    });
  });

  group('ConfirmRideScreen Widget Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('Renders all route details and buttons on ConfirmRideScreen', (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final notifier = container.read(rideBookingNotifierProvider.notifier);
      
      // Seed locations so ConfirmRideScreen doesn't show "Missing route locations"
      notifier.selectPickup(const LocationPoint(latitude: 12.9716, longitude: 77.5946, name: "Village Corner"));
      notifier.selectDestination(const LocationPoint(latitude: 12.9783, longitude: 77.5724, name: "Agri Warehouse"));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ConfirmRideScreen(),
          ),
        ),
      );

      // Allow 220ms animation to complete
      await tester.pump(const Duration(milliseconds: 250));

      // Verify page layout and widgets render correctly
      expect(find.text('Confirm Booking Details'), findsOneWidget);
      expect(find.text('Village Corner'), findsOneWidget);
      expect(find.text('Agri Warehouse'), findsOneWidget);
      expect(find.text('Estimated Distance'), findsOneWidget);
      expect(find.text('Estimated Time'), findsOneWidget);
      expect(find.text('Ride Price'), findsOneWidget);
      expect(find.text('Payment Method'), findsOneWidget);
      expect(find.text('Cash (Default)'), findsOneWidget);
      expect(find.text('Confirm Ride'), findsOneWidget);
      expect(find.text('Edit Route'), findsOneWidget);
    });
  });
}
