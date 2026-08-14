// Reusable profile screen displaying user settings, saved places, and SOS contacts
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/ride_provider.dart';

class RiderProfileScreen extends ConsumerStatefulWidget {
  const RiderProfileScreen({super.key});

  @override
  ConsumerState<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends ConsumerState<RiderProfileScreen> {
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
                      radius: 30,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      child: const Icon(Icons.person, color: AppColors.primary, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? "Passenger Guest",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.phoneNumber ?? "No phone number",
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text("Preferences & SOS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.language, color: AppColors.primary),
                      title: const Text("Language"),
                      subtitle: Text(_selectedLanguage),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showLanguageSelector(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.emergency, color: Colors.red),
                      title: const Text("Emergency SOS Contact"),
                      subtitle: Text(_emergencyContact),
                      trailing: const Icon(Icons.edit, size: 18),
                      onTap: () => _editEmergencyContact(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
