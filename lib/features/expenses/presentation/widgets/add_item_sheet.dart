import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddItemSheet extends StatefulWidget {
  final List<String> categories;
  final Function(Map<String, dynamic>) onAdd;

  const AddItemSheet({
    super.key,
    required this.categories,
    required this.onAdd,
  });

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  String selectedCategory = "Travel";
  final descriptionController = TextEditingController();
  final amountController = TextEditingController();
  final List<String> _receiptPaths = [];
  final ImagePicker _picker = ImagePicker();

  String formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _pickReceipts() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    setState(() {
      for (final f in files) {
        final p = f.path.trim();
        if (p.isNotEmpty && !_receiptPaths.contains(p)) {
          _receiptPaths.add(p);
        }
      }
    });
  }

  Future<void> _pickDocuments() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'heic',
      ],
    );
    if (res == null || res.files.isEmpty) return;
    setState(() {
      for (final f in res.files) {
        final p = f.path?.trim() ?? '';
        if (p.isNotEmpty && !_receiptPaths.contains(p)) {
          _receiptPaths.add(p);
        }
      }
    });
  }

  void _removeReceiptAt(int i) {
    setState(() => _receiptPaths.removeAt(i));
  }

  void submit() {
    final amount = double.tryParse(amountController.text);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid amount")),
      );
      return;
    }

    widget.onAdd({
      "category": selectedCategory,
      "description": descriptionController.text.trim(),
      "amount": amount,
      "expense_date": formatDate(DateTime.now()),
      "_receiptPaths": List<String>.from(_receiptPaths),
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(16, 20, 16, bottomInset + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Add Expense Item",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(selectedCategory),
            initialValue: selectedCategory,
            items: widget.categories
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => selectedCategory = val!),
            decoration: InputDecoration(
              labelText: "Category *",
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 10),
          TextField(
            controller: descriptionController,
            decoration: InputDecoration(
              labelText: "Description",
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 10),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Amount *",
              prefixText: "₹ ",
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Receipts for this line (optional)",
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickReceipts,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text("Add photos"),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickDocuments,
            icon: const Icon(Icons.attach_file_outlined),
            label: const Text("Add files (PDF / images)"),
          ),
          if (_receiptPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _receiptPaths.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final path = _receiptPaths[i];
                  final isPdf = path.toLowerCase().endsWith('.pdf');
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: isPdf
                            ? Container(
                                width: 72,
                                height: 72,
                                color: scheme.surfaceContainerHigh,
                                child: Icon(
                                  Icons.picture_as_pdf,
                                  size: 40,
                                  color: scheme.primary,
                                ),
                              )
                            : Image.file(
                                File(path),
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Material(
                          color: scheme.error,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _removeReceiptAt(i),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: scheme.onError,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: submit,
              child: const Text("Add Item"),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
