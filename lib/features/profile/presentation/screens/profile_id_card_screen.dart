import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';

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
    final scheme = Theme.of(context).colorScheme;

    final authState = ref.watch(authProvider);

    final profile = authState.profile;
    final user = authState.authUser;

    final companyLogo = authState.companyLogoUrl;

    print("🏢 Company Logo URL: $companyLogo");

    final name = profile?.associatesName ?? user?.name ?? "Guest";
    final empId = profile?.payrollCode ?? "EMP0001";
    final designation = profile?.designation ?? "N/A";
    final department = profile?.departmentName ?? "N/A";
    final email = profile?.email ?? "N/A";

    final profileImage = authState.profileUrl;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: const Text("ID Card"), centerTitle: true),
      body: Center(
        child: GestureDetector(
          onTap: flipCard,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
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
                        child: _buildBackCard(
                          scheme,
                          companyLogo,
                          email,
                          department,
                        ),
                      )
                    : _buildFrontCard(
                        scheme,
                        name,
                        empId,
                        designation,
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

  /// FRONT SIDE
  Widget _buildFrontCard(
    ColorScheme scheme,
    String name,
    String empId,
    String designation,
    String profileImage,
    String companyLogo,
  ) {
    return GlassmorphicContainer(
      width: 320,
      height: 520,
      borderRadius: 24,
      blur: 20,
      alignment: Alignment.center,
      border: 1.5,
      linearGradient: LinearGradient(
        colors: [
          scheme.primary.withOpacity(.35),
          scheme.primaryContainer.withOpacity(.25),
        ],
      ),
      borderGradient: LinearGradient(
        colors: [Colors.white.withOpacity(.5), Colors.white.withOpacity(.1)],
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),

          /// COMPANY LOGO
          if (companyLogo.isNotEmpty) Image.network(companyLogo, height: 60),

          const SizedBox(height: 20),

          /// PROFILE IMAGE
          CircleAvatar(
            radius: 50,
            backgroundImage: profileImage.isNotEmpty
                ? NetworkImage(profileImage)
                : const AssetImage("assets/images/profile.jpg")
                      as ImageProvider,
          ),

          const SizedBox(height: 16),

          /// NAME
          Text(
            name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          /// EMP ID
          Text(empId, style: TextStyle(color: scheme.onSurfaceVariant)),

          const SizedBox(height: 12),

          /// DESIGNATION
          Text(
            designation,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),

          const Spacer(),

          const Text("Tap to flip", style: TextStyle(fontSize: 12)),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// BACK SIDE
  Widget _buildBackCard(
    ColorScheme scheme,
    String companyLogo,
    String email,
    String department,
  ) {
    return GlassmorphicContainer(
      width: 320,
      height: 520,
      borderRadius: 24,
      blur: 20,
      alignment: Alignment.center,
      border: 1.5,
      linearGradient: LinearGradient(
        colors: [
          scheme.secondaryContainer.withOpacity(.3),
          scheme.surface.withOpacity(.2),
        ],
      ),
      borderGradient: LinearGradient(
        colors: [Colors.white.withOpacity(.5), Colors.white.withOpacity(.1)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            if (companyLogo.isNotEmpty) Image.network(companyLogo, height: 50),

            const SizedBox(height: 30),

            _info("Department", department),

            const SizedBox(height: 20),

            _info("Email", email),

            const Spacer(),

            Container(height: 60, color: Colors.black),

            const SizedBox(height: 12),

            const Text(
              "Authorized Employee",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
