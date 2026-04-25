import 'package:lms/core/network/api_constants.dart';

/// Encodes each path segment once (handles spaces; avoids double-encoding if already encoded).
String encodeUploadPathSegments(String path) {
  return path.split('/').map((s) {
    if (s.isEmpty) return s;
    try {
      return Uri.encodeComponent(Uri.decodeComponent(s));
    } catch (_) {
      return Uri.encodeComponent(s);
    }
  }).join('/');
}

/// Candidate URIs for downloading an expense attachment.
/// Canonical path: `{BASE_URL}/uploads/expenses/receipts/{filename}`.
/// Also tries older layouts for compatibility.
List<Uri> expenseReceiptCandidateUris(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return const [];

  if (t.startsWith('http://') || t.startsWith('https://')) {
    return [Uri.parse(t)];
  }

  var p = t.replaceFirst(RegExp(r'^/+'), '');
  p = p.replaceAll(r'\/', '/').replaceAll('\\', '/');

  final base = ApiConstants.baseUrl.endsWith('/')
      ? ApiConstants.baseUrl.substring(0, ApiConstants.baseUrl.length - 1)
      : ApiConstants.baseUrl;
  final baseUri = Uri.parse('$base/');

  final relOrder = <String>[];
  final seenRel = <String>{};

  void tryAdd(String relativePath) {
    final enc = encodeUploadPathSegments(relativePath);
    if (seenRel.add(enc)) relOrder.add(enc);
  }

  if (p.startsWith('uploads/expenses/receipts/')) {
    tryAdd(p);
  } else if (p.startsWith('uploads/expenses/') && !p.contains('/receipts/')) {
    tryAdd(p);
    final rest = p.substring('uploads/expenses/'.length);
    if (rest.isNotEmpty && !rest.contains('/')) {
      tryAdd('uploads/expenses/receipts/$rest');
    }
  } else if (p.startsWith('uploads/')) {
    tryAdd(p);
  } else if (p.startsWith('expenses/')) {
    tryAdd('uploads/$p');
  } else {
    tryAdd('uploads/expenses/receipts/$p');
    tryAdd('uploads/expenses/$p');
    if (!p.contains('/')) {
      tryAdd('uploads/$p');
    }
  }

  final segments = p.split('/')..removeWhere((s) => s.isEmpty);
  if (segments.isNotEmpty) {
    final leaf = segments.last;
    if (leaf.isNotEmpty &&
        leaf.contains('.') &&
        !p.startsWith('uploads/expenses/receipts/')) {
      tryAdd('uploads/expenses/receipts/$leaf');
    }
  }

  final out = <Uri>[];
  final seenUri = <String>{};
  for (final r in relOrder) {
    final u = baseUri.resolve(r);
    if (seenUri.add(u.toString())) out.add(u);
  }
  return out;
}
