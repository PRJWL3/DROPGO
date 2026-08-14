import '../models/ride_model.dart';

class FakeRideService {
  FakeRideService._();

  static Future<Driver> simulateDriverMatch() async {
    // Delay 2 seconds to simulate searching progress
    await Future.delayed(const Duration(seconds: 2));

    return const Driver(
      id: "d_matched",
      name: "Amit Kumar",
      rating: 4.8,
      vehicleModel: "Maruti Suzuki WagonR",
      vehiclePlate: "KA-01-EF-5678",
      phone: "+91 98765 43210",
      photoUrl: "",
      currentLat: 12.9716,
      currentLng: 77.5946,
    );
  }
}
