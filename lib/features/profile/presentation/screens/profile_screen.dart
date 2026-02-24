import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import 'package:lms/core/services/selfie_service.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/features/profile/presentation/screens/profile_id_card_screen.dart';
import 'package:lms/features/profile/presentation/widgets/profile_header.dart';
import 'package:lms/features/profile/presentation/widgets/floating_details_card.dart';
import 'package:lms/shared/widgets/app_bar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  final SelfieService _selfieService = SelfieService();

  /// Refresh profile
  Future<void> _refreshUser() async {
    await ref.read(authProvider.notifier).tryAutoLogin();
  }

  /// SHOW IMAGE SOURCE OPTIONS
  Future<void> _showImageSourceOptions() async {
    final scheme = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// TAKE PHOTO OPTION
              ListTile(
                leading: Icon(Icons.camera_alt, color: scheme.primary),
                title: const Text("Take Photo"),
                onTap: () async {
                  Navigator.pop(context);

                  final File? file = await _selfieService.captureSelfie(
                    context,
                  );

                  if (file != null) {
                    final compressed = await _selfieService.compressImage(file);

                    await _uploadProfileImage(compressed);
                  }
                },
              ),

              /// GALLERY OPTION
              ListTile(
                leading: Icon(Icons.photo_library, color: scheme.primary),
                title: const Text("Choose from Gallery"),
                onTap: () async {
                  Navigator.pop(context);

                  final XFile? pickedFile = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );

                  if (pickedFile != null) {
                    final file = File(pickedFile.path);

                    final compressed = await _selfieService.compressImage(file);

                    await _uploadProfileImage(compressed);
                  }
                },
              ),

              /// CANCEL OPTION
              const SizedBox(height: 8),

              ListTile(
                leading: const Icon(Icons.close),
                title: const Text("Cancel"),
                onTap: () => Navigator.pop(context),
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// UPLOAD PROFILE IMAGE
  Future<void> _uploadProfileImage(File file) async {
    final ext = file.path.split('.').last.toLowerCase();

    if (!['png', 'jpg', 'jpeg'].contains(ext)) {
      _snack("Only JPG and PNG images allowed");
      return;
    }

    final sizeMB = await file.length() / (1024 * 1024);

    if (sizeMB > 1) {
      _snack("Please select image smaller than 1MB");
      return;
    }

    final loader = ref.read(globalLoadingProvider.notifier);

    try {
      loader.showLoading("Uploading profile photo...");

      await ref.read(authProvider.notifier).uploadProfileImage(file);

      loader.showSuccess("Profile updated successfully");
    } catch (_) {
      loader.hide();

      _snack("Upload failed. Try again.");
    }
  }

  /// SNACK HELPER
  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final state = ref.watch(authProvider);

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = state.authUser;

    final profile = state.profile;

    final name = profile?.associatesName ?? user?.name ?? 'Guest';

    final empId = profile?.payrollCode ?? 'EMP0001';

    final details = [
      ("Employee ID", empId, Icons.badge_outlined),

      ("Designation", profile?.designation ?? 'N/A', Icons.work_outline),

      (
        "Department",
        profile?.departmentName ?? 'N/A',
        Icons.apartment_outlined,
      ),

      (
        "Manager",
        profile?.manager?.name ?? 'N/A',
        Icons.supervisor_account_outlined,
      ),

      (
        "Reporting To",
        profile?.departmentHead?.name ?? 'N/A',
        Icons.leaderboard_outlined,
      ),

      ("Email", profile?.email ?? 'N/A', Icons.email_outlined),

      (
        "Blood Group",
        profile?.bloodGroup ?? 'N/A',
        Icons.favorite_border_outlined,
      ),
    ];

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,

      appBar: const AppAppBar(title: "Profile", showBack: false),

      drawer: AppDrawer(),

      body: RefreshIndicator(
        onRefresh: _refreshUser,

        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),

          child: Column(
            children: [
              /// PROFILE HEADER
              CurvedProfileHeader(
                name: name,

                empId: empId,

                imageUrl: state.profileUrl,

                onEditTap: _showImageSourceOptions,
              ),

              /// DETAILS CARD
              Transform.translate(
                offset: const Offset(0, -100),

                child: Column(
                  children: [
                    ProfileDetailsCard(details: details),

                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.badge_outlined),
                          label: const Text(
                            "View as ID Card",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfileIdCardScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
