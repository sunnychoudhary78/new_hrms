import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lms/shared/widgets/app_bar.dart';

class NotificationDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> notification;

  const NotificationDetailsScreen({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final cardRadius = BorderRadius.circular(isIOS ? 12 : 16);

    final title = notification["title"] ?? "Notification";
    final message = notification["message"] ?? "";
    final type = notification["type"] ?? "";
    final createdAt = DateTime.tryParse(notification["createdAt"] ?? "");

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: "Notification Details"),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: isIOS
            ? const BouncingScrollPhysics()
            : const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(20),

        /// 👇 This ensures card takes only needed height
        child: Align(
          alignment: Alignment.topCenter,
          child: Card(
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: cardRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),

              /// 👇 Important fix
              child: Column(
                mainAxisSize: MainAxisSize.min, // ⭐ KEY LINE
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// TITLE
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// TYPE
                  Text(
                    "Type: $type",
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// MESSAGE
                  Text(message, style: const TextStyle(fontSize: 16)),

                  const SizedBox(height: 24),

                  /// DATE
                  if (createdAt != null)
                    Text(
                      "Received on: ${createdAt.day}/${createdAt.month}/${createdAt.year} "
                      "${createdAt.hour.toString().padLeft(2, '0')}:"
                      "${createdAt.minute.toString().padLeft(2, '0')}",
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
