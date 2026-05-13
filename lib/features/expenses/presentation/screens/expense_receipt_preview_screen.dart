import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/network_providers.dart';
import 'package:lms/features/expenses/data/expense_attachment_utils.dart';
import 'package:lms/core/services/crypto_helper.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Loads expense receipts the same way attendance selfies are resolved: authenticated
/// [Dio] GET as bytes (not [Image.network], which skips interceptors and can mis-handle
/// JSON/encrypted responses). Tries common upload paths and supports JPEG/PNG/GIF/WebP
/// in-app and PDF via the system viewer.
class ExpenseReceiptPreviewScreen extends ConsumerStatefulWidget {
  final String receiptFileName;

  const ExpenseReceiptPreviewScreen({super.key, required this.receiptFileName});

  @override
  ConsumerState<ExpenseReceiptPreviewScreen> createState() =>
      _ExpenseReceiptPreviewScreenState();
}

class _ExpenseReceiptPreviewScreenState
    extends ConsumerState<ExpenseReceiptPreviewScreen> {
  bool _loading = true;
  String? _error;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    if (widget.receiptFileName.trim().isEmpty) {
      _loading = false;
      _error = 'No receipt file';
    } else {
      _load();
    }
  }

  bool _looksLikeImage(Uint8List b) {
    if (b.length < 12) return false;
    if (b[0] == 0xFF && b[1] == 0xD8) return true;
    if (b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47 &&
        b[4] == 0x0D &&
        b[5] == 0x0A &&
        b[6] == 0x1A &&
        b[7] == 0x0A) {
      return true;
    }
    if (b.length >= 6) {
      final head = String.fromCharCodes(b.sublist(0, 6));
      if (head == 'GIF87a' || head == 'GIF89a') return true;
    }
    if (b.length >= 12) {
      final riff = String.fromCharCodes(b.sublist(0, 4));
      final webp = String.fromCharCodes(b.sublist(8, 12));
      if (riff == 'RIFF' && webp == 'WEBP') return true;
    }
    return false;
  }

  bool _looksLikePdf(Uint8List b) {
    if (b.length < 4) return false;
    final p = String.fromCharCodes(b.sublist(0, 4));
    return p == '%PDF';
  }

  bool _looksLikeJsonObject(Uint8List b) {
    var i = 0;
    while (i < b.length &&
        (b[i] == 0x20 || b[i] == 0x09 || b[i] == 0x0A || b[i] == 0x0D)) {
      i++;
    }
    return i < b.length && b[i] == 0x7B;
  }

  Uint8List? _bytesFromDecrypted(dynamic decrypted) {
    if (decrypted is Uint8List) return decrypted;
    if (decrypted is List<int>) return Uint8List.fromList(decrypted);

    if (decrypted is String) {
      try {
        final decoded = base64Decode(decrypted);
        if (decoded.isNotEmpty) return Uint8List.fromList(decoded);
      } catch (_) {}
      try {
        final decoded = base64Decode(decrypted.replaceAll('\n', '').trim());
        if (decoded.isNotEmpty) return Uint8List.fromList(decoded);
      } catch (_) {}
    }

    if (decrypted is Map) {
      for (final key in [
        'file',
        'data',
        'content',
        'image',
        'base64',
        'file_data',
        'receipt',
        'receipt_file',
      ]) {
        final v = decrypted[key];
        final out = _bytesFromDecrypted(v);
        if (out != null) return out;
      }
    }

    return null;
  }

  Future<Uint8List?> _interpretBody(Uint8List raw) async {
    if (_looksLikeImage(raw) || _looksLikePdf(raw)) return raw;

    if (_looksLikeJsonObject(raw)) {
      try {
        final map = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
        final decrypted = CryptoHelper.decryptPayload(map);
        final fromNested = _bytesFromDecrypted(decrypted);
        if (fromNested != null && fromNested.isNotEmpty) return fromNested;
      } catch (_) {}
    }

    return null;
  }

  Future<void> _openPdf(Uint8List bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final safe = widget.receiptFileName.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
      final file = File('${dir.path}/receipt_$safe');
      await file.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(file.path);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not open PDF: $e';
        });
      }
    }
  }

  Future<void> _load() async {
    final dio = ref.read(dioClientProvider).dio;
    final uris = expenseReceiptCandidateUris(widget.receiptFileName);

    Object? lastError;

    for (final uri in uris) {
      try {
        final res = await dio.getUri<Uint8List>(
          uri,
          options: Options(
            responseType: ResponseType.bytes,
            validateStatus: (s) => s == 200,
          ),
        );

        final dynamic data = res.data;
        final Uint8List? raw = data is Uint8List
            ? data
            : data is List<int>
            ? Uint8List.fromList(data)
            : null;
        if (raw == null || raw.isEmpty) continue;

        final interpreted = await _interpretBody(raw);
        final bytes = interpreted ?? raw;

        if (_looksLikePdf(bytes)) {
          setState(() {
            _loading = false;
            _imageBytes = null;
            _error = null;
          });
          await _openPdf(bytes);
          return;
        }

        if (_looksLikeImage(bytes)) {
          setState(() {
            _loading = false;
            _imageBytes = bytes;
            _error = null;
          });
          return;
        }

        lastError = Exception('Unsupported file type from server');
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == 404 || code == 400) {
          lastError = e;
          continue;
        }
        lastError = e;
        break;
      } catch (e) {
        lastError = e;
        break;
      }
    }

    setState(() {
      _loading = false;
      _error = lastError?.toString() ?? 'Could not load receipt';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: defaultTargetPlatform == TargetPlatform.iOS,
        title: const Text('Receipt', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white54))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ),
            )
          : _imageBytes != null
          ? Center(
              child: InteractiveViewer(
                child: Image.memory(_imageBytes!, fit: BoxFit.contain),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
