class PolicyModel {
  final String id;
  final String title;
  final String fileName;
  final String? originalName;
  final String? fileUrl;
  final int? fileSize;
  final DateTime? createdAt;
  final String? companyName;

  const PolicyModel({
    required this.id,
    required this.title,
    required this.fileName,
    this.originalName,
    this.fileUrl,
    this.fileSize,
    this.createdAt,
    this.companyName,
  });

  factory PolicyModel.fromJson(Map<String, dynamic> json) {
    final company = json['company'];
    final createdRaw = json['created_at'] ?? json['createdAt'];

    return PolicyModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Policy',
      fileName: json['file_name']?.toString() ?? '',
      originalName: json['original_name']?.toString(),
      fileUrl: json['file_url']?.toString(),
      fileSize: int.tryParse(json['file_size']?.toString() ?? ''),
      createdAt: createdRaw == null
          ? null
          : DateTime.tryParse(createdRaw.toString())?.toLocal(),
      companyName: company is Map ? company['name']?.toString() : null,
    );
  }
}
