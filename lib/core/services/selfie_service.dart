import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/global_loading_provider.dart';

class SelfieService {
  /// Opens front camera safely
  Future<File?> captureSelfie(BuildContext context) async {
    /// Hide loader before opening camera
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(globalLoadingProvider.notifier).hide();
    } catch (_) {}

    /// Open camera
    final file = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (_) => const _SelfieCameraScreen()),
    );

    /// ✅ Show loader after photo selected
    if (file != null && context.mounted) {
      try {
        final container = ProviderScope.containerOf(context, listen: false);
        container
            .read(globalLoadingProvider.notifier)
            .showLoading("Uploading selfie...");
      } catch (_) {}
    }

    return file;
  }

  /// Compress image
  Future<File> compressImage(File file) async {
    final dir = await getTemporaryDirectory();

    final path =
        "${dir.path}/selfie_${DateTime.now().millisecondsSinceEpoch}.jpg";

    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      path,
      quality: 70,
    );

    return File(result!.path);
  }
}

class _SelfieCameraScreen extends StatefulWidget {
  const _SelfieCameraScreen();

  @override
  State<_SelfieCameraScreen> createState() => _SelfieCameraScreenState();
}

class _SelfieCameraScreenState extends State<_SelfieCameraScreen> {
  CameraController? controller;

  bool isReady = false;
  bool isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();

    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );

    controller = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await controller!.initialize();

    if (mounted) {
      setState(() {
        isReady = true;
      });
    }
  }

  Future<void> _capture() async {
    if (isCapturing) return;

    isCapturing = true;

    try {
      final XFile file = await controller!.takePicture();

      if (!mounted) return;

      final result = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (_) => _SelfiePreviewScreen(imageFile: File(file.path)),
        ),
      );

      /// ✅ ONLY CLOSE CAMERA IF USER CONFIRMED PHOTO
      if (result != null && mounted) {
        Navigator.pop(context, result);
      }

      /// ✅ If null → user pressed Retake → stay on camera
    } catch (_) {
      if (mounted) Navigator.pop(context, null);
    } finally {
      isCapturing = false;
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isReady) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /// Camera preview
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller!.value.previewSize!.height,
                height: controller!.value.previewSize!.width,
                child: CameraPreview(controller!),
              ),
            ),
          ),

          /// Capture button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _capture,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400, width: 5),
                  ),
                ),
              ),
            ),
          ),

          /// Close button
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context, null),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelfiePreviewScreen extends StatelessWidget {
  final File imageFile;

  const _SelfiePreviewScreen({required this.imageFile});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /// Mirrored image (fix flip)
          Positioned.fill(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scale(-1.0, 1.0),
              child: Image.file(imageFile, fit: BoxFit.cover),
            ),
          ),

          /// Top gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
            ),
          ),

          /// Bottom gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
            ),
          ),

          /// Close button
          Positioned(
            top: 50,
            left: 16,
            child: _CircleButton(
              icon: Icons.close,
              onTap: () => Navigator.pop(context, null),
            ),
          ),

          /// Bottom buttons
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Row(
              children: [
                /// Retake button
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.8)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, null),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(
                      "Retake",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                /// Use photo button
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, imageFile),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text(
                      "Use Photo",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
