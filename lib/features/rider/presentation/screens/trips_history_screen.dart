// Reusable screen listing complete rider trip histories and details
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../models/ride_model.dart';
import '../../providers/ride_provider.dart';

class TripsHistoryScreen extends ConsumerWidget {
  const TripsHistoryScreen({super.key});

  void _showRideDetails(BuildContext context, Ride ride) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Ride Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.my_location, color: Color(0xFF2E7D32), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ride.pickup.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ride.destination.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Driver name:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                Text(ride.driver?.name ?? "N/A", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Vehicle info:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                Text(ride.driver?.vehicleModel ?? "N/A", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("License Plate:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                Text(ride.driver?.vehiclePlate ?? "N/A", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Paid amount:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                Text("\$${ride.price.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingState = ref.watch(rideBookingNotifierProvider);
    final history = bookingState.pastRides;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ride History"),
      ),
      body: SafeArea(
        child: history.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_rounded, size: 64, color: AppColors.primary.withOpacity(0.4)),
                    const SizedBox(height: 16),
                    const Text(
                      "No rides recorded yet",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Your past trips will list here.",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final ride = history[history.length - 1 - index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () => _showRideDetails(context, ride),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.directions_car_filled_outlined, color: AppColors.primary),
                      ),
                      title: Text(
                        ride.destination.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        "${ride.timestamp.day}/${ride.timestamp.month}/${ride.timestamp.year} • \$${ride.price.toStringAsFixed(0)}",
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          ride.status.displayName,
                          style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
