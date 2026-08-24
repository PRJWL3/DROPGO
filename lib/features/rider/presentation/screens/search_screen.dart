// Location search screen matching the reference layout
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/services/places_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/ride_model.dart';
import '../../providers/ride_provider.dart';

enum SearchFieldType {
  pickup,
  destination,
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();

  List<PlaceSuggestion> _pickupSuggestions = [];
  List<PlaceSuggestion> _destinationSuggestions = [];

  bool _isLoadingPickupSuggestions = false;
  bool _isLoadingDestinationSuggestions = false;
  bool _isLoadingRoute = false;
  
  Timer? _pickupDebounce;
  Timer? _destinationDebounce;
  int _pickupQueryId = 0;
  int _destinationQueryId = 0;

  SearchFieldType _activeField = SearchFieldType.destination;

  List<String> _recentPickups = [];
  List<String> _recentDestinations = [];
  List<Map<String, String>> _popularPlaces = [];

  @override
  void initState() {
    super.initState();
    final bookingState = ref.read(rideBookingNotifierProvider);
    _pickupController.text = bookingState.pickup?.name ?? "";
    _destinationController.text = bookingState.destination?.name ?? "";

    _pickupController.addListener(_onPickupSearchChanged);
    _destinationController.addListener(_onDestinationSearchChanged);

    // Initialize recent lists dynamically from real ride history (live recently visited places)
    _recentPickups = bookingState.pastRides.map((r) => r.pickup.name).toSet().take(5).toList();
    _recentDestinations = bookingState.pastRides.map((r) => r.destination.name).toSet().take(5).toList();

    // Initialize popular places dynamically from saved places (Home, Work, etc.)
    _popularPlaces = bookingState.savedPlaces.map((sp) => {
      "name": sp.label,
      "address": sp.address,
    }).toList();
  }

  @override
  void dispose() {
    _pickupController.removeListener(_onPickupSearchChanged);
    _destinationController.removeListener(_onDestinationSearchChanged);
    _pickupController.dispose();
    _destinationController.dispose();
    _pickupDebounce?.cancel();
    _destinationDebounce?.cancel();
    super.dispose();
  }

  void _onPickupSearchChanged() {
    final query = _pickupController.text;
    if (_pickupDebounce?.isActive ?? false) _pickupDebounce!.cancel();
    
    if (query.trim().length < 2) {
      _pickupQueryId++; // Invalidate pending queries
      setState(() {
        _pickupSuggestions = [];
        _isLoadingPickupSuggestions = false;
      });
      return;
    }

    _pickupQueryId++;
    final currentQueryId = _pickupQueryId;

    _pickupDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() {
        _isLoadingPickupSuggestions = true;
      });
      final service = ref.read(placesServiceProvider);
      debugPrint("Pickup Autocomplete Search Query: '$query' (ID: $currentQueryId)");
      final list = await service.searchPlaces(query);
      if (mounted && currentQueryId == _pickupQueryId) {
        setState(() {
          _pickupSuggestions = list;
          _isLoadingPickupSuggestions = false;
        });
        debugPrint("Applied Pickup suggestions for ID: $currentQueryId");
      } else {
        debugPrint("Discarded stale Pickup suggestions for ID: $currentQueryId (Current ID: $_pickupQueryId)");
      }
    });
  }

  void _onDestinationSearchChanged() {
    final query = _destinationController.text;
    if (_destinationDebounce?.isActive ?? false) _destinationDebounce!.cancel();
    
    if (query.trim().length < 2) {
      _destinationQueryId++; // Invalidate pending queries
      setState(() {
        _destinationSuggestions = [];
        _isLoadingDestinationSuggestions = false;
      });
      return;
    }

    _destinationQueryId++;
    final currentQueryId = _destinationQueryId;

    _destinationDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() {
        _isLoadingDestinationSuggestions = true;
      });
      final service = ref.read(placesServiceProvider);
      debugPrint("Destination Autocomplete Search Query: '$query' (ID: $currentQueryId)");
      final list = await service.searchPlaces(query);
      if (mounted && currentQueryId == _destinationQueryId) {
        setState(() {
          _destinationSuggestions = list;
          _isLoadingDestinationSuggestions = false;
        });
        debugPrint("Applied Destination suggestions for ID: $currentQueryId");
      } else {
        debugPrint("Discarded stale Destination suggestions for ID: $currentQueryId (Current ID: $_destinationQueryId)");
      }
    });
  }

  Future<void> _handlePlaceSelection(String placeId, String fallbackName) async {
    setState(() {
      _isLoadingRoute = true;
    });

    final service = ref.read(placesServiceProvider);
    final notifier = ref.read(rideBookingNotifierProvider.notifier);

    debugPrint("Active field: ${_activeField.name.toUpperCase()}");

    try {
      if (_activeField == SearchFieldType.pickup) {
        final details = await service.getPlaceDetails(placeId);
        final pickupPoint = details != null
            ? LocationPoint(
                latitude: details.latitude,
                longitude: details.longitude,
                name: details.name,
              )
            : LocationPoint(
                latitude: 12.9716,
                longitude: 77.5946,
                name: fallbackName,
              );

        debugPrint("Selected pickup: ${pickupPoint.name} (${pickupPoint.latitude}, ${pickupPoint.longitude})");
        notifier.selectPickup(pickupPoint);
        
        if (mounted) {
          _pickupController.text = pickupPoint.name;
          setState(() {
            _pickupSuggestions = [];
          });
        }
      } else {
        final details = await service.getPlaceDetails(placeId);
        final destinationPoint = details != null
            ? LocationPoint(
                latitude: details.latitude,
                longitude: details.longitude,
                name: details.name,
              )
            : LocationPoint(
                latitude: 12.9916,
                longitude: 77.6146,
                name: fallbackName,
              );

        debugPrint("Selected destination: ${destinationPoint.name} (${destinationPoint.latitude}, ${destinationPoint.longitude})");
        
        final bookingState = ref.read(rideBookingNotifierProvider);
        if (bookingState.pickup != null) {
          debugPrint("Directions Requested from ${bookingState.pickup!.latitude},${bookingState.pickup!.longitude} to ${destinationPoint.latitude},${destinationPoint.longitude}");
          final routeArg = (
            origin: LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude),
            destination: LatLng(destinationPoint.latitude, destinationPoint.longitude),
          );
          
          final routeInfo = await ref.read(routeInfoProvider(routeArg).future);
          if (routeInfo != null) {
            debugPrint("Directions received successfully");
            debugPrint("Polyline point count: ${routeInfo.points.length}");
          }
        }

        notifier.selectDestination(destinationPoint);
        if (mounted) {
          Navigator.pop(context, destinationPoint);
        }
      }
    } catch (e) {
      debugPrint("Place details error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
  }

  void _selectLocation(String name) {
    final placeId = "mock_place_${name.replaceAll(' ', '_')}";
    _handlePlaceSelection(placeId, name);
  }

  @override
  Widget build(BuildContext context) {
    final activeSuggestions = _activeField == SearchFieldType.pickup
        ? _pickupSuggestions
        : _destinationSuggestions;
    final activeLoading = _activeField == SearchFieldType.pickup
        ? _isLoadingPickupSuggestions
        : _isLoadingDestinationSuggestions;
    final activeController = _activeField == SearchFieldType.pickup
        ? _pickupController
        : _destinationController;
    final isSearching = activeController.text.trim().length >= 2;
    
    final chips = [
      {"label": "Home", "icon": Icons.home_rounded},
      {"label": "Work", "icon": Icons.add_box_rounded},
      {"label": "Favorites", "icon": Icons.favorite_rounded},
      {"label": "More", "icon": Icons.more_horiz_rounded},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Search",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // 1. Two-field Search Input (Pickup & Destination)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border, width: 1.1),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withOpacity(0.02),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Pickup Input
                      Row(
                        children: [
                          const Icon(
                            Icons.circle,
                            color: Color(0xFF22C55E), // Green for pickup
                            size: 14,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Focus(
                              onFocusChange: (hasFocus) {
                                if (hasFocus) {
                                  setState(() {
                                    _activeField = SearchFieldType.pickup;
                                  });
                                  debugPrint("Active field: PICKUP");
                                }
                              },
                              child: TextField(
                                controller: _pickupController,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: const InputDecoration(
                                  hintText: "Enter pickup location...",
                                  hintStyle: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ),
                          if (_isLoadingPickupSuggestions)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Divider(height: 1, indent: 26, color: AppColors.border),
                      ),
                      // Destination Input
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFEF4444), // Red pin for destination
                            size: 16,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Focus(
                              onFocusChange: (hasFocus) {
                                if (hasFocus) {
                                  setState(() {
                                    _activeField = SearchFieldType.destination;
                                  });
                                  debugPrint("Active field: DESTINATION");
                                }
                              },
                              child: TextField(
                                controller: _destinationController,
                                autofocus: true,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: const InputDecoration(
                                  hintText: "Where do you want to go?",
                                  hintStyle: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ),
                          if (_isLoadingDestinationSuggestions)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Use Current Location Option (Always visible under the search bar)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border, width: 1.2),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    leading: const Icon(
                      Icons.my_location_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    title: const Text(
                      "Use Current Location",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: const Text(
                      "Set starting point to your current position",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.keyboard_arrow_right_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onTap: () async {
                      final liveLoc = ref.read(liveLocationProvider).value;
                      if (liveLoc != null) {
                        final point = LocationPoint(
                          latitude: liveLoc.latitude,
                          longitude: liveLoc.longitude,
                          name: "Current Location",
                        );
                        if (_activeField == SearchFieldType.pickup) {
                          ref.read(rideBookingNotifierProvider.notifier).selectPickup(point);
                          _pickupController.text = "Current Location";
                        } else {
                          ref.read(rideBookingNotifierProvider.notifier).selectDestination(point);
                          _destinationController.text = "Current Location";
                        }
                        context.showSnackBar("Selected current location!");
                      } else {
                        context.showSnackBar("Fetching location... please enable location services");
                        try {
                          final pos = await Geolocator.getCurrentPosition();
                          final point = LocationPoint(
                            latitude: pos.latitude,
                            longitude: pos.longitude,
                            name: "Current Location",
                          );
                          if (_activeField == SearchFieldType.pickup) {
                            ref.read(rideBookingNotifierProvider.notifier).selectPickup(point);
                            _pickupController.text = "Current Location";
                          } else {
                            ref.read(rideBookingNotifierProvider.notifier).selectDestination(point);
                            _destinationController.text = "Current Location";
                          }
                          context.showSnackBar("Selected current location!");
                        } catch (e) {
                          context.showSnackBar("Could not fetch current location: $e");
                        }
                      }
                    },
                  ),
                ),

                // Live Autocomplete Suggestions List
                if (isSearching) ...[
                  if (activeLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (activeSuggestions.isNotEmpty) ...[
                    const Text(
                      "Search Suggestions",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border, width: 1.2),
                      ),
                      child: Column(
                        children: List.generate(activeSuggestions.length, (index) {
                          final suggestion = activeSuggestions[index];
                          final isLast = index == activeSuggestions.length - 1;

                          return Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                leading: const Icon(
                                  Icons.location_on_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                                title: Text(
                                  suggestion.mainText,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                                subtitle: Text(
                                  suggestion.secondaryText,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.keyboard_arrow_right_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                onTap: () => _handlePlaceSelection(suggestion.placeId, suggestion.mainText),
                              ),
                              if (!isLast)
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: AppColors.border,
                                  indent: 20,
                                  endIndent: 20,
                                ),
                            ],
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ] else ...[
                  // 2. Quick Chips Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(chips.length, (index) {
                      final item = chips[index];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _selectLocation(item['label'] as String);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border, width: 1.1),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  item['icon'] as IconData,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item['label'] as String,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 24),

                  // 3. Recent Searches Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _activeField == SearchFieldType.pickup
                            ? "Recent Pickups"
                            : "Recent Destinations",
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_activeField == SearchFieldType.pickup) {
                              _recentPickups.clear();
                            } else {
                              _recentDestinations.clear();
                            }
                          });
                          context.showSnackBar("Recent list cleared");
                        },
                        child: const Text(
                          "Clear",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Recent Searches Rounded Card Container
                  if (_activeField == SearchFieldType.pickup && _recentPickups.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border, width: 1.2),
                      ),
                      child: Column(
                        children: List.generate(_recentPickups.length, (index) {
                          final item = _recentPickups[index];
                          final isLast = index == _recentPickups.length - 1;

                          return Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                                leading: const Icon(
                                  Icons.access_time_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                title: Text(
                                  item,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.keyboard_arrow_right_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                onTap: () => _selectLocation(item),
                              ),
                              if (!isLast)
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: AppColors.border,
                                  indent: 20,
                                  endIndent: 20,
                                ),
                            ],
                          );
                        }),
                      ),
                    )
                  else if (_activeField == SearchFieldType.destination && _recentDestinations.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border, width: 1.2),
                      ),
                      child: Column(
                        children: List.generate(_recentDestinations.length, (index) {
                          final item = _recentDestinations[index];
                          final isLast = index == _recentDestinations.length - 1;

                          return Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                                leading: const Icon(
                                  Icons.access_time_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                title: Text(
                                  item,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.keyboard_arrow_right_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                onTap: () => _selectLocation(item),
                              ),
                              if (!isLast)
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: AppColors.border,
                                  indent: 20,
                                  endIndent: 20,
                                ),
                            ],
                          );
                        }),
                      ),
                    ),

                  if (_popularPlaces.isNotEmpty) ...[
                    const SizedBox(height: 24),

                    // 4. Popular Places Section Header
                    const Text(
                      "Popular Places",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Popular Places Rounded Card Container
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border, width: 1.2),
                      ),
                      child: Column(
                        children: List.generate(_popularPlaces.length, (index) {
                          final place = _popularPlaces[index];
                          final isLast = index == _popularPlaces.length - 1;

                          return Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                leading: const Icon(
                                    Icons.location_on_rounded,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                  title: Text(
                                    place['name']!,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Text(
                                    place['address']!,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.keyboard_arrow_right_rounded,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onTap: () => _selectLocation(place['name']!),
                                ),
                                if (!isLast)
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: AppColors.border,
                                    indent: 20,
                                    endIndent: 20,
                                  ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ],

                  const SizedBox(height: 32),
                ],
              ],
            ),
          ),
          if (_isLoadingRoute)
            Container(
              color: Colors.black.withOpacity(0.35),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
