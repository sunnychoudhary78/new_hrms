import 'package:flutter/material.dart';

class SplashLoadingScreen extends StatelessWidget {
  const SplashLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/images/hrms_logo.png", height: 110),
            const SizedBox(height: 30),
            CircularProgressIndicator(color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
