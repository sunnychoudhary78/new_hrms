import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/profile/data/models/user_details_model.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/shared/widgets/app_bar.dart';

class ProfileIdCardScreen extends ConsumerStatefulWidget {
  const ProfileIdCardScreen({super.key});

  @override
  ConsumerState<ProfileIdCardScreen> createState() =>
      _ProfileIdCardScreenState();
}

class _ProfileIdCardScreenState extends ConsumerState<ProfileIdCardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  bool isFront = true;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0,
      end: pi,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  void flipCard() {
    if (isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    isFront = !isFront;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    final Userdetails? profile = authState.profile;

    if (profile == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profileImage = authState.profileUrl;
    final companyLogo = authState.companyLogoUrl;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppAppBar(title: "Employee ID Card"),
      body: Center(
        child: GestureDetector(
          onTap: flipCard,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (_, __) {
              final angle = _animation.value;
              final isBack = angle > pi / 2;

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: isBack
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(pi),
                        child: _buildBackCard(context, profile, companyLogo),
                      )
                    : _buildFrontCard(
                        context,
                        profile,
                        profileImage,
                        companyLogo,
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  /////////////////////////////////////////////////////////////////
  /// FRONT SIDE
  /////////////////////////////////////////////////////////////////

  Widget _buildFrontCard(
    BuildContext context,
    Userdetails profile,
    String profileImage,
    String companyLogo,
  ) {
    return Container(
      width: 340,
      height: 540,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          /// COMPANY HEADER
          Container(
            height: 90,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Row(
              children: [
                if (companyLogo.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.network(companyLogo, height: 40),
                  ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    profile.companyName ?? "",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 18),

          /// PHOTO + ID
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.iconBg,
            child: CircleAvatar(
              radius: 46,
              backgroundImage: profileImage.isNotEmpty
                  ? NetworkImage(profileImage)
                  : null,
              child: profileImage.isEmpty
                  ? Icon(Icons.person, size: 40, color: AppColors.primary)
                  : null,
            ),
          ),

          SizedBox(height: 10),

          Text(
            profile.associatesName ?? "",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),

          Text(
            profile.designation ?? "",
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),

          SizedBox(height: 4),

          Text(
            "ID: ${profile.payrollCode ?? "--"}",
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),

          const SizedBox(height: 18),

          /// INFO SECTION
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                _infoTile("Department", profile.departmentName),

                _infoTile("Email", profile.email),

                _infoTile("Phone", profile.contactPrimary),

                _infoTile("Location", profile.workLocation),
              ],
            ),
          ),

          const Spacer(),

          /// FOOTER STRIP
          Container(
            height: 45,
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.lg),
              ),
            ),
            child: const Center(
              child: Text(
                "Authorized Employee",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /////////////////////////////////////////////////////////////////
  /// BACK SIDE
  /////////////////////////////////////////////////////////////////

  Widget _buildBackCard(
    BuildContext context,
    Userdetails profile,
    String companyLogo,
  ) {
    return Container(
      width: 340,
      height: 540,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          if (companyLogo.isNotEmpty) Image.network(companyLogo, height: 50),

          SizedBox(height: 20),

          _infoBlock("Employee ID", profile.payrollCode),

          _infoBlock("Manager", profile.manager?.name),

          _infoBlock("Emergency Contact", profile.emergencyContact),

          SizedBox(height: 20),

          /// QR PLACEHOLDER
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.qr_code, size: 60, color: AppColors.primary),
          ),

          const Spacer(),

          Text(
            "If found please return to company office.",
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  /////////////////////////////////////////////////////////////////
  /// HELPERS
  /////////////////////////////////////////////////////////////////

  Widget _infoTile(String title, String? value) {
    if (value == null || value.isEmpty) return SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              title,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBlock(String title, String? value) {
    if (value == null || value.isEmpty) return SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),

          const SizedBox(height: 4),

          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
