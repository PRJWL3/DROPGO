// Driver trips list screen showing all completed/declined histories
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_mode_provider.dart';

class DriverTripsScreen extends ConsumerWidget {
  const DriverTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeColors = ref.watch(appModeColorsProvider);

    final mockTrips = [
      {"dest": "Airport Terminal 2", "time": "12 Aug, 09:30 AM", "earning": "₹260", "status": "Completed"},
      {"dest": "Ramapuram Market", "time": "11 Aug, 04:15 PM", "earning": "₹118", "status": "Completed"},
      {"dest": "College Campus East", "time": "10 Aug, 11:20 AM", "earning": "₹94", "status": "Completed"},
      {"dest": "South Bypass Crossing", "time": "08 Aug, 02:00 PM", "earning": "₹110", "status": "Completed"},
    ];

    return Scaffold(
      backgroundColor: activeColors.background,
      appBar: AppBar(
        backgroundColor: activeColors.cardBackground,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: activeColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Trip History",
          style: TextStyle(
            color: activeColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        itemCount: mockTrips.length,
        itemBuilder: (context, index) {
          final trip = mockTrips[index];
          return GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/driver-trip-details');
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: activeColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: activeColors.border, width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: activeColors.lightAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.directions_car_rounded, color: activeColors.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip['dest']!,
                          style: TextStyle(
                            color: activeColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          trip['time']!,
                          style: TextStyle(
                            color: activeColors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        trip['earning']!,
                        style: TextStyle(
                          color: const Color(0xFF10B981), // success green
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: activeColors.lightAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          trip['status']!,
                          style: TextStyle(
                            color: activeColors.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
