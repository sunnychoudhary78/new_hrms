import 'package:flutter/material.dart';

class SplashLoadingScreen extends StatefulWidget {
  const SplashLoadingScreen({super.key});

  @override
  State<SplashLoadingScreen> createState() => _SplashLoadingScreenState();
}

class _SplashLoadingScreenState extends State<SplashLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final t = _controller.value;

            double logoX = 0;
            double textX = 0;
            double textOpacity = 0;
            double logoScale = 0.8;

            // 🎬 FINAL PERFECT TIMELINE (WITH FIXED SPACING)

            if (t < 0.15) {
              // STEP 1: logo entry
              final p = t / 0.15;

              logoScale = 0.8 + (0.2 * p);
              textOpacity = 0;
              textX = 0;
              logoX = 0;
            } else if (t < 0.45) {
              // STEP 2: reveal
              final p = (t - 0.15) / 0.30;

              logoX = -50 * p;
              textX = 48 * p; // ✅ reduced gap
              textOpacity = p;
              logoScale = 1;
            } else if (t < 0.5) {
              // STEP 3: short pause
              logoX = -50;
              textX = 48; // ✅ reduced gap
              textOpacity = 1;
              logoScale = 1;
            } else if (t < 0.85) {
              // STEP 4: reverse
              final p = Curves.easeIn.transform((t - 0.5) / 0.35);

              logoX = -50 * (1 - p);
              textX = 48 * (1 - p); // ✅ reduced gap
              textOpacity = 1 - p;
              logoScale = 1;
            } else {
              // STEP 5: final hold
              logoX = 0;
              textX = 0;
              textOpacity = 0;
              logoScale = 1;
            }

            return Stack(
              alignment: Alignment.center,
              children: [
                // 🔥 TEXT
                Opacity(
                  opacity: textOpacity,
                  child: Transform.translate(
                    offset: Offset(textX, 0),
                    child: const Text(
                      "HRMS",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC83C73),
                      ),
                    ),
                  ),
                ),

                // 🔥 LOGO
                Transform.translate(
                  offset: Offset(logoX, 0),
                  child: Transform.scale(
                    scale: logoScale,
                    child: Image.asset(
                      "assets/images/hrms_logo_2.png",
                      height: 90,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
