import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/colors.dart';
import '../core/providers/app_mode_provider.dart';
import '../features/rider/presentation/screens/home_screen.dart';
import '../features/rider/presentation/screens/search_screen.dart';
import '../features/rider/presentation/screens/ride_options_screen.dart';
import '../features/rider/presentation/screens/live_tracking_screen.dart';
import '../features/rider/presentation/screens/wallet_screen.dart';
import '../features/rider/presentation/screens/confirm_ride_screen.dart';
import '../features/rider/presentation/screens/rider_profile_screen.dart';
import '../features/rider/presentation/screens/rider_trips_screen.dart';
import '../features/driver/presentation/screens/driver_home_screen.dart';
import '../features/driver/presentation/screens/incoming_ride_request_screen.dart';
import '../features/driver/presentation/screens/driver_to_pickup_screen.dart';
import '../features/driver/presentation/screens/driver_arrived_screen.dart';
import '../features/driver/presentation/screens/driver_trip_in_progress_screen.dart';
import '../features/driver/presentation/screens/driver_trip_completed_screen.dart';
import '../features/driver/presentation/screens/driver_wallet_screen.dart';
import '../features/driver/presentation/screens/driver_profile_screen.dart';
import '../features/driver/presentation/screens/driver_trips_screen.dart';
import '../features/driver/presentation/screens/driver_trip_details_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String search = '/search';
  static const String rideOptions = '/ride-options';
  static const String liveTracking = '/live-tracking';
  static const String wallet = '/wallet';
  static const String confirmRide = '/confirm-ride';
  static const String profile = '/profile';
  static const String history = '/history';
  static const String driverHome = '/driver-home';
  static const String incomingRequest = '/incoming-request';
  static const String driverToPickup = '/driver-to-pickup';
  static const String driverArrived = '/driver-arrived';
  static const String driverTripInProgress = '/driver-trip-in-progress';
  static const String driverTripCompleted = '/driver-trip-completed';
  static const String driverWallet = '/driver-wallet';
  static const String driverTripDetails = '/driver-trip-details';

  static Map<String, WidgetBuilder> get routes => {
        home: (context) => const HomeScreen(),
        search: (context) => const SearchScreen(),
        rideOptions: (context) => const RideOptionsScreen(),
        liveTracking: (context) => const LiveTrackingScreen(),
        wallet: (context) => const WalletScreen(),
        confirmRide: (context) => const ConfirmRideScreen(),
        profile: (context) => Consumer(
          builder: (context, ref, child) {
            final mode = ref.watch(appModeProvider);
            return mode == AppMode.rider ? const RiderProfileScreen() : const DriverProfileScreen();
          },
        ),
        history: (context) => Consumer(
          builder: (context, ref, child) {
            final mode = ref.watch(appModeProvider);
            return mode == AppMode.rider ? const RiderTripsScreen() : const DriverTripsScreen();
          },
        ),
        driverHome: (context) => const DriverHomeScreen(),
        incomingRequest: (context) => const IncomingRideRequestScreen(),
        driverToPickup: (context) => const DriverToPickupScreen(),
        driverArrived: (context) => const DriverArrivedScreen(),
        driverTripInProgress: (context) => const DriverTripInProgressScreen(),
        driverTripCompleted: (context) => const DriverTripCompletedScreen(),
        driverWallet: (context) => const DriverWalletScreen(),
        driverTripDetails: (context) => const DriverTripDetailsScreen(),
      };
}
