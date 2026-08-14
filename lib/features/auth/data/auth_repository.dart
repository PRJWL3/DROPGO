import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/domain/models.dart';

abstract class AuthRepository {
  Future<AppUser?> getCurrentUser();
  Future<AppUser> signInWithPhone(
    String phoneNumber,
    String name, {
    bool asDriver,
    String? vehicleModel,
    String? vehiclePlate,
  });
  Future<void> signOut();
  Future<AppUser> updateRole(
    String userId,
    bool isDriver, {
    String? vehicleModel,
    String? vehiclePlate,
  });
  Stream<AppUser?> authStateChanges();
}

class MockAuthRepository implements AuthRepository {
  final SharedPreferences _prefs;
  AppUser? _currentUser;

  // Custom controller to notify stream listeners
  final List<void Function(AppUser?)> _listeners = [];

  MockAuthRepository(this._prefs) {
    _loadUser();
  }

  void _loadUser() {
    final userJson = _prefs.getString('taxitown_user');
    if (userJson != null) {
      try {
        _currentUser = AppUser.fromJson(jsonDecode(userJson));
      } catch (_) {
        _currentUser = null;
      }
    }
  }

  Future<void> _saveUser(AppUser? user) async {
    _currentUser = user;
    if (user != null) {
      await _prefs.setString('taxitown_user', jsonEncode(user.toJson()));
    } else {
      await _prefs.remove('taxitown_user');
    }
    for (var listener in _listeners) {
      listener(_currentUser);
    }
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Future<AppUser> signInWithPhone(
    String phoneNumber,
    String name, {
    bool asDriver = false,
    String? vehicleModel,
    String? vehiclePlate,
  }) async {
    // Delay to simulate network activity
    await Future.delayed(const Duration(milliseconds: 800));

    final user = AppUser(
      id: "mock_user_${DateTime.now().millisecondsSinceEpoch}",
      phoneNumber: phoneNumber,
      name: name,
      isDriver: asDriver,
      driverDetails: asDriver
          ? DriverDetails(
              vehicleModel: vehicleModel ?? "Rural Eco-E-Rickshaw",
              vehiclePlate: vehiclePlate ?? "TT-05-AB-1234",
              isOnline: true,
              currentLat: 12.9716, // Starts at Town Center Market
              currentLng: 77.5946,
            )
          : null,
    );

    await _saveUser(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    await _saveUser(null);
  }

  @override
  Future<AppUser> updateRole(
    String userId,
    bool isDriver, {
    String? vehicleModel,
    String? vehiclePlate,
  }) async {
    if (_currentUser == null) throw Exception("No user logged in");

    DriverDetails? details;
    if (isDriver) {
      details = DriverDetails(
        vehicleModel:
            vehicleModel ??
            _currentUser?.driverDetails?.vehicleModel ??
            "Rural Eco SUV",
        vehiclePlate:
            vehiclePlate ??
            _currentUser?.driverDetails?.vehiclePlate ??
            "TT-08-XY-9999",
        isOnline: true,
        currentLat: 12.9716,
        currentLng: 77.5946,
      );
    }

    final updated = _currentUser!.copyWith(
      isDriver: isDriver,
      driverDetails: details,
    );

    await _saveUser(updated);
    return updated;
  }

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _currentUser;
    // Simple custom stream generator
    final StreamRecord controller = StreamRecord();
    _listeners.add(controller.add);
    yield* controller.stream;
  }
}

// Simple dynamic custom Stream Controller fallback helper
class StreamRecord {
  final List<AppUser?> _buffer = [];
  bool _isClosed = false;

  void add(AppUser? user) {
    if (!_isClosed) {
      _buffer.add(user);
    }
  }

  Stream<AppUser?> get stream async* {
    while (!_isClosed) {
      await Future.delayed(const Duration(milliseconds: 100));
      while (_buffer.isNotEmpty) {
        yield _buffer.removeAt(0);
      }
    }
  }

  void close() {
    _isClosed = true;
  }
}
