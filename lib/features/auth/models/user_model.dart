// User auth domain model representation
import 'package:flutter/foundation.dart';

@immutable
class UserModel {
  final String? uid;
  final String? phoneNumber;
  final String? name;
  final bool isLoggedIn;

  const UserModel({
    this.uid,
    this.phoneNumber,
    this.name,
    this.isLoggedIn = false,
  });

  UserModel copyWith({
    String? uid,
    String? phoneNumber,
    String? name,
    bool? isLoggedIn,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }
}
