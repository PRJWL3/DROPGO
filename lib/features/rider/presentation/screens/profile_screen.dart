// Reusable profile screen displaying user settings, saved places, and SOS contacts
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/ride_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _selectedLanguage = "English";
  String _emergencyContact = "+91 91100 22000 (Police)";

  void _showLanguageSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select App Language"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ["English", "ಕನ್ನಡ (Kannada)", "हिंदी (Hindi)"].map((lang) {
            return RadioListTile<String>(
              title: Text(lang),
              value: lang,
              groupValue: _selectedLanguage,
              activeColor: AppColors.primary,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedLanguage = val;
                  });
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _editEmergencyContact(BuildContext context) {
    final controller = TextEditingController(text: _emergencyContact);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update SOS Contact"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Emergency Phone / Name",
            hintText: "+1 234 567 890",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _emergencyContact = controller.text.trim();
              });
              Navigator.pop(context);
            },
            child: const Text("Save", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final bookingState = ref.watch(rideBookingNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User details header card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      child: const Icon(Icons.person, color: AppColors.primary, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name ?? "Alex Rider",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.phoneNumber ?? "+91 98765 43210",
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Saved Places shortcuts section
              _buildSectionHeader(Icons.bookmark_outline, "Saved Places"),
              const SizedBox(height: 10),
              ...bookingState.savedPlaces.map((place) {
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      place.iconName == "home" ? Icons.home_outlined : Icons.school_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(place.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(place.address, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                );
              }),
              const SizedBox(height: 24),

              // Settings Section
              _buildSectionHeader(Icons.settings_outlined, "App Settings"),
              const SizedBox(height: 10),

              // Emergency Contact row
              ListTile(
                leading: const Icon(Icons.gpp_maybe_outlined, color: Colors.red),
                title: const Text("Emergency SOS Contact", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(_emergencyContact, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => _editEmergencyContact(context),
              ),
              const Divider(height: 1),

              // Language row
              ListTile(
                leading: const Icon(Icons.language_outlined, color: Colors.blue),
                title: const Text("App Language", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(_selectedLanguage, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: const Icon(Icons.keyboard_arrow_right, size: 18),
                onTap: () => _showLanguageSelector(context),
              ),
              const Divider(height: 1),

              // Help and support
              ListTile(
                leading: const Icon(Icons.help_outline_outlined, color: Colors.grey),
                title: const Text("Help & Support", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: const Text("Fares, safety guidelines, and feedback", style: TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: const Icon(Icons.keyboard_arrow_right, size: 18),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Support desk is open from 9 AM to 6 PM."),
                      backgroundColor: Color(0xFF111111),
                    ),
                  );
                },
              ),
              const SizedBox(height: 48),

              // Sign out Action Button
              ElevatedButton(
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Sign Out Account", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }
}
