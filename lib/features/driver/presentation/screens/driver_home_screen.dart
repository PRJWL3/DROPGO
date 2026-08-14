// Driver home screen displaying earnings statistics, online toggles, and nearby ride requests
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_mode_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/web_helper.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../rider/presentation/widgets/app_top_bar.dart';
import '../../../rider/presentation/widgets/bottom_nav_bar.dart';
import '../../../rider/presentation/widgets/map_preview.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  bool _isOnline = false;
  int _currentNavIndex = 0;
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColors = ref.watch(appModeColorsProvider);

    return Scaffold(
      backgroundColor: activeColors.background,
      body: Column(
        children: [
          // 1. Unified App Mode Top Bar
          AppTopBar(
            onMenuTap: () {
              Navigator.pushNamed(context, '/profile');
            },
            onNotificationTap: () {
              context.showSnackBar("You have 3 new notifications");
            },
            notificationCount: 3,
          ),

          // 2. Main content scroll area
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  // Today's Earnings and Stats Gradient Card (dynamic blue gradient in driver mode)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: activeColors.isDark
                            ? [const Color(0xFF2563EB), const Color(0xFF60A5FA)]
                            : [const Color(0xFF1565FF), const Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: activeColors.primary.withOpacity(0.24),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "TODAY'S EARNINGS",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "₹860",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Divider(height: 24, color: Colors.white24, thickness: 1.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildCardStat("Trips completed", "12"),
                            _buildCardStat("Online time", "5h 20m"),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Online Toggle Row (iOS-style switch container)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: activeColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: activeColors.border, width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981), // success green dot
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isOnline ? "Online" : "Offline",
                              style: TextStyle(
                                color: _isOnline ? activeColors.primary : activeColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        // iOS-style switch
                        Switch.adaptive(
                          value: _isOnline,
                          activeColor: activeColors.primary,
                          onChanged: (val) {
                            setState(() {
                              _isOnline = val;
                            });
                            context.showSnackBar(
                              _isOnline ? "You are now ONLINE" : "You are now OFFLINE",
                              backgroundColor: _isOnline ? const Color(0xFF10B981) : activeColors.textSecondary,
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Map card container
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: activeColors.border, width: 1.2),
                    ),
                    child: !isGoogleMapsInitialized()
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text("Initializing Maps API...", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                              ],
                            ),
                          )
                        : ref.watch(liveLocationProvider).when(
                            data: (position) {
                        if (_isOnline && _mapController != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _mapController!.animateCamera(
                              CameraUpdate.newCameraPosition(
                                CameraPosition(
                                  target: LatLng(position.latitude, position.longitude),
                                  zoom: 16.0,
                                ),
                              ),
                            );
                          });
                        }

                        final carMarker = Marker(
                          markerId: const MarkerId("driver_car"),
                          position: LatLng(position.latitude, position.longitude),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                          infoWindow: const InfoWindow(title: "My Vehicle"),
                        );

                        return GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(position.latitude, position.longitude),
                            zoom: 16.0,
                          ),
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          zoomControlsEnabled: false,
                          markers: {carMarker},
                          onMapCreated: (controller) {
                            _mapController = controller;
                          },
                        );
                      },
                      error: (err, stack) => Container(
                        color: activeColors.cardBackground,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off_rounded, color: activeColors.primary, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              "Enable location services to view map updates",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: activeColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick Stats Grid Section
                  Text(
                    "Quick Stats",
                    style: TextStyle(
                      color: activeColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildQuickStatTile(Icons.account_balance_wallet_rounded, "Wallet", "₹860", activeColors),
                      _buildQuickStatTile(Icons.star_rounded, "Ratings", "4.9", activeColors),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildQuickStatTile(Icons.local_gas_station_rounded, "Fuel", "85%", activeColors),
                      _buildQuickStatTile(Icons.headset_mic_rounded, "Support", "Active", activeColors),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Bottom ride requests section
                  Text(
                    "Nearby Ride Requests",
                    style: TextStyle(
                      color: activeColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Dynamic Request Card depending on online status
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _isOnline
                        ? _buildIncomingRequestCard(activeColors)
                        : _buildOfflineEmptyState(activeColors),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // 3. Unified Bottom Navigation Dock (Dashboard active)
          BottomNavBar(
            currentIndex: _currentNavIndex,
            onTap: (index) {
              setState(() {
                _currentNavIndex = index;
              });
              if (index == 2) {
                Navigator.pushNamed(context, '/driver-wallet');
              } else if (index == 1) {
                Navigator.pushNamed(context, '/history');
              } else if (index == 3) {
                Navigator.pushNamed(context, '/profile');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildQuickStatTile(IconData icon, String label, String value, AppModeColors activeColors) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: activeColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: activeColors.border, width: 1.1),
        ),
        child: Row(
          children: [
            Icon(icon, color: activeColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: activeColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(color: activeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineEmptyState(AppModeColors activeColors) {
    return Container(
      key: const ValueKey("offline"),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: activeColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeColors.border, width: 1.1),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.wifi_off_rounded, color: activeColors.textSecondary, size: 40),
            const SizedBox(height: 8),
            Text(
              "Go online to view nearby requests",
              style: TextStyle(
                color: activeColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingRequestCard(AppModeColors activeColors) {
    return Container(
      key: const ValueKey("online"),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: activeColors.elevatedCardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: activeColors.primary.withOpacity(0.2), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "RIDE REQUEST • 1.4 km away",
                style: TextStyle(
                  color: activeColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: activeColors.isDark ? const Color(0xFF1E3A8A) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Est. ₹120",
                  style: TextStyle(
                    color: activeColors.isDark ? Colors.white : const Color(0xFFD97706),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: activeColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Market Main Street, Bengaluru",
                  style: TextStyle(
                    color: activeColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    context.showSnackBar("Request declined");
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: activeColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    "Decline",
                    style: TextStyle(color: activeColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/incoming-request');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Accept", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Color scale re-definition helper
const Color _amberDark = Color(0xFFB45309);
