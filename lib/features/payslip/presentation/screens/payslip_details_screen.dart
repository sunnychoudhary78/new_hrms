import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/network_providers.dart';
import 'package:lms/core/services/pdf_service.dart';
import 'package:lms/features/payslip/data/models/payslip_model.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:pdfx/pdfx.dart';

class PayslipDetailScreen extends ConsumerStatefulWidget {
  final Payslip payslip;

  const PayslipDetailScreen({super.key, required this.payslip});

  @override
  ConsumerState<PayslipDetailScreen> createState() =>
      _PayslipDetailScreenState();
}

class _PayslipDetailScreenState extends ConsumerState<PayslipDetailScreen> {
  PdfControllerPinch? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (!widget.payslip.isDownloadable) {
      setState(() {
        _loading = false;
        _error = 'Payslip is not available for viewing yet';
      });
      return;
    }

    try {
      final dio = ref.read(dioClientProvider).dio;
      final bytes = await PayslipPdfService.fetchPdfBytes(dio, widget.payslip);

      _controller?.dispose();
      _controller = PdfControllerPinch(
        document: PdfDocument.openData(bytes),
      );

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } on PayslipPdfException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load payslip: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final payslip = widget.payslip;
    final title =
        'Payslip · ${_getMonthName(payslip.month)} ${payslip.year}';

    return Scaffold(
      appBar: AppAppBar(
        title: title,
        actions: [
          if (payslip.isDownloadable)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download payslip',
              onPressed: () async {
                final dio = ref.read(dioClientProvider).dio;
                await PayslipPdfService.download(context, dio, payslip);
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (widget.payslip.isDownloadable) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return PdfViewPinch(
      controller: controller,
      scrollDirection: Axis.vertical,
      padding: defaultTargetPlatform == TargetPlatform.iOS ? 8 : 4,
    );
  }
}

String _getMonthName(int month) {
  const months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return (month >= 1 && month <= 12) ? months[month] : 'Unknown';
}
