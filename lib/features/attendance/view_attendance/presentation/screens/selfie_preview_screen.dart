import 'package:flutter/material.dart';

class SelfiePreviewScreen extends StatelessWidget {
  final String imageUrl;
  final Map<String, String>? headers;

  const SelfiePreviewScreen({super.key, required this.imageUrl, this.headers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(imageUrl, headers: headers, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
