class ResignationModel {
  final String id; // ✅ FIXED

  final String status;
  final String reason;
  final String? lastWorkingDate;

  final String? employeeName;
  final String? managerName;
  final String? hodName;

  ResignationModel({
    required this.id,
    required this.status,
    required this.reason,
    this.lastWorkingDate,
    this.employeeName,
    this.managerName,
    this.hodName,
  });

  factory ResignationModel.fromJson(Map<String, dynamic> json) {
    return ResignationModel(
      id: json['id']?.toString() ?? '', // ✅ FIXED
      status: json['status'] ?? '',
      reason: json['reason'] ?? '',
      lastWorkingDate: json['last_working_date'],

      employeeName: json['employee']?['name'],
      managerName: json['manager']?['name'],
      hodName: json['hod']?['name'],
    );
  }
}
